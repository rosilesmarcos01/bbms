# Building Management System (BBMS)

A **modern, elegant** full-stack IoT solution with iOS application and backend API for monitoring IoT devices and managing building facilities. Features blockchain integration with Rubidex for immutable data storage.

## 🏗️ Architecture

```
iOS App (SwiftUI) ↔ Backend API (Node.js) ↔ Rubidex Blockchain
                                    ↓
                         Push Notifications & Real-time Updates
```

## 📁 Repository Structure

```
bbms/
├── BBMS/                     # iOS SwiftUI Application
├── BBMS.xcodeproj/          # Xcode Project
├── backend/                 # Node.js Backend API
│   ├── src/                 # Backend source code
│   ├── package.json         # Node.js dependencies
│   └── README.md           # Backend documentation
├── docs/                    # Documentation
└── README.md               # This file
```

## 🎨 Modern Design Features

### Visual Excellence
- **Glassmorphism UI**: Beautiful translucent cards with depth and shadows
- **Gradient Accents**: Rich color gradients throughout the interface
- **Dynamic Icons**: Context-aware SF Symbols with status-based coloring
- **Modern Typography**: Clean, readable fonts with perfect hierarchy
- **Smooth Animations**: Fluid transitions and micro-interactions

### Color Palette
- **Primary Gold**: Rich amber gradient (`#FFC032` to `#FFBF33`)
- **Clean Backgrounds**: System-adaptive whites and grays
- **Status Colors**: Semantic color coding for device states
- **Dark Mode Ready**: Full support for light and dark appearances

## Features

### 📊 Smart Dashboard
- **System Status Overview**: Real-time status grid with animated indicators
- **Critical Alerts**: Priority notifications with modern card design
- **Today's Reservations**: Elegant booking overview
- **Quick Stats**: Beautiful metric cards with gradients and icons

### 🔧 Device Monitoring
- **IoT Device Tracking**: Monitor various device types including:
  - Temperature sensors
  - Water level monitors  
  - Gas level detectors
  - Air conditioning systems
  - Lighting controls
  - Security systems
- **Modern Device Cards**: Redesigned cards with status badges and smooth shadows
- **Smart Search**: Beautiful search bar with real-time filtering
- **Filter Chips**: Pill-shaped filters with gradient selections
- **Live Status**: Dynamic status indicators with color-coded states

### 🏢 Zone Management & Reservations
- **Zone Types**: Support for various facility spaces:
  - Executive offices
  - Meeting rooms
  - Conference rooms
  - Lobbies
  - Break rooms
  - Coworking spaces
- **Reservation System**: Book spaces with time slots
- **Availability Tracking**: Real-time space availability
- **Amenity Information**: Detailed facility features

### 👤 User Account Management
- **Profile Management**: Complete user profile with photo, role, and department
- **Settings & Preferences**: Customizable app preferences including:
  - Notification settings (push, email, alerts)
  - Display preferences (dark mode, temperature units)
  - Language selection
  - Quiet hours configuration
- **Role-Based Access**: Support for different user roles:
  - Administrator (crown icon, red accent)
  - Manager (key icon, gold accent)  
  - Technician (tools icon, blue accent)
  - User (person icon, green accent)
- **Account Information**: Service years, department, status tracking
- **Profile Pictures**: Photo upload and management with default avatars

## Technical Architecture

### Project Structure
```
BBMS/
├── Models/
│   ├── Alert.swift           # Alert and notification models
│   ├── Device.swift          # IoT device data model
│   ├── User.swift           # User account and preferences model
│   └── Zone.swift            # Zone and reservation models
├── Views/
│   ├── AccountView.swift     # User account management
│   ├── AlertsView.swift      # Alert management interface
│   ├── ContentView.swift     # Main tab navigation
│   ├── DashboardView.swift   # Dashboard interface
│   ├── DeviceMonitoringView.swift  # Device management
│   ├── EditProfileView.swift # Profile editing interface
│   ├── NotificationSettingsView.swift # Notification preferences
│   ├── ProfileImagePicker.swift # Profile photo management
│   ├── SettingsView.swift    # App settings and preferences
│   └── ZoneReservationView.swift   # Zone booking
├── Services/
│   ├── AlertService.swift    # Alert management service
│   ├── DeviceService.swift   # Device data management
│   ├── UserService.swift     # User account management
│   └── ZoneService.swift     # Zone and reservation logic
└── Assets.xcassets/          # App icons and resources
```

### Technology Stack
- **Framework**: SwiftUI
- **Platform**: iOS 17.0+
- **Architecture**: MVVM with ObservableObject
- **Data Management**: Combine framework for reactive updates
- **UI Components**: Native SwiftUI components with custom styling

## Device Types Supported
- **Temperature Sensors**: Monitor ambient temperature
- **Water Level Monitors**: Track water tank levels
- **Gas Level Detectors**: Monitor gas storage levels
- **HVAC Systems**: Control air conditioning and heating
- **Smart Lighting**: Automated lighting controls
- **Security Systems**: Access control and monitoring

## Development Setup

### Requirements
- Xcode 15.0 or later
- iOS 17.0+ deployment target
- Swift 5.0+

### Building the Project
1. Open `BBMS.xcodeproj` in Xcode
2. Select your target device or simulator
3. Build and run the project (⌘+R)

### Project Configuration
- **Bundle Identifier**: `com.bbms.app`
- **Team**: Configure with your Apple Developer account
- **Deployment Target**: iOS 17.0
## 🚀 Quick Start

### iOS App
1. Open `BBMS.xcodeproj` in Xcode
2. Select your target device or simulator
3. Build and run the project (⌘+R)

### Backend API
```bash
cd backend
npm install
cp .env.example .env
npm run dev
```

The backend runs on `http://localhost:3000` and connects to Rubidex blockchain.

## 🔧 Development Setup

### iOS Requirements
- Xcode 15.0 or later
- iOS 17.0+ deployment target
- Swift 5.0+

### Backend Requirements
- Node.js 18+ 
- npm or yarn
- Rubidex API access

## 📱 Testing on Phone

### Option 1: Local Development
```bash
# 1. Start backend
cd backend && npm run dev

# 2. Get your Mac's IP address
ifconfig | grep "inet " | grep -v 127.0.0.1

# 3. Update iOS app to point to your Mac's IP
# In RubidexService.swift: 
# private let backendURL = "http://192.168.1.XXX:3000/api"
```

### Option 2: Cloud Deployment
```bash
# Deploy backend to Heroku/Railway/Render
# Update iOS app with production URL
```

## Features in Detail

### Real-time Monitoring
The app connects to Rubidex blockchain for immutable IoT data storage with automatic updates. Device status changes are reflected immediately in the UI with appropriate color coding and alerts.

### Blockchain Integration
- **Rubidex Blockchain**: Immutable temperature readings and device data
- **Real-time Sync**: Live updates between iOS app and blockchain
- **Audit Trail**: Complete history of all sensor readings and alerts

### Reservation Management
Users can book zones with:
- Time slot selection
- Purpose specification
- Conflict detection
- Status tracking (Confirmed, Pending, Cancelled)
- Accessibility-compliant design

## Sample Data
The app includes realistic sample data for demonstration:
- 6 different IoT devices across various locations
- Multiple zone types with different capacities
- Pre-configured reservations with various statuses

## Future Enhancements
- Push notifications for critical alerts
- Historical data charts and analytics
- User authentication and role management
- Real IoT device integration via APIs
- Offline mode support
- Export functionality for reports

## License
This project is developed as a demonstration of modern iOS development practices for building management systems.

---

**Built with ❤️ using SwiftUI**