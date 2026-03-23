const router = require('express').Router();
const Student = require('../models/Student');
const auth = require('../middleware/auth');

router.get('/', auth, async (req, res) => {
  try {
    const filter = req.user.role === 'parent' ? { parentId: req.user.id } : {};
    res.json(await Student.find(filter).populate('assignedBus'));
  } catch (e) { res.status(500).json({ message: e.message }); }
});

router.post('/', auth, async (req, res) => {
  try { res.status(201).json(await Student.create({ ...req.body, parentId: req.user.id })); }
  catch (e) { res.status(400).json({ message: e.message }); }
});

module.exports = router;
