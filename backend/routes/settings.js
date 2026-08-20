const router = require('express').Router();
const Setting = require('../models/Setting');
const auth = require('../middleware/auth');

// Return the single settings document. Create defaults if missing.
router.get('/', async (req, res) => {
  try {
    let settings = await Setting.findOne();
    if (!settings) {
      settings = await Setting.create({
        classes: ['1', '2', '3', '4', '5', '6', '7', '8'],
      });
    }
    res.json(settings);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// Admin updates the available classes.
router.put('/', auth, auth.adminOnly, async (req, res) => {
  try {
    const updates = {};
    if (Array.isArray(req.body.classes)) updates.classes = req.body.classes;

    let settings = await Setting.findOne();
    if (!settings) {
      settings = await Setting.create({
        classes: updates.classes || ['1', '2', '3', '4', '5', '6', '7', '8'],
      });
    } else {
      if (updates.classes) settings.classes = updates.classes;
      await settings.save();
    }
    res.json(settings);
  } catch (e) {
    res.status(400).json({ message: e.message });
  }
});

module.exports = router;
