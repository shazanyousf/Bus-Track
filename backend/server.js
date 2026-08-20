const express    = require('express');
const mongoose   = require('mongoose');
const cors       = require('cors');
const http       = require('http');
const path       = require('path');
const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const Bus = require('./models/Bus');
const Driver = require('./models/Driver');
const Registration = require('./models/Registration');
const User = require('./models/User');
require('dotenv').config();

const app    = express();
const server = http.createServer(app);
const io     = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] }
});
app.set('io', io);

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// ── Request Logging Middleware ──────────────────────────────────────────────
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    if (duration > 500) {
      console.log(`⚠️  SLOW: ${req.method} ${req.path} - ${duration}ms`);
    }
  });
  next();
});

// ── Routes ──────────────────────────────────────────────────────────────────
app.use('/api/auth',          require('./routes/auth'));
app.use('/api/buses',         require('./routes/buses'));
app.use('/api/drivers',       require('./routes/drivers'));
app.use('/api/registrations', require('./routes/registrations'));
app.use('/api/routes',        require('./routes/busRoutes'));
app.use('/api/settings',      require('./routes/settings'));
app.use('/api/students',      require('./routes/students'));
app.use('/api/notices',       require('./routes/notices'));
app.use('/api/users',         require('./routes/users'));
app.use('/api/admin',         require('./routes/admin'));
app.use('/api/reports',       require('./routes/reports'));

app.get('/api', (req, res) =>
  res.json({
    message: 'BusTrack School API is running',
    routes: ['/api/auth', '/api/buses', '/api/drivers', '/api/routes', '/api/registrations', '/api/settings', '/api/students', '/api/notices']
  })
);

app.get('/', (req, res) =>
  res.json({ message: 'BusTrack School API', version: '2.0' }));

// ── Socket.io — Real-Time GPS Tracking ──────────────────────────────────────
const activeBuses = {}; // { busId: { busId, tripId, lat, lng, speed, timestamp } }
const activeTrips = {}; // { busId: { busId, tripId, routeId, startedAt } }
app.set('activeBuses', activeBuses);
app.set('activeTrips', activeTrips);

