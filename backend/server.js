const express    = require('express');
const mongoose   = require('mongoose');
const cors       = require('cors');
const http       = require('http');
const { Server } = require('socket.io');
require('dotenv').config();

const app    = express();
const server = http.createServer(app);
const io     = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] }
});

app.use(cors());
app.use(express.json());

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
app.use('/api/students',      require('./routes/students'));

app.get('/', (req, res) =>
  res.json({ message: 'BusTrack University API ✅', version: '2.0' }));

// ── Socket.io — Real-Time GPS Tracking ──────────────────────────────────────
const activeBuses = {}; // { busId: { latitude, longitude, speed, timestamp } }

io.on('connection', (socket) => {
  console.log(`📱 Client connected: ${socket.id}`);

  // Driver sends their GPS location
  // Payload: { busId, latitude, longitude, speed }
  socket.on('driver:location', (data) => {
    if (!data.busId) return;

    activeBuses[data.busId] = {
      ...data,
      timestamp: new Date().toISOString(),
    };

    // Broadcast to all parents watching this bus
    io.emit(`bus:location:${data.busId}`, activeBuses[data.busId]);

    console.log(`🚌 Bus ${data.busId} → lat:${data.latitude?.toFixed(4)} lng:${data.longitude?.toFixed(4)} speed:${data.speed?.toFixed(0)}km/h`);
  });

  // Client can request last known position on connect
  socket.on('bus:request:${busId}', (busId) => {
    if (activeBuses[busId]) {
      socket.emit(`bus:location:${busId}`, activeBuses[busId]);
    }
  });

  socket.on('disconnect', () => {
    console.log(`📴 Client disconnected: ${socket.id}`);
  });
});

// ── Demo simulation (remove in production) ──────────────────────────────────
// Simulates BUS001 moving in a circle so you can test without a real driver
let angle = 0;
setInterval(() => {
  angle += 0.015;
  const data = {
    busId:     'DEMO_BUS',
    latitude:  24.8607 + Math.sin(angle) * 0.008,
    longitude: 67.0011 + Math.cos(angle) * 0.008,
    speed:     Math.round(25 + Math.random() * 20),
    timestamp: new Date().toISOString(),
  };
  activeBuses['DEMO_BUS'] = data;
  io.emit('bus:location:DEMO_BUS', data);
}, 2000);

// ── MongoDB + Start ──────────────────────────────────────────────────────────
const PORT      = process.env.PORT     || 3000;
const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/bustrack_university';

mongoose.connect(MONGO_URI)
  .then(() => {
    console.log('✅ MongoDB connected');
    server.listen(PORT, () =>
      console.log(`🚀 Server running  →  http://localhost:${PORT}`));
  })
  .catch(err => {
    console.error('⚠️  MongoDB error:', err.message);
    console.log('Starting without DB (demo mode)...');
    server.listen(PORT, () =>
      console.log(`🚀 Server running  →  http://localhost:${PORT}`));
  });
