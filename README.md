# TrackMate 📍

> **Connect • Share • Secure**  
> Real-Time Location Sharing, Encrypted 1-to-1 Chat, and Emergency SOS Beacon App built with Flutter & Firebase Realtime Database.  
> **Created by AKHIL JOJO**

---

## 🌟 Key Features & Capabilities

### 1. 🚀 Branded Animated Splash & Dual-Mode Authentication
- **Splash Experience**: Modern radar animation with pulsating ambient glow, app branding, and creator credits.
- **Dual-Mode Login**: Sign in seamlessly using either registered email or username (with automatic database resolution).
- **Session Auto-Sync**: Secure device FCM token registration and persistent authentication.

### 2. 🗺️ Live Interactive Map & Privacy Controls
- **OpenStreetMap & Flutter Map**: Real-time rendering with high-accuracy GPS tracking.
- **Directional Privacy Control**: Core invariant: `CONNECTION != LOCATION PERMISSION`. Users control granular location sharing permissions per connection with instant revocation.
- **Dynamic Distance Calculation**: High-precision distance formatting (`formatDistance`) between users.
- **Live Friends Tracking Drawer**: Horizontal interactive carousel with live status indicators (`Live • 1.5 km` / `Location Off`), one-tap map auto-focus (`zoom: 16.0`), and direct quick-chat shortcuts.

### 3. 🚨 Emergency SOS Distress Beacon
- **Accidental-Activation UI Guard**: 3.0-second continuous hold-to-activate button with animated progress ring and haptic feedback.
- **Telemetry Packaging**: Packages live GPS coordinates alongside device battery level (`battery_plus`).
- **Realtime Database Broadcast**: Broadcasts emergency beacons directly to `/emergency_alerts/$uid`.
- **Sender Safety Dismissal**: One-tap "I'm Safe / Cancel SOS" action that instantly deactivates and removes the alert node from the database.
- **Recipient Emergency Modal**: High-priority alert banner, local push notifications, and `EmergencyAlertDialog` with instant map auto-focus to friend in distress.

### 4. 💬 Real-Time 1-to-1 Messaging
- **Instant Chat Rooms**: Deterministic room IDs (`${uidA}_${uidB}`) with real-time message streaming.
- **Multi-Chat In-App Notifications**: Background listeners with active room suppression.

### 5. 👤 Profile Customization & Emergency Metadata
- **8 Modern Avatar Presets**: Radar Blue, Neon Purple, Emerald Shield, Solar Amber, Crimson Flame, Cosmic Indigo, Teal Compass, Midnight Slate.
- **Customizable Bio & Status**: Multiline user status visible to connections.
- **Emergency Contact**: Dedicated primary emergency phone number displayed on profile.
- **Safe Sign-Out**: Complete session and location streaming cleanup.

---

## 🏗️ Architecture & Technology Stack

- **Framework**: Flutter 3.35.x (Dart 3.9+)
- **Backend & Database**: Firebase Authentication, Firebase Realtime Database
- **Notifications**: Firebase Cloud Messaging (`firebase_messaging`), `flutter_local_notifications`
- **Mapping Engine**: `flutter_map` (OpenStreetMap tile provider) & `latlong2`
- **Hardware Telemetry**: `geolocator`, `battery_plus`
- **State Management**: `provider` (MultiProvider architecture)

---

## 🔒 Security Rules & Database Schema

```json
{
  "rules": {
    "users": {
      ".read": true,
      ".indexOn": ["username"],
      "$uid": {
        ".write": "auth != null && auth.uid === $uid"
      }
    },
    "user_tokens": {
      "$uid": {
        ".read": "auth != null",
        ".write": "auth != null && auth.uid === $uid"
      }
    },
    "connection_requests": {
      "$receiverUid": {
        ".read": "auth != null && auth.uid === $receiverUid",
        "$senderUid": {
          ".write": "auth != null && (auth.uid === $senderUid || auth.uid === $receiverUid)"
        }
      }
    },
    "sent_requests": {
      "$senderUid": {
        ".read": "auth != null && auth.uid === $senderUid",
        "$receiverUid": {
          ".write": "auth != null && (auth.uid === $senderUid || auth.uid === $receiverUid)"
        }
      }
    },
    "connections": {
      "$uid": {
        ".read": "auth != null && auth.uid === $uid",
        ".write": "auth != null"
      }
    },
    "chats": {
      "$chatId": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    },
    "locations": {
      ".read": "auth != null",
      "$uid": {
        ".write": "auth != null && auth.uid === $uid"
      }
    },
    "location_permissions": {
      "$ownerUid": {
        ".read": "auth != null",
        ".write": "auth != null && auth.uid === $ownerUid"
      }
    },
    "emergency_alerts": {
      ".read": "auth != null",
      "$uid": {
        ".write": "auth != null && auth.uid === $uid"
      }
    }
  }
}
```

---

## 🚦 Roadmap & Milestones

- [x] **Phase 1**: Authentication, Indexed User Search & Bi-directional Connections
- [x] **Phase 2**: Real-Time Location Sharing & Directional Privacy Engine
- [x] **Phase 2 (FCM)**: Secure Device Token Registration & Local Heads-Up Notifications
- [x] **Phase 2 (SOS)**: Emergency SOS Beacon (3s hold, battery & GPS broadcast, live alerts, recipient modal)
- [x] **Phase 3**: Branded Splash Screen, Map Polish & Live Friends Tracking Carousel (auto-focus + quick chat)
- [x] **Phase 4**: Profile Customization (8 avatar presets, bio, emergency contact)
- [ ] **Phase 5**: In-Chat Image & Media Attachments (Firebase Storage)
- [ ] **Phase 6**: Geofencing Alerts & Safe-Zone Notifications
- [ ] **Phase 7**: Group / Family Tracking Rooms
