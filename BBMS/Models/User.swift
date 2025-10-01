import Foundation
import SwiftUI

// MARK: - User Model
struct User: Identifiable, Codable {
    let id = UUID()
    var name: String
    var email: String
    var role: UserRole
    var profileImageName: String?
    var department: String
    var joinDate: Date
    var isActive: Bool
    var preferences: UserPreferences
    
    init(
        name: String,
        email: String,
        role: UserRole = .user,
        profileImageName: String? = nil,
        department: String = "General",
        joinDate: Date = Date(),
        isActive: Bool = true,
        preferences: UserPreferences = UserPreferences()
    ) {
        self.name = name
        self.email = email
        self.role = role
        self.profileImageName = profileImageName
        self.department = department
        self.joinDate = joinDate
        self.isActive = isActive
        self.preferences = preferences
    }
}

// MARK: - User Role
enum UserRole: String, CaseIterable, Codable {
    case admin = "Administrator"
    case manager = "Manager"
    case technician = "Technician"
    case user = "User"
    
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

// MARK: - User Preferences
struct UserPreferences: Codable {
    var notificationsEnabled: Bool
    var darkModeEnabled: Bool
    var alertsEnabled: Bool
    var emailNotifications: Bool
    var pushNotifications: Bool
    var language: String
    var temperatureUnit: TemperatureUnit
    
    init(
        notificationsEnabled: Bool = true,
        darkModeEnabled: Bool = false,
        alertsEnabled: Bool = true,
        emailNotifications: Bool = true,
        pushNotifications: Bool = true,
        language: String = "English",
        temperatureUnit: TemperatureUnit = .celsius
    ) {
        self.notificationsEnabled = notificationsEnabled
        self.darkModeEnabled = darkModeEnabled
        self.alertsEnabled = alertsEnabled
        self.emailNotifications = emailNotifications
        self.pushNotifications = pushNotifications
        self.language = language
        self.temperatureUnit = temperatureUnit
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