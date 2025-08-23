const crypto = require('crypto');

// Minimal local rules-based moderation with categories and severities.
// This is intentionally lightweight to enable preview/testing without external providers.

const CHARTER_VERSION = process.env.CHARTER_VERSION || '2025-08-Preview-1';
const MODERATION_PROVIDER = (process.env.MODERATION_PROVIDER || '').toLowerCase();
const { getCharterSync } = require('./charter');
const fetch = require('node-fetch');

// Example charter categories. Extend as needed or replace with external provider.
const CHARTER = {
  version: CHARTER_VERSION,
  categories: [
    { key: 'illegal', title: 'Illegal Content', severity: 'hard' },
    { key: 'sexual', title: 'Sexual Content', severity: 'soft' },
    { key: 'self_harm', title: 'Self Harm', severity: 'hard' },
    { key: 'violence', title: 'Violence', severity: 'soft' },
    { key: 'hate', title: 'Hate / Harassment', severity: 'hard' },
    { key: 'pii', title: 'Personal Information', severity: 'soft' },
    { key: 'malware', title: 'Malware / Exploits', severity: 'hard' },
    { key: 'spam', title: 'Spam / Scams', severity: 'soft' }
  ],
  uiHints: {
    suggestEdits: true,
    highlightSpans: true
  }
};

function getCharter() {
  return CHARTER;
}

// Very small keyword/regex sets for demonstration. Replace/expand per needs.
const HARD_BLOCK_REGEX = [
  /child\s*(porn|sexual|abuse)/i,
  /(kill|murder)\s+(you|them|him|her|people)/i,
  /racial\s+slur\s*list/i,
  /(credit\s*card|ssn|social\s*security)\s*(number|no\.?)/i,
  /(botnet|exploit\s*code|ransomware|keylogger)/i
];

const SOFT_BLOCK_REGEX = [
  /(buy\s+now|limited\s+offer|click\s+here)/i,
  /(win\s+money|free\s+crypto|airdrop)/i,
  /\b(?:https?:\/\/)?[\w.-]+\.[a-z]{2,}\/\S*/i // generic links (spam heuristic)
];

const PII_REGEX = {
  email: /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i,
  phone: /(?:\+?\d{1,3}[\s-]?)?(?:\(?\d{3}\)?[\s-]?\d{3}[\s-]?\d{4})/,
};

function summarize(text) {
  const hash = crypto.createHash('sha1').update(text || '').digest('hex').slice(0, 8);
  return { len: (text || '').length, sha1_8: hash };
}

async function classifyWithGrok(text) {
  try {
    const apiKey = process.env.GROK_API_KEY;
    if (!apiKey) return null;
    // Minimal example; replace with actual Grok moderation endpoint once standardized
    const resp = await fetch('https://api.x.ai/v1/moderations', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
      body: JSON.stringify({ input: text })
    });
    if (!resp.ok) return null;
    const data = await resp.json();
    return data; // expect { categories: [{key, confidence}], flags: [...] }
  } catch (_) { return null; }
}

function applyCharter(charter, localHits) {
  // If provider returned structured results, merge here; for now, only localHits
  const byCategory = new Map();
  for (const h of localHits) {
    byCategory.set(h.category, Math.max(byCategory.get(h.category) || 0, h.score || 1.0));
  }
  const violations = [];
  for (const cat of charter.categories || []) {
    const s = byCategory.get(cat.key) || 0;
    const hard = cat.thresholds?.hard_block ?? 1.1;
    if (s >= hard) violations.push({ category: cat.key, score: s });
  }
  if (violations.length > 0) return { action: 'hard_block', violations };
  return { action: 'allow', violations: [] };
}

async function evaluateModeration(content, context = {}) {
  const startedAt = Date.now();
  const text = (content || '').trim();
  const hits = [];

  for (const re of HARD_BLOCK_REGEX) {
    if (re.test(text)) {
      hits.push({ category: 'illegal', rule: re.toString(), severity: 'hard' });
    }
  }

  for (const re of SOFT_BLOCK_REGEX) {
    if (re.test(text)) {
      hits.push({ category: 'spam', rule: re.toString(), severity: 'soft' });
    }
  }

  if (PII_REGEX.email.test(text) || PII_REGEX.phone.test(text)) {
    hits.push({ category: 'pii', rule: 'email/phone regex', severity: 'soft' });
  }

  // Derive action from local rules
  let action = 'allow';
  if (hits.some(h => h.severity === 'hard')) action = 'hard_block';
  else if (hits.length > 0) action = 'soft_block';

  const reason = hits.map(h => `${h.category}:${h.rule}`).slice(0, 5).join('; ');
  const latencyMs = Date.now() - startedAt;

  const localDecision = {
    action,
    categories: Array.from(new Set(hits.map(h => h.category))),
    reason,
    hits,
    model: 'local-rules-v1',
    charterVersion: CHARTER_VERSION,
    latencyMs,
    contentSummary: summarize(text),
    context: {
      postType: context.postType || 'free'
    }
  };

  // Optional: Provider (Grok) classification
  let providerCategories = [];
  if (MODERATION_PROVIDER === 'grok') {
    const provider = await classifyWithGrok(text);
    const cats = Array.isArray(provider?.categories) ? provider.categories : [];
    // Expect shape: [{ key, confidence }]; tolerate alternative keys
    providerCategories = cats
      .map(c => ({
        key: c.key || c.category || c.name,
        confidence: typeof c.confidence === 'number' ? c.confidence : (typeof c.score === 'number' ? c.score : 0.0)
      }))
      .filter(c => c.key && c.confidence > 0);
    if (providerCategories.length > 0) {
      localDecision.model = 'grok+local';
    }
  }

  // Apply Charter thresholds (server-sourced) with merged evidence
  const charter = getCharterSync();
  if (charter) {
    const evidence = [
      // Local rules mapped to scores
      ...hits.map(h => ({ category: h.category, score: h.severity === 'hard' ? 1.0 : 0.7 })),
      // Provider categories mapped to scores (use provider confidence)
      ...providerCategories.map(pc => ({ category: pc.key, score: Math.max(0, Math.min(1, pc.confidence)) }))
    ];
    const applied = applyCharter(charter, evidence);
    if (applied.action === 'hard_block') {
      localDecision.action = 'hard_block';
      localDecision.reason = localDecision.reason || 'Charter threshold breached';
    } else if (localDecision.action !== 'hard_block' && hits.length > 0) {
      // Preserve soft block when local rules hit but charter doesn’t hard block
      localDecision.action = 'soft_block';
    }
  }
  return localDecision;
}

module.exports = {
  evaluateModeration
};


