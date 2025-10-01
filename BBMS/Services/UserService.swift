import Foundation
import SwiftUI

// MARK: - User Service
@MainActor
class UserService: ObservableObject {
    @Published var currentUser: User
    @Published var isLoading = false
    
    static let shared = UserService()
    
    private init() {
        // Initialize with a sample user
        self.currentUser = User(
            name: "Marcos Rosiles",
            email: "marcos@rubidex.ai",
            role: .manager,
            department: "QA",
            joinDate: Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
        )
    }
    
    // MARK: - User Management
    func updateUser(_ user: User) {
        currentUser = user
        saveUserToStorage()
    }
    
    func updateUserName(_ name: String) {
        currentUser.name = name
        saveUserToStorage()
    }
    
    func updateUserEmail(_ email: String) {
        currentUser.email = email
        saveUserToStorage()
    }
    
    func updateUserDepartment(_ department: String) {
        currentUser.department = department
        saveUserToStorage()
    }
    
    func updateUserRole(_ role: UserRole) {
        currentUser.role = role
        saveUserToStorage()
    }
    
    // MARK: - Preferences Management
    func updatePreferences(_ preferences: UserPreferences) {
        currentUser.preferences = preferences
        saveUserToStorage()
    }
    
    func toggleNotifications() {
        currentUser.preferences.notificationsEnabled.toggle()
        saveUserToStorage()
    }
    
    func toggleDarkMode() {
        currentUser.preferences.darkModeEnabled.toggle()
        saveUserToStorage()
    }
    
    func toggleAlerts() {
        currentUser.preferences.alertsEnabled.toggle()
        saveUserToStorage()
    }
    
    func toggleEmailNotifications() {
        currentUser.preferences.emailNotifications.toggle()
        saveUserToStorage()
    }
    
    func togglePushNotifications() {
        currentUser.preferences.pushNotifications.toggle()
        saveUserToStorage()
    }
    
    func updateTemperatureUnit(_ unit: TemperatureUnit) {
        currentUser.preferences.temperatureUnit = unit
        saveUserToStorage()
    }
    
    func updateLanguage(_ language: String) {
        currentUser.preferences.language = language
        saveUserToStorage()
    }
    
    // MARK: - Profile Image Management
    func updateProfileImage(_ imageName: String?) {
        currentUser.profileImageName = imageName
        saveUserToStorage()
    }
    
    // MARK: - Data Persistence
    private func saveUserToStorage() {
        // In a real app, this would save to UserDefaults, Core Data, or a remote service
        // For now, we'll just simulate the save
        print("User data saved: \(currentUser.name)")
    }
    
    private func loadUserFromStorage() {
        // In a real app, this would load from UserDefaults, Core Data, or a remote service
        // For now, we'll use the default user
    }
    
    // MARK: - Authentication Simulation
    func logout() {
        // Reset to default user or clear user data
        currentUser = User(
            name: "Guest User",
            email: "guest@company.com",
            role: .user,
            department: "General"
        )
    }
    
    // MARK: - Utility Methods
    func getFormattedJoinDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: currentUser.joinDate)
    }
    
    func getYearsOfService() -> Int {
        let calendar = Calendar.current
        let years = calendar.dateComponents([.year], from: currentUser.joinDate, to: Date()).year ?? 0
        return years
    }
}
