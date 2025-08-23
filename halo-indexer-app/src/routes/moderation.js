const express = require('express');
const router = express.Router();
const { evaluateModeration } = require('../services/moderation');
const { getCharterSync } = require('../services/charter');

// Return current moderation charter (versioned)
router.get('/charter', (req, res) => {
  const c = getCharterSync();
  if (!c) return res.status(503).json({ error: 'Charter unavailable' });
  res.json({ success: true, data: c });
});

// Stateless moderation preflight for clients
router.post('/check', (req, res) => {
  try {
    const { content, postType } = req.body || {};
    if (typeof content !== 'string' || content.trim().length === 0) {
      return res.status(400).json({ error: 'Invalid content' });
    }
    const decision = evaluateModeration(content, { postType });
    return res.json({ success: true, data: decision });
  } catch (e) {
    return res.status(500).json({ error: 'Moderation check failed' });
  }
});

module.exports = router;


