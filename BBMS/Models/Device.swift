import Foundation

struct Device: Identifiable, Codable, Hashable {
    var id: UUID
    let name: String
    let type: DeviceType
    let location: String
    var status: DeviceStatus
    var value: Double
    var unit: String
    let lastUpdated: Date
    
    // Custom initializer to generate consistent IDs
    init(name: String, type: DeviceType, location: String, status: DeviceStatus, value: Double, unit: String, lastUpdated: Date) {
        self.name = name
        self.type = type
        self.location = location
        self.status = status
        self.value = value
        self.unit = unit
        self.lastUpdated = lastUpdated
        
        // Generate a consistent UUID based on name and location
        let combined = "\(name)_\(location)_\(type.rawValue)"
        let hash = combined.sha256
        
        // Create UUID from hash in a simpler way
        let part1 = String(hash.prefix(8))
        let part2 = String(hash.dropFirst(8).prefix(4))
        let part3 = String(hash.dropFirst(12).prefix(4))
        let part4 = String(hash.dropFirst(16).prefix(4))
        let part5 = String(hash.dropFirst(20).prefix(12))
        
        let formattedUUID = "\(part1)-\(part2)-\(part3)-\(part4)-\(part5)"
        self.id = UUID(uuidString: formattedUUID) ?? UUID()
    }
    
    enum DeviceType: String, CaseIterable, Codable {
        case temperature = "Temperature"
        case waterLevel = "Water Level"
        case gasLevel = "Gas Level"
        case airConditioning = "Air Conditioning"
        case lighting = "Lighting"
        case security = "Security"
    }
    
    enum DeviceStatus: String, CaseIterable, Codable {
        case online = "Online"
        case offline = "Offline"
        case warning = "Warning"
        case critical = "Critical"
        
        var color: String {
            switch self {
            case .online: return "green"
            case .offline: return "gray"
            case .warning: return "orange"
            case .critical: return "red"
            }
        }
    }
    
    var statusIcon: String {
        switch status {
        case .online: return "checkmark.circle.fill"
        case .offline: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
    
    var typeIcon: String {
        switch type {
        case .temperature: return "thermometer"
        case .waterLevel: return "drop.fill"
        case .gasLevel: return "flame.fill"
        case .airConditioning: return "snowflake"
        case .lighting: return "lightbulb.fill"
        case .security: return "lock.fill"
        }
    }
    
    // Enhanced icon based on specific device name
    var deviceIcon: String {
        let lowercaseName = name.lowercased()
        
        // Check for specific device names first
        if lowercaseName.contains("lobby") {
            return "building.2.fill"
        } else if lowercaseName.contains("tank") {
            return "cylinder.fill"
        } else if lowercaseName.contains("water") && !lowercaseName.contains("tank") {
            return "drop.triangle.fill"
        } else if lowercaseName.contains("gas") {
            if lowercaseName.contains("monitor") {
                return "gauge.badge.plus"
            } else {
                return "flame.circle.fill"
            }
        } else if lowercaseName.contains("conference") || lowercaseName.contains("meeting") {
            return "person.3.fill"
        } else if lowercaseName.contains("emergency") {
            return "exclamationmark.triangle.fill"
        } else if lowercaseName.contains("entrance") || lowercaseName.contains("door") {
            return "door.left.hand.open"
        } else if lowercaseName.contains("main") && lowercaseName.contains("security") {
            return "shield.lefthalf.filled"
        } else if lowercaseName.contains("ac") || lowercaseName.contains("air conditioning") {
            return "air.conditioner.horizontal"
        } else if lowercaseName.contains("temperature") {
            if lowercaseName.contains("outdoor") || lowercaseName.contains("outside") {
                return "thermometer.sun.fill"
            } else if lowercaseName.contains("indoor") || lowercaseName.contains("room") {
                return "thermometer.medium"
            } else {
                return "thermometer.variable.and.figure"
            }
        } else if lowercaseName.contains("lighting") {
            if lowercaseName.contains("emergency") {
                return "lightbulb.led.fill"
            } else if lowercaseName.contains("outdoor") {
                return "sun.max.fill"
            } else {
                return "lightbulb.circle.fill"
            }
        }
        
        // Fall back to type-based icon
        return typeIcon
    }
}

// Extension to generate consistent UUIDs from strings
import CryptoKit

extension String {
    var sha256: String {
        let data = Data(self.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}