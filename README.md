# BusTrack

Smart school transport tracking and management system with a Node.js Express backend and a Flutter mobile app.

## Overview

BusTrack is a comprehensive school transport platform that enables:

- **Administrators** to manage buses, drivers, routes, students, registrations, and notices
- **Drivers** to broadcast GPS location, send alerts, and track their trips
- **Parents** to view buses, register students, track live bus location, and receive notifications
- **Real-time Communication** through Socket.io for live GPS updates and alerts

The repository contains:

- `backend/` - Express.js API with MongoDB, JWT authentication, email verification, file uploads, Socket.io integration, and Razorpay payment gateway
- `mobile/` - Flutter cross-platform app (iOS/Android) with role-based screens for parents, admins, and drivers

## Project Structure

```text
bustrack/
├── backend/
│   ├── server.js                 # Main Express server with Socket.io setup
│   ├── cleanup.js               # Legacy user cleanup utility
│   ├── package.json
│   ├── middleware/
│   │   └── auth.js              # JWT authentication middleware
│   ├── models/                  # Mongoose schemas
│   │   ├── User.js              # Users and pending registrations
│   │   ├── Student.js
│   │   ├── Bus.js
│   │   ├── Driver.js
│   │   ├── Route.js
│   │   ├── Registration.js
│   │   ├── Notice.js
│   │   ├── MonthlyPayment.js
│   │   ├── SupportQuery.js
│   │   └── Setting.js
│   ├── routes/                  # API route handlers
│   │   ├── auth.js              # Authentication endpoints
│   │   ├── buses.js
│   │   ├── drivers.js
│   │   ├── students.js
│   │   ├── registrations.js
│   │   ├── routes.js
│   │   ├── notices.js
│   │   ├── users.js
│   │   ├── settings.js
│   │   ├── admin.js             # Admin management
│   │   ├── support.js           # Support queries
│   │   ├── reports.js           # Report generation
│   │   └── auth.js
│   └── uploads/                 # File uploads directory
│       ├── notices/
│       └── support/
├── mobile/
│   ├── lib/
│   │   ├── main.dart            # App entry point and theme
│   │   ├── screens/             # UI screens
│   │   ├── services/            # API and Socket.io clients
│   │   └── widgets/             # Reusable UI components
│   ├── pubspec.yaml
│   ├── android/                 # Android-specific configuration
│   ├── ios/                     # iOS-specific configuration
│   └── build/                   # Build output (generated)
└── README.md
```

## Requirements

- **Node.js** 18+ with npm
- **Flutter SDK** 3.x
- **MongoDB** Atlas or local MongoDB instance (required for full functionality)
- **Android Studio** or **Xcode** for building mobile apps
- **Email Service** (Brevo) - optional, required for registration and password reset emails
- **Razorpay Account** - optional, required for payment processing features

## Backend Setup

### Installation

```bash
cd backend
npm install
npm run dev
```

The backend server starts on port `3000` by default and connects to MongoDB. If MongoDB is unavailable, the server will still start but database operations will fail.

### Environment Configuration

Create `backend/.env` with the following settings:

