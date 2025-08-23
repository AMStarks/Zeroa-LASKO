const express = require('express');
const Joi = require('joi');
const crypto = require('crypto');
const { verifyTelestaiSignature } = require('../services/auth');
const { getSequentialCodeGenerator } = require('../services/sequentialCodeGenerator');
const { storePost, getPost, getChronologicalFeed, getUserPosts, checkRateLimit } = require('../services/redis');
const { getBatchManager } = require('../services/batchManager');
const logger = require('../utils/logger');

const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const { requireSubscription } = require('../middleware/subscription');
const { evaluateModeration } = require('../services/moderation');

// Helper: robust reverse ZSET range compatible across Redis clients/versions
async function zRevRangeCompat(client, key, start, count) {
  // Preferred: REV option on zRange
  try {
    if (typeof client.zRange === 'function') {
      return await client.zRange(key, start, start + count - 1, { REV: true });
    }
  } catch (e) {
    // fall through
  }
  // Next: direct zRevRange if available
  try {
    if (typeof client.zRevRange === 'function') {
      return await client.zRevRange(key, start, start + count - 1);
    }
  } catch (e) {
    // fall through
  }
  // Fallback: compute using zCard + forward zRange + local reverse
  const total = (typeof client.zCard === 'function') ? (await client.zCard(key)) : 0;
  if (!total) return [];
  const stopExclusive = start + count; // exclusive in our math
  const forwardStart = Math.max(total - stopExclusive, 0);
  const forwardEnd = Math.max(total - 1 - start, -1);
  if (forwardEnd < forwardStart) return [];
  const forward = await client.zRange(key, forwardStart, forwardEnd);
  return forward.reverse();
}

