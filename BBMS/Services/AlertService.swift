import SwiftUI
import Foundation

class AlertService: ObservableObject {
    @Published var alerts: [Alert] = []
    @Published var unreadCount: Int = 0
    
    init() {
        loadAlerts()
        updateUnreadCount()
    }
    
    func loadAlerts() {
        // In a real app, this would fetch from an API or database
        alerts = Alert.sampleAlerts.sorted { $0.timestamp > $1.timestamp }
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
        }
    }
    
    func deleteAlert(_ alert: Alert) {
        alerts.removeAll { $0.id == alert.id }
        updateUnreadCount()
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
    }
}