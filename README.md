# 🚌 BusTrack — University Transport System v2.0
### Flutter + Node.js + Express + MongoDB + Socket.io (Real-Time GPS)

---

## ✅ WHAT'S INCLUDED

| Feature                         | Status |
|---------------------------------|--------|
| Parent login & dashboard        | ✅ Done |
| Admin login & dashboard         | ✅ Done |
| Driver login & GPS broadcast    | ✅ Done |
| Live bus tracking (Google Maps) | ✅ Done |
| Bus registration with departments | ✅ Done |
| Approve / Reject requests       | ✅ Done |
| Manage buses & drivers          | ✅ Done |
| Seat map visualization          | ✅ Done |
| Real-time Socket.io GPS         | ✅ Done |
| Route stops on map              | ✅ Done |

---

## ⚡ COMMANDS TO START

### Terminal 1 — Backend
```bash
cd bustrack/backend
npm install
npm run dev
```
You should see:
```
✅ MongoDB connected
🚀 Server running → http://localhost:3000
```

### Terminal 2 — Flutter App
```bash
cd bustrack/mobile
flutter pub get
flutter run
```

---

## 🗺️ GOOGLE MAPS API KEY SETUP (Required for maps)

### Step 1 — Get a free key (5 minutes)
1. Go to https://console.cloud.google.com
2. Create a new project (e.g. "BusTrack")
3. Go to **APIs & Services → Enable APIs**
4. Enable: **Maps SDK for Android** + **Maps SDK for iOS**
5. Go to **APIs & Services → Credentials → Create Credentials → API Key**
6. Copy your API key

### Step 2 — Add it to Android
Open: `mobile/android/app/src/main/AndroidManifest.xml`
Find this line and replace `YOUR_GOOGLE_MAPS_API_KEY`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>   ← paste key here
```

### Step 3 — Add it to iOS (Mac only)
Open: `mobile/ios/Runner/Info.plist`
Find and replace:
```xml
<key>GMSApiKey</key>
<string>YOUR_GOOGLE_MAPS_API_KEY</string>   ← paste key here
```

---

## 👥 CREATE ACCOUNTS

Use **Thunder Client** (VS Code extension) or **Postman**:

### Create Admin:
```
POST http://localhost:3000/api/auth/register
{
  "name": "University Admin",
  "email": "admin@university.edu",
  "password": "admin123",
  "role": "admin"
}
```

### Create Parent:
```
POST http://localhost:3000/api/auth/register
{
  "name": "Ahmed Khan",
  "email": "parent@university.edu",
  "password": "parent123",
  "role": "parent"
}
```

### Create Driver:
```
POST http://localhost:3000/api/auth/register
{
  "name": "Bus Driver Ali",
  "email": "driver@university.edu",
  "password": "driver123",
  "role": "driver"
}
```

> Each role opens a different screen automatically after login.

---

## 📱 THREE SEPARATE DASHBOARDS

### 👨‍👩‍👧 Parent Dashboard
- See assigned bus, driver details, route
- Live GPS tracking with Google Maps
- Register child for a bus (select department & semester)
- View all registration requests and their status

### 🛡 Admin Dashboard
- View all buses, add/delete buses
- View all drivers, add/delete drivers
- Approve or reject registration requests (with optional rejection reason)
- Overview stats

### 🚌 Driver Dashboard (NEW)
- Select which bus you are driving
- Tap **"Start Route & Broadcast GPS"**
- Your phone GPS is sent via Socket.io every 5 metres to the server
- All parents watching that bus see your live position on their maps
- Shows your current speed and trip duration
- Tap **"Stop Broadcasting"** when route ends

---

## 📡 HOW REAL-TIME GPS WORKS

```
Driver Phone                Server              Parent Phone
    |                          |                      |
    |  driver:location event   |                      |
    |  { busId, lat, lng, spd }|                      |
    |─────────────────────────>|                      |
    |                          |  bus:location:BUS001 |
    |                          |─────────────────────>|
    |                          |  { lat, lng, speed } |
    |                          |                      | ← map moves!
```

- Driver emits location every ~2 seconds (or every 5 metres of movement)
- Server rebroadcasts to ALL connected clients watching that bus
- Parent map animates the bus marker to new position
- Speed, timestamp and route stops shown in bottom panel

---

## 🔧 REQUIREMENTS

| Tool        | Version | Download                                |
|-------------|---------|-----------------------------------------|
| Node.js     | 18+ LTS | https://nodejs.org                      |
| Flutter SDK | 3.x     | https://flutter.dev/docs/get-started    |
| Android Studio | Latest | https://developer.android.com/studio  |
| MongoDB     | Any     | https://cloud.mongodb.com (free Atlas)  |

---

## 🌐 CONNECTION SETTINGS

| Device           | API_BASE_URL in mobile/.env                  |
|------------------|----------------------------------------------|
| Android Emulator | http://10.0.2.2:3000/api  (default ✅)       |
| iOS Simulator    | http://localhost:3000/api                    |
| Real Device      | http://YOUR_PC_IP:3000/api                   |

Find your PC IP: `ipconfig` (Windows) or `ifconfig` (Mac/Linux)

---

## ⚠️ COMMON ISSUES

**Maps not showing / blank screen:**
→ You haven't added your Google Maps API key yet (see step above)

**Flutter can't connect to server:**
→ Make sure `npm run dev` is running
→ Android emulator uses 10.0.2.2, not localhost

**GPS not working on emulator:**
→ In Android Studio emulator: click the 3-dot menu → Location → set a fake location

**MongoDB connection error:**
→ Server still starts without DB — create an Atlas free account at cloud.mongodb.com
