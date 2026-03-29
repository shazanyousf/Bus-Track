const router = require('express').Router();
const Setting = require('../models/Setting');
const auth = require('../middleware/auth');

// Return the single settings document. Create defaults if missing.
router.get('/', async (req, res) => {
  try {
    let settings = await Setting.findOne();
    if (!settings) {
      settings = await Setting.create({
        departments: ['Computer Science', 'Software Engineering', 'Electrical Engineering', 'Mechanical Engineering'],
        semesters: ['1st', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th'],
      });
    }
    res.json(settings);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// Admin updates the available departments and semesters.
router.put('/', auth, auth.adminOnly, async (req, res) => {
  try {
    const updates = {};
    if (Array.isArray(req.body.departments)) updates.departments = req.body.departments;
    if (Array.isArray(req.body.semesters)) updates.semesters = req.body.semesters;

    let settings = await Setting.findOne();
    if (!settings) {
      settings = await Setting.create({
        departments: updates.departments || ['Computer Science', 'Software Engineering', 'Electrical Engineering', 'Mechanical Engineering'],
        semesters: updates.semesters || ['1st', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th'],
      });
    } else {
      if (updates.departments) settings.departments = updates.departments;
      if (updates.semesters) settings.semesters = updates.semesters;
      await settings.save();
    }
    res.json(settings);
  } catch (e) {
    res.status(400).json({ message: e.message });
  }
});

module.exports = router;
