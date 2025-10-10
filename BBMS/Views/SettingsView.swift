import SwiftUI

struct SettingsView: View {
    @StateObject private var userService = UserService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Notification Settings
                Section(header: Text("Notifications")) {
                    Toggle("Enable Notifications", isOn: Binding(
                        get: { userService.currentUser.preferences?.notificationsEnabled ?? false },
                        set: { _ in userService.toggleNotifications() }
                    ))
                    .tint(Color("BBMSGold"))
                    
                    Toggle("Alert Notifications", isOn: Binding(
                        get: { userService.currentUser.preferences?.alertsEnabled ?? false },
                        set: { _ in userService.toggleAlerts() }
                    ))
                    .tint(Color("BBMSGold"))
                    .disabled(!(userService.currentUser.preferences?.notificationsEnabled ?? false))
                    
                    Toggle("Email Notifications", isOn: Binding(
                        get: { userService.currentUser.preferences?.emailNotifications ?? false },
                        set: { _ in userService.toggleEmailNotifications() }
                    ))
                    .tint(Color("BBMSGold"))
                    .disabled(!(userService.currentUser.preferences?.notificationsEnabled ?? false))
                    
                    Toggle("Push Notifications", isOn: Binding(
                        get: { userService.currentUser.preferences?.pushNotifications ?? false },
                        set: { _ in userService.togglePushNotifications() }
                    ))
                    .tint(Color("BBMSGold"))
                    .disabled(!(userService.currentUser.preferences?.notificationsEnabled ?? false))
                }
                
                // Developer Tools (for testing notifications)
                #if DEBUG
                Section(header: Text("Developer Tools")) {
                    NavigationLink(destination: NotificationTestView()) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundColor(.orange)
                            Text("Test Notifications")
                        }
                    }
                }
                #endif
                
                // Security Settings
                Section(header: Text("Security")) {
                    BiometricSettingsRow()
                    
                    NavigationLink(destination: BiometricSettingsView()) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(.blue)
                            Text("Authentication Settings")
                        }
                    }
                }
                
                // Display Settings
                Section(header: Text("Display")) {
                    Toggle("Dark Mode", isOn: Binding(
                        get: { userService.currentUser.preferences?.darkModeEnabled ?? false },
                        set: { _ in userService.toggleDarkMode() }
                    ))
                    .tint(Color("BBMSGold"))
                    
                    Picker("Temperature Unit", selection: Binding(
                        get: { userService.currentUser.preferences?.temperatureUnit ?? .celsius },
                        set: { userService.updateTemperatureUnit($0) }
                    )) {
                        ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                            Text("\(unit.rawValue) (\(unit.symbol))")
                                .tag(unit)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    HStack {
                        Text("Language")
                        Spacer()
                        Text(userService.currentUser.preferences?.language ?? "English")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Data & Privacy
                Section(header: Text("Data & Privacy")) {
                    HStack {
                        Image(systemName: "shield.checkerboard")
                            .foregroundColor(Color("BBMSGold"))
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(Color("BBMSGold"))
                        Text("Terms of Service")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "externaldrive")
                            .foregroundColor(.blue)
                        Text("Data Export")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                // App Information
                Section(header: Text("App Information")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("100")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("Rate App")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(Color("BBMSGold"))
                        Text("Send Feedback")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Account Actions
                Section(header: Text("Account Actions")) {
                    Button(action: {
                        // Reset preferences to default
                        let defaultPreferences = UserPreferences()
                        userService.updatePreferences(defaultPreferences)
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                            Text("Reset to Default")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button(action: {
                        // Sign out
                        userService.logout()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Text("Sign Out")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color("BBMSGold"))
                }
            }
        }
    }
}

// MARK: - Settings Row Views
struct SettingsRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let iconColor: Color
    let action: () -> Void
    
    init(title: String, subtitle: String? = nil, icon: String, iconColor: Color = Color("BBMSGold"), action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView()
}