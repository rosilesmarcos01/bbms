import Foundation
import UserNotifications
import SwiftUI

extension Notification.Name {
    static let notificationPermissionDenied = Notification.Name("notificationPermissionDenied")
    static let navigateToDevice = Notification.Name("navigateToDevice")
}

class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    
    @Published var permissionGranted = false
    @Published var temperatureAlerts: [String: Date] = [:] // Device ID to last alert timestamp
    
    // Cooldown period to avoid spam notifications (5 minutes)
    private let alertCooldownPeriod: TimeInterval = 300
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        setupNotificationCategories()
        checkPermissionStatus()
    }
    
    // MARK: - Notification Categories Setup
    
    private func setupNotificationCategories() {
        // Actions for temperature alerts
        let viewAction = UNNotificationAction(
            identifier: "VIEW_DEVICE",
            title: "View Device",
            options: [.foreground]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: []
        )
        
        // Regular temperature alert category
        let temperatureCategory = UNNotificationCategory(
            identifier: "TEMPERATURE_ALERT",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Critical temperature alert category
        let criticalCategory = UNNotificationCategory(
            identifier: "CRITICAL_TEMPERATURE_ALERT",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Register categories
        UNUserNotificationCenter.current().setNotificationCategories([
            temperatureCategory,
            criticalCategory
        ])
        
        print("✅ Notification categories configured")
    }
    
    // MARK: - Permission Management
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.permissionGranted = granted
                if granted {
                    print("✅ Notification permissions granted")
                } else {
                    print("❌ Notification permissions denied")
                    // Show alert to user about importance of notifications
                    self.showPermissionDeniedAlert()
                }
            }
            
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    private func showPermissionDeniedAlert() {
        // This will be handled by the UI layer
        NotificationCenter.default.post(name: .notificationPermissionDenied, object: nil)
    }
    
    private func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.permissionGranted = settings.authorizationStatus == .authorized
                
                // Log current permission status for debugging
                switch settings.authorizationStatus {
                case .authorized:
                    print("✅ Notifications authorized")
                case .denied:
                    print("❌ Notifications denied")
                case .notDetermined:
                    print("⚠️ Notifications not determined - requesting permission...")
                    self.requestPermission()
                case .provisional:
                    print("⚠️ Notifications provisional")
                case .ephemeral:
                    print("⚠️ Notifications ephemeral")
                @unknown default:
                    print("⚠️ Unknown notification authorization status")
                }
                
                // Check if background app refresh is enabled
                if settings.authorizationStatus == .authorized {
                    print("🔔 Alert setting: \(settings.alertSetting.rawValue)")
                    print("🔊 Sound setting: \(settings.soundSetting.rawValue)")
                    print("🔴 Badge setting: \(settings.badgeSetting.rawValue)")
                    if #available(iOS 12.0, *) {
                        print("🚨 Critical alert setting: \(settings.criticalAlertSetting.rawValue)")
                    }
                }
            }
        }
    }
    
    // MARK: - Temperature Alert Notifications
    
    func sendTemperatureAlert(deviceName: String, deviceId: String, currentTemp: Double, limit: Double, location: String) {
        // Check if we're in cooldown period for this device
        if let lastAlertTime = temperatureAlerts[deviceId],
           Date().timeIntervalSince(lastAlertTime) < alertCooldownPeriod {
            print("⏰ Skipping alert for \(deviceName) - still in cooldown period")
            return
        }
        
        // Double-check permission status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                print("❌ Cannot send notification - permission not granted. Status: \(settings.authorizationStatus)")
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = "🌡️ High Temperature Alert"
            content.body = "\(deviceName) in \(location) has exceeded the temperature limit!\n\nCurrent: \(String(format: "%.1f", currentTemp))°C\nLimit: \(String(format: "%.1f", limit))°C"
            content.sound = .default
            content.badge = 1
            content.categoryIdentifier = "TEMPERATURE_ALERT"
            
            // Set interruption level for iOS 15+
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .active
            }
            
            // Add custom data for handling the notification
            content.userInfo = [
                "type": "temperature_alert",
                "deviceId": deviceId,
                "deviceName": deviceName,
                "currentTemp": currentTemp,
                "limit": limit,
                "location": location,
                "timestamp": Date().timeIntervalSince1970
            ]
            
            // Create request with unique identifier
            let identifier = "temp_alert_\(deviceId)_\(Date().timeIntervalSince1970)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: nil // Immediate notification
            )
            
            // Schedule notification
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Error scheduling notification: \(error.localizedDescription)")
                } else {
                    DispatchQueue.main.async {
                        self.temperatureAlerts[deviceId] = Date()
                    }
                    print("✅ Temperature alert notification scheduled for \(deviceName) - ID: \(identifier)")
                }
            }
        }
    }
    
    // MARK: - Critical Temperature Alert (Higher Priority)
    
    func sendCriticalTemperatureAlert(deviceName: String, deviceId: String, currentTemp: Double, criticalLimit: Double, location: String) {
        // Double-check permission status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                print("❌ Cannot send critical notification - permission not granted. Status: \(settings.authorizationStatus)")
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = "🚨 CRITICAL Temperature Alert"
            content.body = "URGENT: \(deviceName) in \(location) has reached critical temperature levels!\n\nCurrent: \(String(format: "%.1f", currentTemp))°C\nCritical Limit: \(String(format: "%.1f", criticalLimit))°C\n\nImmediate action required!"
            content.sound = .defaultCritical
            content.badge = 1
            content.categoryIdentifier = "CRITICAL_TEMPERATURE_ALERT"
            
            // Set interruption level for iOS 15+
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .critical
            }
            
            // Add custom data
            content.userInfo = [
                "type": "critical_temperature_alert",
                "deviceId": deviceId,
                "deviceName": deviceName,
                "currentTemp": currentTemp,
                "criticalLimit": criticalLimit,
                "location": location,
                "timestamp": Date().timeIntervalSince1970
            ]
            
            // Create request with unique identifier
            let identifier = "critical_temp_alert_\(deviceId)_\(Date().timeIntervalSince1970)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: nil
            )
            
            // Schedule notification
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Error scheduling critical notification: \(error.localizedDescription)")
                } else {
                    DispatchQueue.main.async {
                        self.temperatureAlerts[deviceId] = Date()
                    }
                    print("🚨 Critical temperature alert notification scheduled for \(deviceName) - ID: \(identifier)")
                }
            }
        }
    }
    
    // MARK: - Background Temperature Monitoring
    
    func checkTemperatureThresholds(for device: Device, currentTemp: Double, temperatureLimit: Double) {
        let criticalLimit = temperatureLimit + 10.0 // Critical is 10 degrees above normal limit
        
        if currentTemp >= criticalLimit {
            sendCriticalTemperatureAlert(
                deviceName: device.name,
                deviceId: device.id.uuidString,
                currentTemp: currentTemp,
                criticalLimit: criticalLimit,
                location: device.location
            )
        } else if currentTemp > temperatureLimit {
            sendTemperatureAlert(
                deviceName: device.name,
                deviceId: device.id.uuidString,
                currentTemp: currentTemp,
                limit: temperatureLimit,
                location: device.location
            )
        }
    }
    
    // MARK: - Utility Functions
    
    func clearTemperatureAlert(for deviceId: String) {
        temperatureAlerts.removeValue(forKey: deviceId)
    }
    
    func clearAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func clearDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    // MARK: - Debug and Status Methods
    
    func getNotificationStatus() async -> String {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        
        var status = "📱 Notification Status Report:\n"
        status += "Authorization: \(settings.authorizationStatus.description)\n"
        status += "Alert Setting: \(settings.alertSetting.description)\n"
        status += "Sound Setting: \(settings.soundSetting.description)\n"
        status += "Badge Setting: \(settings.badgeSetting.description)\n"
        if #available(iOS 12.0, *) {
            status += "Critical Alert: \(settings.criticalAlertSetting.description)\n"
        }
        status += "Announcement: \(settings.announcementSetting.description)\n"
        
        if #available(iOS 15.0, *) {
            status += "Scheduled Delivery: \(settings.scheduledDeliverySetting.description)\n"
        }
        
        // Check pending notifications
        let pendingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        status += "Pending notifications: \(pendingRequests.count)\n"
        
        // Check delivered notifications
        let deliveredNotifications = await UNUserNotificationCenter.current().deliveredNotifications()
        status += "Delivered notifications: \(deliveredNotifications.count)\n"
        
        return status
    }
    
    func checkBackgroundAppRefreshStatus() -> String {
        let backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
        
        switch backgroundRefreshStatus {
        case .available:
            return "✅ Background App Refresh: Available"
        case .denied:
            return "❌ Background App Refresh: Denied"
        case .restricted:
            return "⚠️ Background App Refresh: Restricted"
        @unknown default:
            return "❓ Background App Refresh: Unknown"
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
        
        print("📱 Notification presented while app is active: \(notification.request.identifier)")
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        
        if let type = userInfo["type"] as? String,
           let deviceId = userInfo["deviceId"] as? String {
            
            print("📱 User interacted with notification: \(type), device: \(deviceId), action: \(response.actionIdentifier)")
            
            switch response.actionIdentifier {
            case "VIEW_DEVICE":
                // Navigate to device detail view
                NotificationCenter.default.post(
                    name: .navigateToDevice, 
                    object: nil, 
                    userInfo: ["deviceId": deviceId]
                )
                
            case "DISMISS":
                // Just dismiss the notification
                break
                
            case UNNotificationDefaultActionIdentifier:
                // User tapped the notification itself (not an action button)
                switch type {
                case "temperature_alert", "critical_temperature_alert":
                    NotificationCenter.default.post(
                        name: .navigateToDevice, 
                        object: nil, 
                        userInfo: ["deviceId": deviceId]
                    )
                    
                default:
                    break
                }
                
            default:
                break
            }
        }
        
        completionHandler()
    }
}

// MARK: - Extensions for Better Debugging

extension UNAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }
}

extension UNNotificationSetting {
    var description: String {
        switch self {
        case .enabled: return "Enabled"
        case .disabled: return "Disabled"
        case .notSupported: return "Not Supported"
        @unknown default: return "Unknown"
        }
    }
}