// Validation schemas
const postSchema = Joi.object({
  content: Joi.string().min(1).max(parseInt(process.env.POST_CONTENT_MAX || '25000', 10)).required(),
  userAddress: Joi.string().required(),
  signature: Joi.string().required(),
  pubkey: Joi.string().hex().length(66).optional(), // compressed secp256k1
  timestamp: Joi.number().integer().min(0).required(),
  ipfsHash: Joi.string().optional(),
  postType: Joi.string().valid('free', 'sponsored').default('free'),
  // Accept optional fields used by clients; they may be ignored server-side but shouldn't hard-fail validation
  contentHashHex: Joi.string().hex().length(64).optional(),
  tlsAddress: Joi.string().optional(),
  publicKeyCompressedHex: Joi.string().hex().length(66).optional(),
  zeroaSessionId: Joi.string().optional(),
  // Accept LAS# with 1..64 hex digits to allow for future expansions
  parentSequentialCode: Joi.string().pattern(/^LAS#[A-Fa-f0-9]{1,64}$/).optional(),
  parentIpfsHash: Joi.string().optional()
}).unknown(false);

const getPostSchema = Joi.object({
  sequentialCode: Joi.string().pattern(/^LAS#[A-Fa-f0-9]{1,64}$/).required()
});

/**
 * POST /api/posts
 * Create a new post with sequential code
 */
router.post('/', requireAuth, requireSubscription, async (req, res) => {
  try {
    // Rate limiting
    const clientIp = req.ip || req.connection.remoteAddress;
    const perMin = parseInt(process.env.POST_RATE_LIMIT_PER_MIN || '30', 10);
    const rateLimitOk = await checkRateLimit(clientIp, 60, perMin);
    
    if (!rateLimitOk) {
      return res.status(429).json({
        error: 'Rate limit exceeded',
        message: 'Too many posts. Please wait before posting again.'
      });
    }

    // Validate request body
    const { error, value } = postSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        error: 'Validation error',
        details: error.details[0].message
      });
    }

    const { content, userAddress, signature, pubkey, timestamp, ipfsHash, postType } = value;
    // Moderation preview gate: only enforce when header present
    const previewEnabled = String(req.get('X-Moderation-Preview') || '').toLowerCase() === 'true';
    if (previewEnabled) {
      const decision = await evaluateModeration(content, { postType });
      if (decision?.action === 'hard_block') {
        return res.status(422).json({
          error: 'Moderation blocked',
          message: 'Content violates moderation policy',
          decision
        });
      }
      if (decision?.action === 'soft_block') {
        // Mark not-live so it doesn’t appear in feeds
        req._moderation_soft_block = decision;
      }
    }

    // Parent linkage may be provided via body or query; prefer body when present
    const parentSequentialCode = value.parentSequentialCode || req.query.parentSequentialCode || undefined;
    const parentIpfsHash = value.parentIpfsHash || req.query.parentIpfsHash || undefined;

    // AuthN: token subject must match userAddress
    if (req.user?.sub && req.user.sub !== userAddress) {
      return res.status(403).json({ error: 'Token subject does not match user address' });
    }

    // Timestamp skew check
    const nowMs = Date.now();
    const maxSkewSec = parseInt(process.env.POST_MAX_SKEW_SECONDS || '120', 10);
    if (Math.abs(nowMs - Number(timestamp)) > maxSkewSec * 1000) {
      return res.status(400).json({ error: 'Timestamp outside allowed window' });
    }

    // Signature verification (optional gate via env)
    const enforceSig = (process.env.ENFORCE_POST_SIGNATURE || 'false').toLowerCase() === 'true';
    let verified = false;
    try {
      if (signature?.startsWith('mock-')) {
        verified = !enforceSig; // allow in non-enforced mode
      } else if (pubkey) {
        const contentHash = crypto.createHash('sha256').update(content).digest('hex');
        const canonical = `LASKO_POST|${contentHash}|${timestamp}|${userAddress}|${process.env.BUNDLE_ID || ''}|v1`;
        verified = verifyTelestaiSignature({
          message: canonical,
          signatureBase64: signature,
          pubkeyCompressedHex: pubkey,
          address: userAddress
        });
      }
    } catch (e) {
      verified = false;
    }
    if (enforceSig && !verified) {
      return res.status(400).json({ error: 'Invalid signature' });
    }

    // Verify signature (placeholder - implement actual verification)
    // TODO: Implement Core Wallet signature verification
    if (!signature || signature.length < 10) {
      return res.status(400).json({
        error: 'Invalid signature',
        message: 'Post must be signed with Core Wallet'
      });
    }

    // Generate sequential code
    const sequentialCodeGenerator = getSequentialCodeGenerator();
    const sequentialCode = await sequentialCodeGenerator.generateSequentialCode(userAddress, timestamp);

    // Create post data
    const postData = {
      sequentialCode,
      content,
      userAddress,
      signature,
      pubkey: pubkey || '',
      timestamp,
      ipfsHash: ipfsHash || '',
      postType,
      liveFlag: 'live', // Always live for now; group moderation can toggle later
      blockHeight: null, // Will be set when imprinted on TLS
      createdAt: new Date().toISOString(),
      // Parent relationships for replies (optional)
      parentSequentialCode: parentSequentialCode || '',
      parentIpfsHash: parentIpfsHash || ''
    };

    // Store post in Redis (simplified for now)
    try {
      await storePost(sequentialCode, postData);
      // Belt-and-braces: ensure replies never appear in the global feed
      const isReply = Boolean((postData.parentSequentialCode && postData.parentSequentialCode.length > 0) || (postData.parentIpfsHash && postData.parentIpfsHash.length > 0));
      if (isReply) {
        try {
          const client = require('../services/redis').getRedisClient();
          await client.zRem('halo:feed:chronological', sequentialCode);
          logger.info('Reply removed from global feed', {
            sequentialCode,
            parentSequentialCode: postData.parentSequentialCode,
            parentIpfsHash: postData.parentIpfsHash
          });
        } catch (e) {
          logger.warn('Failed to remove reply from global feed', { sequentialCode, error: e?.message });
        }
      }
    } catch (error) {
      logger.warn('Failed to store post in Redis, continuing anyway', error.message);
      // Continue without Redis storage for now
    }

    // Add post to batch for TLS blockchain writing
    try {
      const batchManager = getBatchManager();
      const batchInfo = await batchManager.addPostToBatch(postData);
      
      logger.info('Post added to batch', {
        sequentialCode,
        batchCode: batchInfo.batchCode,
        batchNumber: batchInfo.batchNumber,
        postCount: batchInfo.postCount
      });
    } catch (error) {
      logger.error('Failed to add post to batch', error);
      // Continue without batch processing for now
    }

    logger.info('Post created successfully', {
      sequentialCode,
      userAddress: userAddress.slice(0, 10) + '...',
      contentLength: content.length,
      postType
    });

    res.status(201).json({
      success: true,
      sequentialCode,
      message: 'Post created successfully',
      data: {
        sequentialCode,
        content,
        userAddress: userAddress.slice(0, 10) + '...',
        timestamp: Number(timestamp),
        postType,
        liveFlag: 'live'
      }
    });

  } catch (error) {
    logger.error('Failed to create post', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to create post'
    });
  }
});

/**
 * GET /api/posts/:sequentialCode/replies
 * Fetch replies for a given parent post by sequential code
 */
router.get('/:sequentialCode/replies', async (req, res) => {
  try {
    // Validate sequential code
    const { error, value } = getPostSchema.validate({ sequentialCode: req.params.sequentialCode });
    if (error) {
      return res.status(400).json({
        error: 'Invalid sequential code format',
        message: 'Sequential code must be in LAS#00000000000000000000000000000001 format'
      });
    }

    const page = parseInt(req.query.page) || 0;
    const limit = Math.min(parseInt(req.query.limit) || 50, 100);
    const start = page * limit;

    const parentSequentialCode = value.sequentialCode;
    const client = require('../services/redis').getRedisClient();
    const key = `halo:replies:parent:${parentSequentialCode}`;
    const ids = await zRevRangeCompat(client, key, start, limit);
    const posts = [];
    for (const id of ids) {
      const p = await require('../services/redis').getPost(id);
      if (p) posts.push(p);
    }

    return res.json({
      success: true,
      data: posts,
      pagination: {
        page,
        limit,
        total: posts.length,
        hasMore: posts.length === limit
      }
    });
  } catch (error) {
    logger.error('Failed to get replies for parent', error);
    return res.status(500).json({ error: 'Internal server error', message: 'Failed to retrieve replies' });
  }
});

