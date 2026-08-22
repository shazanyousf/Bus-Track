const router = require('express').Router();
const Route = require('../models/Route');
const auth = require('../middleware/auth');

const normalizeRoute = (body) => ({
  routeName: body.routeName,
  routeCode: body.routeCode,
  description: body.description || '',
  stops: (body.stops || []).map((stop, index) => ({
    name: String(stop.name || '').trim(),
    order: index + 1,
    monthlyFee: Number(stop.monthlyFee),
  })),
});

const validateRoute = (route) => {
  if (!route.routeName?.trim() || !route.routeCode?.trim()) return 'Route name and code are required';
  if (route.stops.some((stop) => !stop.name || !Number.isFinite(stop.monthlyFee) || stop.monthlyFee < 0)) {
    return 'Each stop requires a name and valid monthly fee';
  }
  return null;
};

router.get('/', async (req, res) => {
  try { res.json(await Route.find()); }
  catch (e) { res.status(500).json({ message: e.message }); }
});

router.post('/', auth, auth.adminOnly, async (req, res) => {
  try {
    const route = normalizeRoute(req.body);
    const error = validateRoute(route);
    if (error) return res.status(400).json({ message: error });
    res.status(201).json(await Route.create(route));
  }
  catch (e) { res.status(400).json({ message: e.message }); }
});

router.put('/:id', auth, auth.adminOnly, async (req, res) => {
  try {
    const route = normalizeRoute(req.body);
    const error = validateRoute(route);
    if (error) return res.status(400).json({ message: error });
    res.json(await Route.findByIdAndUpdate(req.params.id, route, { new: true, runValidators: true }));
  }
  catch (e) { res.status(400).json({ message: e.message }); }
});

router.delete('/:id', auth, auth.adminOnly, async (req, res) => {
  try { await Route.findByIdAndDelete(req.params.id); res.json({ message: 'Route deleted' }); }
  catch (e) { res.status(500).json({ message: e.message }); }
});

module.exports = router;
