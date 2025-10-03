# Quick Test Guide for Temperature Notifications

## 🔧 **UPDATED SYSTEM - Now with Global Monitoring!**

The notification system has been improved to monitor temperatures **globally** across the entire app, not just when viewing specific device details.

## Testing the Notification System

### 1. Basic Setup Test (Automatic)
1. Open the BBMS app
2. **Global monitoring starts automatically** - no need to visit device details
3. Navigate to Settings > Developer Tools > Test Notifications to see monitoring status
4. Check that "Global Monitoring Status" shows "Active"

### 2. Temperature Limit Configuration
1. Navigate to any temperature device detail view
2. Set the temperature limit using the slider
3. **The limit is now saved globally** and applies even when you leave the view
4. You can verify this in Developer Tools

### 3. Real-time Monitoring Test
1. Set a temperature limit in any device view
2. **Navigate away from the device** (go to Dashboard, Alerts, etc.)
3. The app will continue monitoring and send notifications every 30 seconds
4. You should receive notifications even when browsing other parts of the app

### 4. Background Test
1. Set temperature limits appropriately
2. **Put the app in background or lock your phone**
3. Global monitoring continues with 15-minute intervals
4. Notifications arrive on lock screen without opening device details

### 5. Developer Test Mode (Debug builds only)
1. Go to Settings > Developer Tools > Test Notifications
2. **Check "Global Monitoring Status"** - should show Active
3. View number of monitored devices
4. Test notifications work from any screen

### Expected Behavior
✅ **Global monitoring starts automatically when app launches**
✅ **No need to visit device detail views to start monitoring**
✅ **Temperature limits persist across app navigation**
✅ **Notifications work from any screen in the app**
✅ **Background monitoring continues when app is backgrounded**
✅ **Real-time monitoring every 30 seconds when app is active**

### Key Improvements
🚀 **Global Temperature Monitor**: Centralized monitoring service
🚀 **Always Active**: Monitoring starts automatically on app launch
🚀 **Persistent Configuration**: Limits saved globally, not per-view
🚀 **Navigation Independence**: Works regardless of current screen
🚀 **Dual-layer Monitoring**: 30-second active checks + 15-minute background checks

### Troubleshooting
If notifications don't work:
1. **Check Global Monitoring Status in Developer Tools**
2. Verify iOS Settings > [App Name] > Notifications (should be enabled)
3. Verify iOS Settings > General > Background App Refresh (should be enabled)
4. Check that temperature limits are configured (visit any temperature device once)
5. Monitor console output for debugging information

### Technical Details
- **Active Monitoring**: Every 30 seconds when app is foreground
- **Background Monitoring**: Every 15 minutes when app is backgrounded
- **Global State**: Temperature limits stored in UserDefaults
- **Automatic Setup**: No manual configuration required
- **Cross-screen**: Works from Dashboard, Alerts, Settings, anywhere in the app

The system now provides truly global temperature monitoring that works continuously, regardless of which screen you're currently viewing! 🎯