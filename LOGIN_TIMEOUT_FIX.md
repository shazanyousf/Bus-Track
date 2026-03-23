# BusTrack Login Timeout Fix Guide

## Issues Fixed

✅ **Added 10-second timeout** to all HTTP requests (both login and API calls)
✅ **Added request logging middleware** to identify slow queries
✅ **Added database indices** for faster email lookups
✅ **Better error messages** showing the server URL when connection fails

## Troubleshooting Login Timeout Issues

### 1. Check Backend Server is Running

```bash
cd backend
npm start
```

You should see:
```
✅ MongoDB connected
🚀 Server running → http://localhost:3000
```

### 2. Verify MongoDB is Running

**macOS with Homebrew:**
```bash
brew services start mongodb-community
```

Check if it's running:
```bash
brew services list | grep mongodb
```

**Manual Start:**
```bash
mongod --config /opt/homebrew/etc/mongod.conf
```

### 3. Check Your `.env.example`

The backend needs proper MongoDB connection:
```
PORT=3000
MONGO_URI=mongodb://localhost:27017/bustrack_university
JWT_SECRET=bustrack_secret_key_2024
NODE_ENV=development
```

### 4. Verify API Endpoint in Flutter

In `mobile/lib/services/auth_service.dart`, check the baseUrl:
- **For Android Emulator:** `http://10.0.2.2:3000/api`
- **For Physical Device:** Use your computer's IP (e.g., `http://192.168.1.100:3000/api`)
- **For iOS Simulator:** `http://localhost:3000/api`

Set via `.env` file:
```
API_BASE_URL=http://10.0.2.2:3000/api
```

### 5. Test Backend Directly

```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

### 6. Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| **"Connection timeout"** | Backend not running or wrong URL in `.env` |
| **"MongoDB error"** | MongoDB not running - use `brew services start mongodb-community` |
| **Slow login (5+ sec)** | Check backend logs for slow queries with `⚠️ SLOW:` warnings |
| **Phone can't reach localhost:3000** | Use your computer's IP instead of localhost |

### 7. Monitor Backend Performance

When you see login delays, check the backend logs for:
```
⚠️ SLOW: POST /api/auth/login - 2500ms
```

This helps identify if the issue is:
- **Network:** Usually < 100ms
- **Database:** Usually < 50ms per query
- **Server Processing:** > 500ms indicates slowness

## Changes Made

### Frontend (`mobile/lib/services/`)
- **auth_service.dart**: Added 10-second timeout to login & register
- **api_service.dart**: Added 10-second timeout to all API calls

### Backend (`backend/`)
- **server.js**: Added request logging middleware for debugging
- **models/User.js**: Added indices for email field (faster queries)

## Quick Start Commands

```bash
# Terminal 1: Start Backend
cd backend
npm start

# Terminal 2: Start MongoDB (if needed)
brew services start mongodb-community

# Terminal 3: Run Flutter App
cd mobile
flutter run
```

Then try logging in. If it still times out after 10 seconds, you'll get a clear error message showing the server URL it's trying to reach.