io.on('connection', (socket) => {
  console.log(`📱 Client connected: ${socket.id}`);
  const token = socket.handshake.auth?.token;
  if (token) {
    try {
      socket.user = jwt.verify(token, process.env.JWT_SECRET || 'bustrack_secret');
    } catch (_) {
      socket.user = null;
    }
  }

  const driverCanUseBus = async (busId) => {
    if (socket.user?.role !== 'driver') return { ok: false, reason: 'socket is not an authenticated driver' };
    const user = await User.findOne({ _id: socket.user.id, role: 'driver' }).select('_id phone').lean().catch(() => null);
    if (!user) return { ok: false, reason: 'driver user was not found' };
    if (!user.phone) return { ok: false, reason: 'driver user has no phone for Driver lookup' };
    const bus = await Bus.findById(busId).select('driverId').lean().catch(() => null);
    if (!bus?.driverId) return { ok: false, reason: 'bus has no assigned driverId' };
    const driver = await Driver.findOne({ _id: bus.driverId, phone: user.phone }).select('_id').lean().catch(() => null);
    return driver
      ? { ok: true }
      : { ok: false, reason: 'Bus.driverId does not match the authenticated driver phone' };
  };

  // Driver sends their GPS location
  // Payload: { busId, latitude, longitude, speed }
 socket.on('driver:trip:start', async (data) => {
  console.log('TRIP START REQUEST', { driverId: socket.user?.id || 'anonymous', busId: data.busId, tripId: data.tripId });
  if (!data.busId || !data.tripId) return console.log('TRIP START REJECTED: busId and tripId are required');
  const authorization = await driverCanUseBus(data.busId);
  if (!authorization.ok) return console.log(`TRIP START REJECTED: ${authorization.reason}`);
  const bus = await Bus.findOneAndUpdate({
    _id: data.busId,
    tripStatus: { $ne: 'ACTIVE' },
    tripId: { $ne: data.tripId },
  }, {
    $set: {
      tripStatus: 'ACTIVE', trackingStatus: 'LIVE', tripId: data.tripId,
      tripStartedAt: new Date(), tripCompletedAt: null,
    },
  }, { new: true }).catch(() => null);
  if (!bus) return console.log('TRIP START REJECTED: bus is already active or trip state changed');
  const trip = {
    busId: data.busId,
    tripId: data.tripId,
    routeId: bus.routeId?.toString(),
    startedAt: bus.tripStartedAt,
    currentLocation: activeBuses[data.busId] || null,
  };
  activeTrips[data.busId] = trip;
  io.emit('trip:started', trip);
});

 socket.on('driver:trip:complete', async (data) => {
  console.log('TRIP COMPLETE REQUEST', { driverId: socket.user?.id || 'anonymous', busId: data.busId, tripId: data.tripId });
  if (!data.busId || !data.tripId) return console.log('TRIP COMPLETE REJECTED: busId and tripId are required');
  const authorization = await driverCanUseBus(data.busId);
  if (!authorization.ok) return console.log(`TRIP COMPLETE REJECTED: ${authorization.reason}`);
  const bus = await Bus.findOneAndUpdate(
    { _id: data.busId, tripId: data.tripId, tripStatus: 'ACTIVE' },
    { $set: { tripStatus: 'COMPLETED', trackingStatus: 'OFFLINE', tripCompletedAt: new Date() } },
    { new: true },
  ).catch(() => null);
  if (!bus) return console.log('TRIP COMPLETE REJECTED: trip does not match active bus');
  delete activeTrips[data.busId];
  delete activeBuses[data.busId];
  io.emit('trip:completed', { busId: data.busId, tripId: data.tripId, completedAt: bus.tripCompletedAt });
});

 socket.on('driver:location', async (data) => {
  const lat = Number(data.latitude ?? data.lat);
  const lng = Number(data.longitude ?? data.lng);
  console.log('LOCATION RECEIVED', { driverId: socket.user?.id || 'anonymous', busId: data.busId, tripId: data.tripId || null, lat, lng });
  if (!data.busId) return console.log('LOCATION REJECTED: busId is required');
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return console.log('LOCATION REJECTED: latitude/longitude are invalid');
  const authorization = await driverCanUseBus(data.busId);
  if (!authorization.ok) return console.log(`LOCATION REJECTED: ${authorization.reason}`);
  const bus = await Bus.findOne({ _id: data.busId, tripStatus: 'ACTIVE', trackingStatus: 'LIVE' }).select('_id tripId').lean();
  if (!bus) return console.log('LOCATION REJECTED: bus is not ACTIVE/LIVE');
  const tripId = data.tripId || bus.tripId || null;

  const formattedData = {
    busId: data.busId,
    tripId,
    lat,
    lng,
    latitude: lat,
    longitude: lng,
    speed: data.speed,
    timestamp: new Date().toISOString(),
  };

  activeBuses[data.busId] = formattedData;
  await Bus.updateOne({ _id: data.busId }, { $set: { 'currentLocation.latitude': lat, 'currentLocation.longitude': lng } }).catch((error) => {
    console.log(`LOCATION PERSIST FAILED: ${error.message}`);
  });

  io.emit(`bus:location:${data.busId}`, formattedData);
  io.emit('trip:location', formattedData);

  console.log('LOCATION BROADCAST', { busId: data.busId, tripId: data.tripId, lat, lng });
});

  // Client can request last known position on connect
  socket.on('bus:request', async (busId) => {
  if (!busId) return;
  if (activeBuses[busId]) {
    return socket.emit(`bus:location:${busId}`, activeBuses[busId]);
  }

  const bus = await Bus.findOne({
    _id: busId,
    tripStatus: 'ACTIVE',
    trackingStatus: 'LIVE',
  }).select('_id tripId currentLocation updatedAt').lean().catch(() => null);
  const latitude = Number(bus?.currentLocation?.latitude);
  const longitude = Number(bus?.currentLocation?.longitude);
  if (!bus || !Number.isFinite(latitude) || !Number.isFinite(longitude) ||
      (latitude === 0 && longitude === 0)) {
    return;
  }

  socket.emit(`bus:location:${busId}`, {
    busId,
    tripId: bus.tripId,
    lat: latitude,
    lng: longitude,
    latitude,
    longitude,
    speed: 0,
    timestamp: bus.updatedAt?.toISOString() || new Date().toISOString(),
  });
});

  // Driver issue / traffic update -> broadcast to all parents for this bus
  socket.on('driver:alert', (data) => {
    if (!data.busId || !data.message) return;

    const alertPayload = {
      busId: data.busId,
      type: data.type || 'info',
      message: data.message,
      timestamp: new Date().toISOString(),
    };

    io.emit(`bus:alert:${data.busId}`, alertPayload);
    io.emit('bus:alert', alertPayload); // optional global channel

    console.log(`🚨 Bus ${data.busId} alert (${alertPayload.type}): ${alertPayload.message}`);
  });

  socket.on('disconnect', () => {
    console.log(`📴 Client disconnected: ${socket.id}`);
  });
});

