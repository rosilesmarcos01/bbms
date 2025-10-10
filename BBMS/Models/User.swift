import Foundation
import SwiftUI

// MARK: - User Model
struct User: Identifiable, Codable {
    var id: UUID
    var name: String
    var email: String
    var role: UserRole
    var profileImageName: String?
    var department: String
    var joinDate: Date?  // ✅ Made optional - not always returned by backend
    var isActive: Bool?  // ✅ Made optional - not always returned by backend
    var preferences: UserPreferences?  // ✅ Made optional - not always returned by backend
    var accessLevel: AccessLevel
    var lastLoginAt: Date?
    var createdAt: Date?  // ✅ Made optional - not always returned by backend
    
    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        role: UserRole = .user,
        profileImageName: String? = nil,
        department: String = "General",
        joinDate: Date? = Date(),
        isActive: Bool? = true,
        preferences: UserPreferences? = UserPreferences(),
        accessLevel: AccessLevel = .basic,
        lastLoginAt: Date? = nil,
        createdAt: Date? = Date()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.profileImageName = profileImageName
        self.department = department
        self.joinDate = joinDate
        self.isActive = isActive
        self.preferences = preferences
        self.accessLevel = accessLevel
        self.lastLoginAt = lastLoginAt
        self.createdAt = createdAt
    }
}

// MARK: - User Role
enum UserRole: String, CaseIterable, Codable {
    case admin = "admin"
    case manager = "manager"
    case technician = "technician"
    case user = "user"
    
    var displayName: String {
        switch self {
        case .admin:
            return "Administrator"
        case .manager:
            return "Manager"
        case .technician:
            return "Technician"
        case .user:
            return "User"
        }
    }
    
    var color: Color {
        switch self {
        case .admin:
            return .red
        case .manager:
            return Color("BBMSGold")
        case .technician:
            return .blue
        case .user:
            return .green
        }
    }
    
    var icon: String {
        switch self {
        case .admin:
            return "crown.fill"
        case .manager:
            return "person.badge.key.fill"
        case .technician:
            return "wrench.and.screwdriver.fill"
        case .user:
            return "person.fill"
        }
    }
}

// MARK: - Access Level
enum AccessLevel: String, CaseIterable, Codable {
    case basic = "basic"
    case standard = "standard"
    case elevated = "elevated"
    case admin = "admin"
    
    var displayName: String {
        switch self {
        case .basic:
            return "Basic Access"
        case .standard:
            return "Standard Access"
        case .elevated:
            return "Elevated Access"
        case .admin:
            return "Administrator Access"
        }
    }
    
    var color: Color {
        switch self {
        case .basic:
            return .green
        case .standard:
            return .blue
        case .elevated:
            return Color("BBMSGold")
        case .admin:
            return .red
        }
    }
    
    var icon: String {
        switch self {
        case .basic:
            return "person.fill"
        case .standard:
            return "person.badge.plus.fill"
        case .elevated:
            return "person.badge.key.fill"
        case .admin:
            return "crown.fill"
        }
    }
}

// MARK: - User Preferences
struct UserPreferences: Codable {
    var notificationsEnabled: Bool
    var darkModeEnabled: Bool
    var alertsEnabled: Bool
    var emailNotifications: Bool
    var pushNotifications: Bool
    var language: String
    var temperatureUnit: TemperatureUnit
    
    // Biometric preferences
    var enableBiometricLogin: Bool
    var enableBuildingAccess: Bool
    var requireBiometricForSensitiveActions: Bool
    
    init(
        notificationsEnabled: Bool = true,
        darkModeEnabled: Bool = false,
        alertsEnabled: Bool = true,
        emailNotifications: Bool = true,
        pushNotifications: Bool = true,
        language: String = "English",
        temperatureUnit: TemperatureUnit = .celsius,
        enableBiometricLogin: Bool = false,
        enableBuildingAccess: Bool = false,
        requireBiometricForSensitiveActions: Bool = false
    ) {
        self.notificationsEnabled = notificationsEnabled
        self.darkModeEnabled = darkModeEnabled
        self.alertsEnabled = alertsEnabled
        self.emailNotifications = emailNotifications
        self.pushNotifications = pushNotifications
        self.language = language
        self.temperatureUnit = temperatureUnit
        self.enableBiometricLogin = enableBiometricLogin
        self.enableBuildingAccess = enableBuildingAccess
        self.requireBiometricForSensitiveActions = requireBiometricForSensitiveActions
    }
}

// MARK: - Temperature Unit
enum TemperatureUnit: String, CaseIterable, Codable {
    case celsius = "Celsius"
    case fahrenheit = "Fahrenheit"
    
    var symbol: String {
        switch self {
        case .celsius:
            return "°C"
        case .fahrenheit:
            return "°F"
        }
    }
}