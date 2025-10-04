import SwiftUI
import Foundation

class AlertService: ObservableObject {
    static let shared = AlertService()
    
    @Published var alerts: [Alert] = []
    @Published var unreadCount: Int = 0
    
    private init() {
        loadAlerts()
        updateUnreadCount()
    }
    
    func loadAlerts() {
        // Load any persisted alerts from UserDefaults
        loadPersistedAlerts()
        
        // If no persisted alerts, start with sample data
        if alerts.isEmpty {
            alerts = Alert.sampleAlerts.sorted { $0.timestamp > $1.timestamp }
            saveAlertsToUserDefaults()
        }
    }
    
    func markAsRead(_ alert: Alert) {
        if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
            alerts[index] = Alert(
                title: alert.title,
                message: alert.message,
                severity: alert.severity,
                category: alert.category,
                timestamp: alert.timestamp,
                deviceId: alert.deviceId,
                zoneId: alert.zoneId,
                isRead: true,
                isResolved: alert.isResolved
            )
            updateUnreadCount()
            saveAlertsToUserDefaults()
        }
    }
    
    func markAsResolved(_ alert: Alert) {
        if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
            alerts[index] = Alert(
                title: alert.title,
                message: alert.message,
                severity: alert.severity,
                category: alert.category,
                timestamp: alert.timestamp,
                deviceId: alert.deviceId,
                zoneId: alert.zoneId,
                isRead: true,
                isResolved: true
            )
            updateUnreadCount()
            saveAlertsToUserDefaults()
            
            // If this is a temperature alert and has a deviceId, document the resolution in Rubidex
            if alert.category == .hvac && alert.severity == .critical || alert.severity == .warning,
               let deviceId = alert.deviceId {
                Task {
                    let success = await RubidexService.shared.updateTemperatureAlertResolved(
                        deviceId: deviceId,
                        deviceName: alert.title.replacingOccurrences(of: "High Temperature Alert", with: "Device").replacingOccurrences(of: "CRITICAL Temperature Alert", with: "Device")
                    )
                    
                    if success {
                        print("✅ Temperature alert resolution automatically documented in Rubidex blockchain")
                    } else {
                        print("⚠️ Failed to document temperature alert resolution in Rubidex blockchain")
                    }
                }
            }
        }
    }
    
    func deleteAlert(_ alert: Alert) {
        alerts.removeAll { $0.id == alert.id }
        updateUnreadCount()
        saveAlertsToUserDefaults()
    }
    
    func getAlerts(for severity: Alert.AlertSeverity? = nil, category: Alert.AlertCategory? = nil) -> [Alert] {
        var filteredAlerts = alerts
        
        if let severity = severity {
            filteredAlerts = filteredAlerts.filter { $0.severity == severity }
        }
        
        if let category = category {
            filteredAlerts = filteredAlerts.filter { $0.category == category }
        }
        
        return filteredAlerts
    }
    
    func getCriticalAlerts() -> [Alert] {
        return alerts.filter { $0.severity == .critical && !$0.isResolved }
    }
    
    func getUnreadAlerts() -> [Alert] {
        return alerts.filter { !$0.isRead }
    }
    
    private func updateUnreadCount() {
        unreadCount = alerts.filter { !$0.isRead }.count
    }
    
    func addAlert(_ alert: Alert) {
        alerts.insert(alert, at: 0)
        updateUnreadCount()
        saveAlertsToUserDefaults()
    }
    
    func markAllAsRead() {
        for i in 0..<alerts.count {
            if !alerts[i].isRead {
                alerts[i] = Alert(
                    title: alerts[i].title,
                    message: alerts[i].message,
                    severity: alerts[i].severity,
                    category: alerts[i].category,
                    timestamp: alerts[i].timestamp,
                    deviceId: alerts[i].deviceId,
                    zoneId: alerts[i].zoneId,
                    isRead: true,
                    isResolved: alerts[i].isResolved
                )
            }
        }
        updateUnreadCount()
        saveAlertsToUserDefaults()
    }
    
    // MARK: - Persistence Methods
    
    private func saveAlertsToUserDefaults() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(alerts)
            UserDefaults.standard.set(data, forKey: "SavedAlerts")
        } catch {
            print("❌ Failed to save alerts to UserDefaults: \(error)")
        }
    }
    
    private func loadPersistedAlerts() {
        guard let data = UserDefaults.standard.data(forKey: "SavedAlerts") else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            alerts = try decoder.decode([Alert].self, from: data)
            alerts.sort { $0.timestamp > $1.timestamp }
        } catch {
            print("❌ Failed to load alerts from UserDefaults: \(error)")
            alerts = []
        }
    }
    
    // MARK: - Development/Testing Methods
    
    func clearAllAlerts() {
        alerts.removeAll()
        updateUnreadCount()
        saveAlertsToUserDefaults()
    }
    
    func resetToSampleData() {
        alerts = Alert.sampleAlerts.sorted { $0.timestamp > $1.timestamp }
        updateUnreadCount()
        saveAlertsToUserDefaults()
    }
    
    // Method to check if we have real temperature monitoring working
    func hasRealTemperatureDevices() -> Bool {
        return alerts.contains { alert in
            alert.category == .hvac && alert.deviceId != nil && !alert.title.contains("sample")
        }
    }
}