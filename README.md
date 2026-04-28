# 🚌 BusTrack — University Transport System v2.1
### Flutter + Node.js + Express + MongoDB + Socket.io (Real-Time GPS + Map Fixes)


---

## ✅ FEATURES

| Feature | Status |
|---------|--------|
| Parent login & dashboard | ✅ |
| Admin dashboard (buses/drivers/routes/settings) | ✅ |
| Driver GPS broadcast & alerts | ✅ |
| Live bus tracking (FlutterMap OSM)| ✅ |
| Registration with departments | ✅ |
| Approve/Reject requests | ✅ |
| Bus/Driver/Route management | ✅ |
| Seat availability | ✅ |
| Real-time Socket.io GPS | ✅ |
| Route stops/markers on map | ✅ |
| Parent bus lists & details | ✅ |

---

## 🚀 QUICK START

### 1. Backend
```bash
cd backend
npm install
npm run dev  # http://localhost:3000
```

### 2. Mobile App
```bash
cd mobile
flutter pub get
flutter run
```

**Note:** Uses OpenStreetMap (no API key needed). Live GPS works out-of-box.

---

## 🎮 ROLES & FLOW

**👨‍👩‍👧 Parent:**
```
Login → Home → Bus List → Live Tracking (map + GPS + stops)
                         ↓
                     Registration Form
```

**🛡 Admin:**
```
Login → Dashboard → Manage Buses/Drivers/Routes/Requests
```

**🚌 Driver:**
```
Login → Select Bus → Start GPS Broadcast → Send Alerts
```

---

## 🗺️ MAP (Fixed)
- **FlutterMap + OpenStreetMap** (free, no keys).
- **Fix:** Dark overlays lightened (0.25 opacity glass effect).
- Bus marker (orange), route polyline (blue), stops (green/red/blue).
- Pan/zoom/pinch full screen.
- GPS updates every ~2s via Socket.io.

---

## 📡 REAL-TIME GPS
Driver broadcasts position → server → all parents on that bus see live updates.

---

## 🔧 SETUP NOTES

- **MongoDB:** Use Atlas free tier, add connection string to backend/.env.
- **Emulator GPS:** Android Studio → Extended Controls → Location.
- **Network:** Emulator uses `10.0.2.2:3000`, device uses PC IP.

---

## 📱 TEST ACCOUNTS
Create via app or POST /api/auth/register:
```
{ "name": "Test Parent", "email": "parent@test.com", "password": "123", "role": "parent" }
```

---

## 📁 PROJECT STRUCTURE
```
bustrack/
├── backend/       Node/Express/Mongo/Socket.io
├── mobile/        Flutter app (3 roles)
├── README.md      ← This file
```

**Production ready.** Run `flutter build apk` for Android release.