```env
# Server
PORT=3000

# Database
MONGODB_URI=mongodb://localhost:27017/bustrack_school

# Authentication
JWT_SECRET=your_secret_key_here




## Mobile Setup

### Installation

```bash
cd mobile
flutter pub get
flutter run
```

### Environment Configuration

Create `mobile/.env` at the project root with:

```env
API_BASE_URL=http://127.0.0.1:3000/api
SOCKET_URL=http://127.0.0.1:3000
```

### Network Configuration

- **For local development on physical device:** Replace `127.0.0.1` with your machine's IP address
- **For Android emulator:** Use `10.0.2.2` to access the host machine
- **For iOS simulator:** Use `127.0.0.1` or your machine's IP

### Build Notes

**Android Build Issues:**

If you encounter Kotlin daemon cache registration errors:

1. Update `mobile/android/gradle.properties`:
   ```properties
   kotlin.incremental=false
   kotlin.compiler.execution.strategy=in-process
   ```

2. Clean and rebuild:
   ```bash
   cd mobile
   ./android/gradlew --stop
   rm -rf build android/.gradle
   flutter clean
   flutter pub get
   flutter run -d emulator-5554
   ```

## Authentication Flow

### User Registration & Email Verification

1. **Parent Registration:**
   - `POST /api/auth/register` - Creates a pending user and sends verification code to email
   - `POST /api/auth/verify-registration` - Completes registration after entering verification code
   - User must verify their email before they can log in

2. **Verified Login:**
   - `POST /api/auth/login` - Only verified users can log in and receive JWT token
   - JWT token includes `userId` and `sessionId` for session management
   - Failed attempts increment login failure counter

3. **Password Recovery:**
   - `POST /api/auth/forgot-password` - Sends password reset code to registered email
   - `POST /api/auth/verify-reset-code` - Validates the reset code
   - `POST /api/auth/reset-password` - Sets new password after code verification

### Session Management

- Each user login creates a new session
- `sessionId` is stored in both JWT token and User document
- Only one active session per user; logging in on another device revokes previous session
- Socket.io connections verify that the `sessionId` matches the stored value
- Session revocation triggers `session:revoked` event to notify disconnected clients

### Pending Registrations

- Pending registrations are stored in the `User` collection with `role: 'pending'`
- `verificationCode` and `verificationExpiry` fields track the verification state
- The cleanup script only removes legacy unverified users without active verification codes

## API Routes

The backend exposes the following API route groups:

| Route | Purpose |
|-------|---------|
| `/api/auth` | User registration, login, password reset, and session management |
| `/api/buses` | Bus CRUD operations and bus tracking data |
| `/api/drivers` | Driver management and driver profile operations |
| `/api/registrations` | Student registration and registration requests |
| `/api/routes` | Bus route management and route details |
| `/api/settings` | School and system settings configuration |
| `/api/students` | Student profile and data management |
| `/api/notices` | Notice creation, distribution, and retrieval |
| `/api/users` | User management (admins, drivers, parents) |
| `/api/support` | Support queries and help requests |
| `/api/admin` | Administrative operations and dashboard data |
| `/api/reports` | Report generation and data export |

### Root Endpoints

- `GET /` - Basic API status and version info
- `GET /api` - API status with complete route list

## Real-Time Communication (Socket.io)

Socket.io is used for live bus tracking, alerts, and session management.

### GPS Location Events

- **Driver broadcasts location:**
  ```
  Event: 'driver:location'
  Data: { busId, tripId, lat, lng, speed, timestamp }
  ```

- **Server broadcasts to listeners:**
  ```
  Event: 'bus:location:<busId>'
  Sent to: All clients listening to that bus
  ```

- **Request latest position:**
  ```
  Event: 'bus:request'
  Purpose: Clients can request the current position of a bus
  ```

### Alert Events

- **Driver sends alert:**
  ```
  Event: 'driver:alert'
  Data: { busId, message, type }
  ```

- **Server broadcasts alerts:**
  ```
  Events: 'bus:alert:<busId>' (specific bus)
           'bus:alert' (global broadcast)
  ```

### Session Management

- Socket connections must provide JWT token in handshake auth
- Server validates token and verifies active session
- If session is revoked (user logged in elsewhere), socket receives:
  ```
  Event: 'session:revoked'
  Data: { userId, sessionId, message }
  ```

### Connection Requirements

To connect with a valid session:
```
socket.handshake.auth = { token: '<JWT_TOKEN>' }
```

## Mobile App Screens

The Flutter app provides role-based screens for different user types:

### Parent/User Screens

- **Authentication**
  - Splash screen
  - Login screen
  - Registration screen with email verification
  - Password reset flow

- **Main Features**
  - Home screen with quick actions
  - Bus list and bus details with live tracking
  - Student registration management
  - My registrations view
  - Live bus tracking map

- **Shared Screens**
  - Notices and announcements
  - Account and profile management

### Admin Screens

- Dashboard with overview metrics
- Bus management (add, edit, delete)
- Driver management and assignment
- Route management
- Registration requests handling
- Student management
- Settings configuration
- User management
- Reports and analytics

### Driver Screens

- Driver home/dashboard
- Active trip management
- GPS location broadcasting
- Bus alerts and notifications

### Map Integration

- Uses `flutter_map` with OpenStreetMap tiles
- No map API key required
- Real-time driver and bus location display
- Route visualization

## Cleanup & Maintenance

### Legacy User Cleanup

The cleanup script removes old unverified users that no longer have active verification codes:

```bash
cd backend
node cleanup.js
```

**Important:** The script only deletes legacy unverified users without active `verificationCode` or `verificationExpiry` values. It will not remove:
- Currently pending registrations with active verification codes
- Verified users
- Users with recent verification attempts

## Key Features & Notes

### Technology Stack

**Backend:**
- Express.js for REST API
- MongoDB with Mongoose ODM
- Socket.io for real-time communication
- JWT for stateless authentication
- Multer for file uploads
- Razorpay for payment processing
- ExcelJS for report generation

**Mobile:**
- Flutter for cross-platform development
- Provider for state management
- `flutter_map` with OpenStreetMap for mapping
- `geolocator` for GPS tracking
- `socket_io_client` for real-time updates
- `razorpay_flutter` for payment integration
- `flutter_local_notifications` for push notifications
- `file_picker` for document uploads

### Important Notes

- **Maps:** The app uses OpenStreetMap tiles via `flutter_map`, requiring no external map API key
- **GPS Tracking:** Drivers must grant location permissions for GPS broadcasting to work
- **Email Verification:** Parents must verify their email before they can log in
- **Session Management:** Users can only have one active session at a time
- **File Uploads:** Notices and support files are stored in `/backend/uploads/`
- **Payment Processing:** Razorpay integration requires valid API credentials for payment features
- **App Theme:** Configured in `mobile/lib/main.dart`
- **API Integration:** Handled by `mobile/lib/services/api_service.dart` and `mobile/lib/services/socket_service.dart`
