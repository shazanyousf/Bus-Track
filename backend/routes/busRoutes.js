const router = require('express').Router();
const Route = require('../models/Route');
const auth = require('../middleware/auth');

router.get('/', async (req, res) => {
  try { res.json(await Route.find()); }
  catch (e) { res.status(500).json({ message: e.message }); }
});

router.post('/', auth, auth.adminOnly, async (req, res) => {
  try { res.status(201).json(await Route.create(req.body)); }
  catch (e) { res.status(400).json({ message: e.message }); }
});

router.put('/:id', auth, auth.adminOnly, async (req, res) => {
  try { res.json(await Route.findByIdAndUpdate(req.params.id, req.body, { new: true })); }
  catch (e) { res.status(400).json({ message: e.message }); }
});

router.delete('/:id', auth, auth.adminOnly, async (req, res) => {
  try { await Route.findByIdAndDelete(req.params.id); res.json({ message: 'Route deleted' }); }
  catch (e) { res.status(500).json({ message: e.message }); }
});

module.exports = router;
