# Building Management System (BBMS) - iOS App

A **modern, elegant** iOS application built with SwiftUI for monitoring IoT devices and managing building facilities with a beautiful, intuitive interface.

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

## Technical Architecture

### Project Structure
```
BBMS/
├── Models/
│   ├── Device.swift          # IoT device data model
│   └── Zone.swift            # Zone and reservation models
├── Views/
│   ├── ContentView.swift     # Main tab navigation
│   ├── DashboardView.swift   # Dashboard interface
│   ├── DeviceMonitoringView.swift  # Device management
│   └── ZoneReservationView.swift   # Zone booking
├── Services/
│   ├── DeviceService.swift   # Device data management
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

## Features in Detail

### Real-time Monitoring
The app simulates IoT device connections with automatic data updates every 30 seconds. Device status changes are reflected immediately in the UI with appropriate color coding and alerts.

### Reservation Management
Users can book zones with:
- Time slot selection
- Purpose specification
- Conflict detection
- Status tracking (Confirmed, Pending, Cancelled)

### Modern UI Design
- Clean, intuitive interface
- System-native icons and controls
- Responsive layout for all iOS devices
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