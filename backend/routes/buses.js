const router = require('express').Router();
const Bus = require('../models/Bus');
const auth = require('../middleware/auth');

router.get('/active-trips', auth, async (req, res) => {
  try {
    const buses = await Bus.find({ tripStatus: 'ACTIVE', trackingStatus: 'LIVE' })
      .populate('routeId', 'routeName')
      .populate('driverId', 'name phone');
    res.json(buses.map((bus) => ({
      busId: bus._id,
      tripId: bus.tripId,
      route: bus.routeId,
      driver: bus.driverId,
      startedAt: bus.tripStartedAt,
      status: bus.tripStatus,
      trackingStatus: bus.trackingStatus,
    })));
  } catch (e) { res.status(500).json({ message: e.message }); }
});

router.get('/:id/active-trip', auth, async (req, res) => {
  try {
    const bus = await Bus.findOne({ _id: req.params.id, tripStatus: 'ACTIVE', trackingStatus: 'LIVE' }).populate('routeId', 'routeName');
    if (!bus) return res.status(404).json({ message: 'No active trip' });
    res.json({ busId: bus._id, tripId: bus.tripId, route: bus.routeId, startedAt: bus.tripStartedAt, status: bus.tripStatus, trackingStatus: bus.trackingStatus });
  } catch (e) { res.status(500).json({ message: e.message }); }
});

// Get all buses (optionally filter by route)
router.get('/', async (req, res) => {
  try {
    const filter = req.query.routeId ? { routeId: req.query.routeId } : {};
    const buses = await Bus.find(filter).populate('driverId').populate('routeId');
    res.json(buses);
  } catch (e) { res.status(500).json({ message: e.message }); }
});

// Get single bus
router.get('/:id', async (req, res) => {
  try {
    const bus = await Bus.findById(req.params.id).populate('driverId').populate('routeId');
    if (!bus) return res.status(404).json({ message: 'Bus not found' });
    res.json(bus);
  } catch (e) { res.status(500).json({ message: e.message }); }
});

// Add bus (admin only)
router.post('/', auth, auth.adminOnly, async (req, res) => {
  try {
    const bus = await Bus.create(req.body);
    res.status(201).json(bus);
  } catch (e) { res.status(400).json({ message: e.message }); }
});

// Update bus
router.put('/:id', auth, auth.adminOnly, async (req, res) => {
  try {
    const bus = await Bus.findByIdAndUpdate(req.params.id, req.body, { new: true });
    res.json(bus);
  } catch (e) { res.status(400).json({ message: e.message }); }
});

// Delete bus
router.delete('/:id', auth, auth.adminOnly, async (req, res) => {
  try {
    await Bus.findByIdAndDelete(req.params.id);
    res.json({ message: 'Bus deleted' });
  } catch (e) { res.status(500).json({ message: e.message }); }
});

module.exports = router;
