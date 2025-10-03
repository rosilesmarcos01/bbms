# Temperature Notification System - Implementation Guide

## Overview

This implementation adds a comprehensive push notification system for high temperature alerts in the BBMS app. The system works even when the phone is locked or the app is in the background.

## Features Implemented

### 1. Push Notifications
- **Local notifications** that work even when the app is closed
- **Permission management** with user-friendly request flow
- **Cooldown system** to prevent notification spam (5-minute intervals)
- **Two severity levels**:
  - Warning alerts when temperature exceeds the set limit
  - Critical alerts when temperature exceeds limit + 10°C

### 2. Background Monitoring
- **Background app refresh** capability for continuous monitoring
- **Automatic temperature checking** every 15 minutes when app is backgrounded
- **Smart scheduling** that respects iOS background execution limits
- **App lifecycle integration** for seamless monitoring

### 3. User Interface
- **Notification settings panel** in device detail view
- **Visual indicators** showing notification permission status
- **Temperature limit slider** with real-time feedback
- **Alert level indicators** (warning vs critical thresholds)

### 4. Developer Tools
- **Test notification view** for development and debugging
- **Permission status monitoring**
- **Manual alert triggering** for testing

## How to Test the Notification System

### 1. Enable Notifications
1. Open the app and navigate to any temperature device
2. Scroll down to the "Notification Settings" section
3. Tap "Enable" if notifications are disabled
4. Grant permission when iOS prompts you

### 2. Set Temperature Limits
1. In the device detail view, find the "Temperature Limit" section
2. Use the slider to set your desired temperature threshold
3. The app will show warning when current temp > limit
4. Critical alerts trigger when temp > limit + 10°C

### 3. Test with Developer Tools (Debug Mode)
1. Go to Settings in the app
2. Find "Developer Tools" section (only visible in debug builds)
3. Tap "Test Notifications"
4. Use the sliders to simulate different temperature scenarios
5. Test both warning and critical alert levels

### 4. Background Testing
1. Set a temperature limit lower than the current reading
2. Put the app in background or lock your phone
3. Notifications should arrive within 15 minutes
4. Check that notifications appear on lock screen

## Files Added/Modified

### New Files:
- `BBMS/Services/NotificationService.swift` - Core notification management
- `BBMS/Services/BackgroundMonitoringService.swift` - Background temperature monitoring
- `BBMS/Views/NotificationTestView.swift` - Developer testing interface

### Modified Files:
- `BBMS/BBMSApp.swift` - Added notification service initialization and app lifecycle handling
- `BBMS/Views/DeviceDetailView.swift` - Added notification UI and integration
- `BBMS/Views/SettingsView.swift` - Added developer tools section

## Configuration Required

### Xcode Project Settings
To enable background app refresh, you need to add the following capability to your iOS project:

1. Open the project in Xcode
2. Select your app target
3. Go to "Signing & Capabilities"
4. Add "Background Modes" capability
5. Check "Background App Refresh"

### Info.plist (if needed)
Add these keys to your Info.plist:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>background-app-refresh</string>
</array>
```

## How the System Works

### Notification Flow
1. **Permission Request**: App requests notification permissions on launch
2. **Temperature Monitoring**: DeviceDetailView watches for temperature changes
3. **Threshold Checking**: When temperature exceeds limit, both in-app alerts and push notifications are triggered
4. **Background Monitoring**: When app goes to background, automatic checks continue every 15 minutes
5. **Cooldown Prevention**: Same device won't trigger multiple notifications within 5 minutes

### Background Execution
- Uses iOS Background App Refresh for periodic checks
- Schedules background tasks every 15 minutes
- Performs temperature checks for all monitored devices
- Handles iOS execution time limits gracefully

### Notification Types
- **Standard Alerts**: Temperature > set limit
- **Critical Alerts**: Temperature > set limit + 10°C (higher priority, different sound)
- **Rich Content**: Includes device name, location, current temp, and limit values

## Testing Scenarios

### Scenario 1: Immediate Notifications
1. Set temperature limit to 25°C
2. Adjust device reading to 30°C (simulate high temp)
3. Should receive immediate notification

### Scenario 2: Background Notifications
1. Set temperature limit appropriately
2. Put app in background
3. Wait for background check cycle
4. Should receive notification if temperature exceeds limit

### Scenario 3: Critical Alerts
1. Set temperature limit to 30°C
2. Simulate temperature of 41°C or higher
3. Should receive critical alert with urgent styling

### Scenario 4: Cooldown System
1. Trigger a temperature alert
2. Immediately trigger another for same device
3. Second alert should be suppressed for 5 minutes

## Troubleshooting

### Notifications Not Working
1. Check permission status in app
2. Verify iOS notification settings for the app
3. Ensure background app refresh is enabled
4. Test with developer tools first

### Background Monitoring Issues
1. Ensure Background App Refresh is enabled in iOS Settings
2. Keep app alive for a few minutes after backgrounding
3. Check iOS low power mode isn't affecting background execution

### Testing on Simulator vs Device
- Notifications work on both simulator and device
- Background app refresh is more reliable on physical devices
- Test critical functionality on actual hardware

## Future Enhancements

1. **Remote Push Notifications**: Integration with APNs for server-triggered alerts
2. **Smart Scheduling**: ML-based prediction of temperature spikes
3. **Group Notifications**: Bundled alerts for multiple devices
4. **Location-Based Alerts**: Geofenced notifications
5. **Integration with Health**: Temperature data export to Apple Health

## Security Considerations

- All notifications contain device identifiers for routing
- No sensitive user data is stored in notification payloads
- Permission requests follow iOS best practices
- Background monitoring respects user privacy settings

---

This implementation provides a robust foundation for temperature monitoring with push notifications that work reliably even when the app is not actively being used.