const router = require('express').Router();
const Driver = require('../models/Driver');
const auth = require('../middleware/auth');

router.get('/', async (req, res) => {
  try { res.json(await Driver.find()); }
  catch (e) { res.status(500).json({ message: e.message }); }
});

router.post('/', auth, auth.adminOnly, async (req, res) => {
  try { res.status(201).json(await Driver.create(req.body)); }
  catch (e) { res.status(400).json({ message: e.message }); }
});

router.put('/:id', auth, auth.adminOnly, async (req, res) => {
  try { res.json(await Driver.findByIdAndUpdate(req.params.id, req.body, { new: true })); }
  catch (e) { res.status(400).json({ message: e.message }); }
});

router.delete('/:id', auth, auth.adminOnly, async (req, res) => {
  try { await Driver.findByIdAndDelete(req.params.id); res.json({ message: 'Driver deleted' }); }
  catch (e) { res.status(500).json({ message: e.message }); }
});

module.exports = router;
