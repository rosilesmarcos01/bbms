import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var userService = UserService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("General Notifications") {
                    Toggle("Master Switch", isOn: Binding(
                        get: { userService.currentUser.preferences.notificationsEnabled },
                        set: { _ in userService.toggleNotifications() }
                    ))
                    .tint(Color("BBMSGold"))
                    
                    if !userService.currentUser.preferences.notificationsEnabled {
                        Text("All notifications are disabled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                
                Section("Notification Types") {
                    VStack(alignment: .leading, spacing: 12) {
                        NotificationToggleRow(
                            title: "System Alerts",
                            description: "Critical system notifications and alerts",
                            icon: "exclamationmark.triangle.fill",
                            iconColor: .red,
                            isEnabled: userService.currentUser.preferences.alertsEnabled,
                            isDisabled: !userService.currentUser.preferences.notificationsEnabled
                        ) {
                            userService.toggleAlerts()
                        }
                        
                        NotificationToggleRow(
                            title: "Device Status",
                            description: "Updates about device connectivity and status",
                            icon: "sensor.tag.radiowaves.forward.fill",
                            iconColor: .blue,
                            isEnabled: true, // This would be another preference
                            isDisabled: !userService.currentUser.preferences.notificationsEnabled
                        ) {
                            // Toggle device notifications
                        }
                        
                        NotificationToggleRow(
                            title: "Zone Activity",
                            description: "Notifications about zone reservations and activity",
                            icon: "location.fill",
                            iconColor: .green,
                            isEnabled: true, // This would be another preference
                            isDisabled: !userService.currentUser.preferences.notificationsEnabled
                        ) {
                            // Toggle zone notifications
                        }
                        
                        NotificationToggleRow(
                            title: "Maintenance",
                            description: "Scheduled maintenance and updates",
                            icon: "wrench.and.screwdriver.fill",
                            iconColor: .orange,
                            isEnabled: true, // This would be another preference
                            isDisabled: !userService.currentUser.preferences.notificationsEnabled
                        ) {
                            // Toggle maintenance notifications
                        }
                    }
                }
                
                Section("Delivery Methods") {
                    Toggle("Push Notifications", isOn: Binding(
                        get: { userService.currentUser.preferences.pushNotifications },
                        set: { _ in userService.togglePushNotifications() }
                    ))
                    .tint(Color("BBMSGold"))
                    .disabled(!userService.currentUser.preferences.notificationsEnabled)
                    
                    Toggle("Email Notifications", isOn: Binding(
                        get: { userService.currentUser.preferences.emailNotifications },
                        set: { _ in userService.toggleEmailNotifications() }
                    ))
                    .tint(Color("BBMSGold"))
                    .disabled(!userService.currentUser.preferences.notificationsEnabled)
                }
                
                Section("Quiet Hours") {
                    HStack {
                        Text("Do Not Disturb")
                        Spacer()
                        Text("10:00 PM - 7:00 AM")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .opacity(userService.currentUser.preferences.notificationsEnabled ? 1.0 : 0.5)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color("BBMSGold"))
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct NotificationToggleRow: View {
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
    let isEnabled: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: .constant(isEnabled))
                .tint(Color("BBMSGold"))
                .disabled(isDisabled)
                .onTapGesture {
                    if !isDisabled {
                        action()
                    }
                }
        }
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}

#Preview {
    NotificationSettingsView()
}