import Foundation
import SwiftUI

// MARK: - User Service
@MainActor
class UserService: ObservableObject {
    @Published var currentUser: User
    @Published var isLoading = false
    
    static let shared = UserService()
    
    private init() {
        // Initialize with a default user - will be updated by AuthService
        self.currentUser = User(
            name: "Guest User",
            email: "guest@bbms.local",
            role: .user,
            department: "General"
        )
    }
    
    // MARK: - User Management
    func updateUser(_ user: User) {
        currentUser = user
        saveUserToStorage()
    }
    
    func setAuthenticatedUser(_ user: User) {
        currentUser = user
        saveUserToStorage()
    }
    
    func clearUser() {
        currentUser = User(
            name: "Guest User",
            email: "guest@bbms.local",
            role: .user,
            department: "General"
        )
        clearUserStorage()
    }
    
    func updateUserName(_ name: String) {
        currentUser.name = name
        saveUserToStorage()
        
        // Update with auth service
        Task {
            await updateProfileWithAuthService()
        }
    }
    
    func updateUserEmail(_ email: String) {
        currentUser.email = email
        saveUserToStorage()
        
        // Update with auth service
        Task {
            await updateProfileWithAuthService()
        }
    }
    
    func updateUserDepartment(_ department: String) {
        currentUser.department = department
        saveUserToStorage()
        
        // Update with auth service
        Task {
            await updateProfileWithAuthService()
        }
    }
    
    func updateUserRole(_ role: UserRole) {
        currentUser.role = role
        saveUserToStorage()
    }
    
    func updateUserAccessLevel(_ accessLevel: AccessLevel) {
        currentUser.accessLevel = accessLevel
        saveUserToStorage()
    }
    
    // MARK: - Auth Service Integration
    private func updateProfileWithAuthService() async {
        await AuthService.shared.updateProfile(
            name: currentUser.name,
            department: currentUser.department
        )
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
    
    private func clearUserStorage() {
        // Clear any locally stored user data
        print("User data cleared")
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