// ── Demo simulation (remove in production) ──────────────────────────────────
// Simulates BUS001 moving in a circle so you can test without a real driver

// let angle = 0;
// setInterval(() => {
//   angle += 0.015;
//   const data = {
//     busId:     'DEMO_BUS',                           //just checking
//     latitude:  24.8607 + Math.sin(angle) * 0.008,
//     longitude: 67.0011 + Math.cos(angle) * 0.008,
//     speed:     Math.round(25 + Math.random() * 20),
//     timestamp: new Date().toISOString(),
//   };
//   activeBuses['DEMO_BUS'] = data;
//   io.emit('bus:location:DEMO_BUS', data);
// }, 2000);

// ── MongoDB + Start ──────────────────────────────────────────────────────────
const PORT      = process.env.PORT     || 3000;
const MONGO_URI = process.env.MONGODB_URI || process.env.MONGO_URI || 'mongodb://localhost:27017/bustrack_school';

async function reconcileBusSeats() {
  const assignments = await Registration.aggregate([
    { $match: { status: 'active', assignmentStatus: 'ASSIGNED', busId: { $ne: null } } },
    { $group: { _id: '$busId', assigned: { $sum: 1 } } },
  ]);
  const assignedByBus = new Map(assignments.map((entry) => [entry._id.toString(), entry.assigned]));
  const buses = await Bus.find({}, 'totalSeats availableSeats');
  await Promise.all(buses.map((bus) => {
    const assigned = assignedByBus.get(bus._id.toString()) || 0;
    const availableSeats = Math.max(bus.totalSeats - assigned, 0);
    if (bus.availableSeats === availableSeats) return null;
    return Bus.updateOne({ _id: bus._id }, { $set: { availableSeats } });
  }));
  console.log(`🪑 Reconciled seats for ${buses.length} bus(es)`);
}

async function hydrateActiveTrips() {
  const buses = await Bus.find({ tripStatus: 'ACTIVE', trackingStatus: 'LIVE' }).select('_id tripId routeId tripStartedAt currentLocation').lean();
  buses.forEach((bus) => {
    const busId = bus._id.toString();
    activeTrips[busId] = {
      busId,
      tripId: bus.tripId,
      routeId: bus.routeId?.toString(),
      startedAt: bus.tripStartedAt,
    };
    const latitude = Number(bus.currentLocation?.latitude);
    const longitude = Number(bus.currentLocation?.longitude);
    if (Number.isFinite(latitude) && Number.isFinite(longitude) && (latitude !== 0 || longitude !== 0)) {
      activeBuses[busId] = {
        busId,
        tripId: bus.tripId,
        latitude,
        longitude,
        lat: latitude,
        lng: longitude,
        timestamp: bus.updatedAt?.toISOString() || new Date().toISOString(),
      };
    }
  });
  console.log(`🚍 Restored ${buses.length} active trip(s)`);
}

mongoose.connect(MONGO_URI)
  .then(() => {
    console.log('✅ MongoDB connected');
    return reconcileBusSeats().then(hydrateActiveTrips);
  })
  .then(() => {
    
    server.listen(PORT, '0.0.0.0', () =>
      console.log(`🚀 Server running  →  http://0.0.0.0:${PORT} (accessible from Android emulator at 10.0.2.2:${PORT})`));
  })

  .catch(err => {
    console.error('⚠️  MongoDB error:', err.message);
    console.log('Starting without DB (demo mode)...');
    server.listen(PORT, '0.0.0.0', () =>
      console.log(`🚀 Server running  →  http://0.0.0.0:${PORT} (accessible from Android emulator at 10.0.2.2:${PORT})`));
  });
