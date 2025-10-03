import Foundation
import UserNotifications
import SwiftUI

class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    
    @Published var permissionGranted = false
    @Published var temperatureAlerts: [String: Date] = [:] // Device ID to last alert timestamp
    
    // Cooldown period to avoid spam notifications (5 minutes)
    private let alertCooldownPeriod: TimeInterval = 300
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkPermissionStatus()
    }
    
    // MARK: - Permission Management
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.permissionGranted = granted
            }
            
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    private func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.permissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Temperature Alert Notifications
    
    func sendTemperatureAlert(deviceName: String, deviceId: String, currentTemp: Double, limit: Double, location: String) {
        // Check if we're in cooldown period for this device
        if let lastAlertTime = temperatureAlerts[deviceId],
           Date().timeIntervalSince(lastAlertTime) < alertCooldownPeriod {
            return
        }
        
        guard permissionGranted else {
            print("Notification permission not granted")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "🌡️ High Temperature Alert"
        content.body = "\(deviceName) in \(location) has exceeded the temperature limit!\n\nCurrent: \(String(format: "%.1f", currentTemp))°C\nLimit: \(String(format: "%.1f", limit))°C"
        content.sound = .default
        content.badge = 1
        
        // Add custom data for handling the notification
        content.userInfo = [
            "type": "temperature_alert",
            "deviceId": deviceId,
            "deviceName": deviceName,
            "currentTemp": currentTemp,
            "limit": limit,
            "location": location
        ]
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "temp_alert_\(deviceId)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Immediate notification
        )
        
        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    self.temperatureAlerts[deviceId] = Date()
                }
                print("Temperature alert notification scheduled for \(deviceName)")
            }
        }
    }
    
    // MARK: - Critical Temperature Alert (Higher Priority)
    
    func sendCriticalTemperatureAlert(deviceName: String, deviceId: String, currentTemp: Double, criticalLimit: Double, location: String) {
        guard permissionGranted else {
            print("Notification permission not granted")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "🚨 CRITICAL Temperature Alert"
        content.body = "URGENT: \(deviceName) in \(location) has reached critical temperature levels!\n\nCurrent: \(String(format: "%.1f", currentTemp))°C\nCritical Limit: \(String(format: "%.1f", criticalLimit))°C\n\nImmediate action required!"
        content.sound = .defaultCritical
        content.badge = 1
        content.interruptionLevel = .critical
        
        // Add custom data
        content.userInfo = [
            "type": "critical_temperature_alert",
            "deviceId": deviceId,
            "deviceName": deviceName,
            "currentTemp": currentTemp,
            "criticalLimit": criticalLimit,
            "location": location
        ]
        
        // Create request with immediate trigger
        let request = UNNotificationRequest(
            identifier: "critical_temp_alert_\(deviceId)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling critical notification: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    self.temperatureAlerts[deviceId] = Date()
                }
                print("Critical temperature alert notification scheduled for \(deviceName)")
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
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        
        if let type = userInfo["type"] as? String,
           let deviceId = userInfo["deviceId"] as? String {
            
            switch type {
            case "temperature_alert", "critical_temperature_alert":
                // You can add navigation logic here to open the specific device detail view
                print("User tapped temperature alert for device: \(deviceId)")
                // TODO: Navigate to device detail view
                
            default:
                break
            }
        }
        
        completionHandler()
    }
}