import SwiftUI
import Foundation

struct Alert: Identifiable, Codable {
    let id: UUID
    let title: String
    let message: String
    let severity: AlertSeverity
    let category: AlertCategory
    let timestamp: Date
    let deviceId: String?
    let zoneId: String?
    let isRead: Bool
    let isResolved: Bool
    
    init(title: String, message: String, severity: AlertSeverity, category: AlertCategory, timestamp: Date, deviceId: String? = nil, zoneId: String? = nil, isRead: Bool = false, isResolved: Bool = false) {
        self.id = UUID()
        self.title = title
        self.message = message
        self.severity = severity
        self.category = category
        self.timestamp = timestamp
        self.deviceId = deviceId
        self.zoneId = zoneId
        self.isRead = isRead
        self.isResolved = isResolved
    }
    
    enum AlertSeverity: String, CaseIterable, Codable {
        case critical = "critical"
        case warning = "warning"
        case info = "info"
        case success = "success"
        
        var color: Color {
            switch self {
            case .critical:
                return .red
            case .warning:
                return .orange
            case .info:
                return .blue
            case .success:
                return .green
            }
        }
        
        var icon: String {
            switch self {
            case .critical:
                return "exclamationmark.triangle.fill"
            case .warning:
                return "exclamationmark.circle.fill"
            case .info:
                return "info.circle.fill"
            case .success:
                return "checkmark.circle.fill"
            }
        }
        
        var displayName: String {
            switch self {
            case .critical:
                return "Critical"
            case .warning:
                return "Warning"
            case .info:
                return "Info"
            case .success:
                return "Success"
            }
        }
    }
    
    enum AlertCategory: String, CaseIterable, Codable {
        case security = "security"
        case hvac = "hvac"
        case lighting = "lighting"
        case access = "access"
        case maintenance = "maintenance"
        case energy = "energy"
        case safety = "safety"
        case system = "system"
        
        var icon: String {
            switch self {
            case .security:
                return "shield.fill"
            case .hvac:
                return "thermometer"
            case .lighting:
                return "lightbulb.fill"
            case .access:
                return "key.fill"
            case .maintenance:
                return "wrench.fill"
            case .energy:
                return "bolt.fill"
            case .safety:
                return "cross.circle.fill"
            case .system:
                return "gear"
            }
        }
        
        var displayName: String {
            switch self {
            case .security:
                return "Security"
            case .hvac:
                return "HVAC"
            case .lighting:
                return "Lighting"
            case .access:
                return "Access Control"
            case .maintenance:
                return "Maintenance"
            case .energy:
                return "Energy"
            case .safety:
                return "Safety"
            case .system:
                return "System"
            }
        }
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// Extension for sample data
extension Alert {
    static let sampleAlerts: [Alert] = [
        Alert(
            title: "Temperature Critical",
            message: "Server room temperature has exceeded 85°F. Immediate attention required to prevent equipment damage.",
            severity: .critical,
            category: .hvac,
            timestamp: Date().addingTimeInterval(-300), // 5 minutes ago
            deviceId: "HVAC-001",
            zoneId: "server-room",
            isRead: false,
            isResolved: false
        ),
        Alert(
            title: "Unauthorized Access Attempt",
            message: "Failed keycard access detected at main entrance. Security review recommended.",
            severity: .warning,
            category: .security,
            timestamp: Date().addingTimeInterval(-900), // 15 minutes ago
            deviceId: "ACCESS-001",
            zoneId: "main-entrance",
            isRead: false,
            isResolved: false
        ),
        Alert(
            title: "Lighting System Updated",
            message: "Conference room lighting schedule has been successfully updated for energy optimization.",
            severity: .success,
            category: .lighting,
            timestamp: Date().addingTimeInterval(-1800), // 30 minutes ago
            deviceId: "LIGHT-003",
            zoneId: "conference-room-a",
            isRead: true,
            isResolved: true
        ),
        Alert(
            title: "Maintenance Due",
            message: "HVAC filter replacement scheduled for next week. Pre-order filters recommended.",
            severity: .info,
            category: .maintenance,
            timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            deviceId: "HVAC-002",
            zoneId: "office-floor-2",
            isRead: true,
            isResolved: false
        ),
        Alert(
            title: "High Energy Consumption",
            message: "Building energy usage 15% above normal. Consider adjusting HVAC settings.",
            severity: .warning,
            category: .energy,
            timestamp: Date().addingTimeInterval(-7200), // 2 hours ago
            deviceId: nil,
            zoneId: nil,
            isRead: true,
            isResolved: false
        ),
        Alert(
            title: "Emergency Exit Clear",
            message: "Emergency exit obstruction has been cleared. Safety compliance restored.",
            severity: .success,
            category: .safety,
            timestamp: Date().addingTimeInterval(-10800), // 3 hours ago
            deviceId: "SAFETY-001",
            zoneId: "emergency-exit-b",
            isRead: true,
            isResolved: true
        )
    ]
}