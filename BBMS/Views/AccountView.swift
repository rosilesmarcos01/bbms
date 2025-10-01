import SwiftUI

struct AccountView: View {
    @StateObject private var userService = UserService.shared
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var showingImagePicker = false
    @State private var showingNotifications = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeader
                    
                    // Quick Stats
                    quickStats
                    
                    // Menu Items
                    menuItems
                    
                    Spacer()
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingImagePicker) {
                ProfileImagePicker(isPresented: $showingImagePicker)
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationSettingsView()
            }
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Profile Image
            Button {
                showingImagePicker = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color("BBMSGold").opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    if let imageName = userService.currentUser.profileImageName {
                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        VStack {
                            Image(systemName: "person.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Color("BBMSGold"))
                            
                            Text("")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Camera overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color("BBMSBlack"))
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            }
                            .offset(x: -40, y: 0)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // User Info
            VStack(spacing: 4) {
                Text(userService.currentUser.name)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(userService.currentUser.email)
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                
                // Role Badge
                HStack {
                    Image(systemName: userService.currentUser.role.icon)
                        .font(.system(size: 12))
                        .foregroundColor(userService.currentUser.role.color)
                    
                    Text(userService.currentUser.role.rawValue)
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundColor(userService.currentUser.role.color)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(userService.currentUser.role.color.opacity(0.1))
                )
                .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }
    
    // MARK: - Quick Stats
    private var quickStats: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Joined",
                value: "\(userService.getYearsOfService())",
                icon: "calendar",
                color: .blue
            )
            
            StatCard(
                title: "Area",
                value: userService.currentUser.department,
                icon: "building.2",
                color: .green
            )
            
            StatCard(
                title: "Status",
                value: userService.currentUser.isActive ? "Active" : "Inactive",
                icon: userService.currentUser.isActive ? "checkmark.circle" : "xmark.circle",
                color: userService.currentUser.isActive ? .green : .red
            )
        }
    }
    
    // MARK: - Menu Items
    private var menuItems: some View {
        VStack(spacing: 12) {
            MenuItemRow(
                title: "Edit Profile",
                subtitle: "Update your personal information",
                icon: "person.crop.circle",
                color: Color("BBMSGold")
            ) {
                showingEditProfile = true
            }
            
            MenuItemRow(
                title: "Settings & Preferences",
                subtitle: "Customize your app experience",
                icon: "gearshape",
                color: .blue
            ) {
                showingSettings = true
            }
            
            MenuItemRow(
                title: "Notifications",
                subtitle: "Manage notification preferences",
                icon: "bell",
                color: .orange
            ) {
                showingNotifications = true
            }
            
            MenuItemRow(
                title: "Security",
                subtitle: "Password and security settings",
                icon: "lock.shield",
                color: .red
            ) {
                // Navigate to security settings
            }
            
            MenuItemRow(
                title: "Help & Support",
                subtitle: "Get help and contact support",
                icon: "questionmark.circle",
                color: .purple
            ) {
                // Navigate to help
            }
            
            MenuItemRow(
                title: "About",
                subtitle: "App version and information",
                icon: "info.circle",
                color: .gray
            ) {
                // Navigate to about
            }
        }
    }
}

// MARK: - Supporting Views
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }
}

struct MenuItemRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon) 
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray5), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AccountView()
}