/**
 * GET /api/posts/:sequentialCode
 * Get post by sequential code
 */
router.get('/:sequentialCode', async (req, res) => {
  try {
    // Validate sequential code
    const { error, value } = getPostSchema.validate({ sequentialCode: req.params.sequentialCode });
    if (error) {
      return res.status(400).json({
        error: 'Invalid sequential code format',
        message: 'Sequential code must be in LAS#0000000000000000000000000000001 format'
      });
    }

    const { sequentialCode } = value;

    // Get post from Redis
    const post = await getPost(sequentialCode);
    
    if (!post) {
      return res.status(404).json({
        error: 'Post not found',
        message: `Post with sequential code ${sequentialCode} not found`
      });
    }

    res.json({
      success: true,
      data: post
    });

  } catch (error) {
    logger.error('Failed to get post', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to retrieve post'
    });
  }
});

/**
 * GET /api/posts
 * Get chronological feed
 */
router.get('/', async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 0;
    const limit = Math.min(parseInt(req.query.limit) || 50, 100); // Max 100 posts per request
    const author = req.query.author;
    const parentSequentialCode = req.query.parentSequentialCode;
    const parentIpfsHash = req.query.parentIpfsHash;
    
    let posts = [];
    if (parentSequentialCode || parentIpfsHash) {
      // Fetch replies for a given parent
      const client = require('../services/redis').getRedisClient();
      if (parentSequentialCode) {
        const key = `halo:replies:parent:${parentSequentialCode}`;
        const ids = await zRevRangeCompat(client, key, page * limit, limit);
        for (const id of ids) {
          const p = await require('../services/redis').getPost(id);
          if (p) posts.push(p);
        }
      } else if (parentIpfsHash) {
        const key = `halo:replies:parentipfs:${parentIpfsHash}`;
        const ids = await zRevRangeCompat(client, key, page * limit, limit);
        for (const id of ids) {
          const p = await require('../services/redis').getPost(id);
          if (p) posts.push(p);
        }
      }
    } else if (author) {
      posts = await getUserPosts(author, page * limit, limit);
      if ((!posts || posts.length === 0) && (process.env.ALLOW_GLOBAL_FEED === 'true')) {
        posts = await getChronologicalFeed(page * limit, limit);
      }
    } else {
      posts = await getChronologicalFeed(page * limit, limit);
    }
    
    res.json({
      success: true,
      data: posts,
      pagination: {
        page,
        limit,
        total: posts.length,
        hasMore: posts.length === limit
      }
    });

  } catch (error) {
    logger.error('Failed to get feed', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to retrieve feed'
    });
  }
});

/**
 * GET /api/posts/:sequentialCode/replies
 * Fetch replies for a given parent post by sequential code
 */
 

/**
 * PUT /api/posts/:sequentialCode/flag
 * Update live/not-live flag (moderation)
 */
router.put('/:sequentialCode/flag', async (req, res) => {
  try {
    // Validate sequential code
    const { error, value } = getPostSchema.validate({ sequentialCode: req.params.sequentialCode });
    if (error) {
      return res.status(400).json({
        error: 'Invalid sequential code format',
        message: 'Sequential code must be in LAS#0000000000000000000000000000001 format'
      });
    }

    const { sequentialCode } = value;
    const { liveFlag, reason, moderatorAddress } = req.body;

    // Validate flag value
    if (!['live', 'not-live'].includes(liveFlag)) {
      return res.status(400).json({
        error: 'Invalid flag value',
        message: 'Flag must be either "live" or "not-live"'
      });
    }

    // Get existing post
    const post = await getPost(sequentialCode);
    if (!post) {
      return res.status(404).json({
        error: 'Post not found',
        message: `Post with sequential code ${sequentialCode} not found`
      });
    }

    // Update flag
    const updatedPost = {
      ...post,
      liveFlag,
      flagUpdatedAt: new Date().toISOString(),
      flagReason: reason || '',
      flagModerator: moderatorAddress || ''
    };

    // Store updated post
    await storePost(sequentialCode, updatedPost);

    logger.info('Post flag updated', {
      sequentialCode,
      liveFlag,
      moderatorAddress: moderatorAddress?.slice(0, 10) + '...'
    });

    res.json({
      success: true,
      message: `Post flag updated to ${liveFlag}`,
      data: {
        sequentialCode,
        liveFlag,
        updatedAt: updatedPost.flagUpdatedAt
      }
    });

  } catch (error) {
    logger.error('Failed to update post flag', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to update post flag'
    });
  }
});

module.exports = router; 