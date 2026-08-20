# BusTrack

School transport tracking system with a Node.js backend and a Flutter mobile app.

## Overview

The repository contains two apps:

- `backend/` - Express API with MongoDB, JWT auth, file uploads, email verification, and Socket.io GPS updates
- `mobile/` - Flutter app with admin, parent, and driver screens

The current code supports:

- Parent registration with email verification
- Verified user login
- Password reset by email code
- Admin management of buses, drivers, routes, users, settings, students, registrations, and notices
- Driver GPS broadcasting and bus alerts through Socket.io
- Parent bus tracking screens with live updates

## Project Structure

```text
bustrack/
├── backend/
│   ├── server.js
│   ├── cleanup.js
│   ├── middleware/
│   ├── models/
│   ├── routes/
│   └── uploads/
├── mobile/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   ├── services/
│   │   └── widgets/
│   ├── android/
│   └── ios/
└── README.md
```

## Requirements

- Node.js 18+ and npm
- Flutter SDK 3.x
- MongoDB Atlas or a local MongoDB instance
- Android Studio or Xcode for mobile builds

## Backend Setup

```bash
cd backend
npm install
npm run dev
```

The backend starts on port `3000` by default. If MongoDB is unavailable, the server still starts in demo mode, but database-backed features will not work normally.

### Backend Environment

Create `backend/.env` with at least:

```env
PORT=3000
MONGODB_URI=mongodb://localhost:27017/bustrack_school
JWT_SECRET=bustrack_secret
SMTP_HOST=
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=
SMTP_PASS=
EMAIL_FROM=
```

SMTP settings are optional, but they are required if you want registration and password-reset emails to be delivered.

## Mobile Setup

```bash
cd mobile
flutter pub get
flutter run
```

### Mobile Environment

The Flutter app loads `mobile/.env` at startup. The code looks for:

```env
API_BASE_URL=http://127.0.0.1:3000/api
SOCKET_URL=http://127.0.0.1:3000
```

If you are running on an Android emulator, `127.0.0.1` can be replaced with `10.0.2.2` or an accessible machine IP depending on your setup.

## Authentication Flow

The app currently uses these auth flows:

- `POST /api/auth/register` creates a pending parent registration and sends a verification code
- `POST /api/auth/verify-registration` completes registration after the code is entered
- `POST /api/auth/login` only accepts verified users
- `POST /api/auth/forgot-password` sends a reset code
- `POST /api/auth/verify-reset-code` checks the reset code
- `POST /api/auth/reset-password` sets a new password

Pending registrations are stored in the `User` collection. The cleanup script only removes legacy unverified users that do not have an active verification code or expiry.

## API Routes

The backend mounts these route groups:

- `/api/auth`
- `/api/buses`
- `/api/drivers`
- `/api/registrations`
- `/api/routes`
- `/api/settings`
- `/api/students`
- `/api/notices`
- `/api/users`

The root server responses are:

- `GET /` - basic API status
- `GET /api` - API status plus route list

## Realtime Socket Events

Socket.io is used for live bus tracking and alerts.

- Driver emits `driver:location` with `{ busId, lat, lng, speed }`
- Server broadcasts `bus:location:<busId>` to listeners
- Client can request the latest position with `bus:request`
- Driver emits `driver:alert` with `{ busId, message, type }`
- Server broadcasts `bus:alert:<busId>` and the global `bus:alert` channel

## App Screens

The Flutter app includes screens for:

- Splash and login/signup flow
- Parent home, bus list, bus details, registration, my registrations, live tracking
- Admin home, buses, drivers, routes, requests, settings, users
- Driver home
- Shared notices and account screens

## Cleanup Script

Run the legacy cleanup only when you need to remove old unverified users:

```bash
cd backend
node cleanup.js
```

## Notes

- The app uses `flutter_map` with OpenStreetMap tiles, so no map API key is required.
- `mobile/lib/main.dart` sets the app theme and starts at the splash screen.
- `mobile/lib/services/api_service.dart` and `mobile/lib/services/socket_service.dart` contain the API and realtime client wiring.
