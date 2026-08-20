const express    = require('express');
const mongoose   = require('mongoose');
const cors       = require('cors');
const http       = require('http');
const path       = require('path');
const { Server } = require('socket.io');
const Bus = require('./models/Bus');
const Registration = require('./models/Registration');
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
const activeBuses = {}; // { busId: { latitude, longitude, speed, timestamp } }

io.on('connection', (socket) => {
  console.log(`📱 Client connected: ${socket.id}`);

  // Driver sends their GPS location
  // Payload: { busId, latitude, longitude, speed }
 socket.on('driver:location', (data) => {
  if (!data.busId) return;

  const formattedData = {
    busId: data.busId,
    lat: data.lat,
    lng: data.lng,
    speed: data.speed,
    timestamp: new Date().toISOString(),
  };

  activeBuses[data.busId] = formattedData;

  io.emit(`bus:location:${data.busId}`, formattedData);

  console.log(`🚌 Bus ${data.busId} → lat:${data.lat?.toFixed(4)} lng:${data.lng?.toFixed(4)} speed:${data.speed?.toFixed(0)}km/h`);
});

  // Client can request last known position on connect
  socket.on('bus:request', (busId) => {
  if (activeBuses[busId]) {
    socket.emit(`bus:location:${busId}`, activeBuses[busId]);
  }
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

mongoose.connect(MONGO_URI)
  .then(() => {
    console.log('✅ MongoDB connected');
    return reconcileBusSeats();
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
