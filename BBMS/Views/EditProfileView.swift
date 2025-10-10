import SwiftUI

struct EditProfileView: View {
    @StateObject private var userService = UserService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var editedName: String = ""
    @State private var editedEmail: String = ""
    @State private var editedDepartment: String = ""
    @State private var selectedRole: UserRole = .user
    @State private var showingSuccessAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    // Profile Picture Section
                    HStack {
                        Spacer()
                        Button(action: {}) {
                            ZStack {
                                Circle()
                                    .fill(Color("BBMSGold").opacity(0.2))
                                    .frame(width: 80, height: 80)
                                
                                if let imageName = userService.currentUser.profileImageName {
                                    Image(imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(Color("BBMSGold"))
                                }
                                
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        ZStack {
                                            Circle()
                                                .fill(Color("BBMSGold"))
                                                .frame(width: 24, height: 24)
                                            
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.white)
                                        }
                                        .offset(x: -4, y: -4)
                                    }
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    // Name Field
                    HStack {
                        Image(systemName: "person")
                            .foregroundColor(Color("BBMSGold"))
                            .frame(width: 20)
                        
                        TextField("Full Name", text: $editedName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Email Field
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(Color("BBMSGold"))
                            .frame(width: 20)
                        
                        TextField("Email Address", text: $editedEmail)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                    }
                    
                    // Department Field
                    HStack {
                        Image(systemName: "building.2")
                            .foregroundColor(Color("BBMSGold"))
                            .frame(width: 20)
                        
                        TextField("Department", text: $editedDepartment)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                Section(header: Text("Role & Permissions")) {
                    Picker("Role", selection: $selectedRole) {
                        ForEach(UserRole.allCases, id: \.self) { role in
                            HStack {
                                Image(systemName: role.icon)
                                    .foregroundColor(role.color)
                                Text(role.rawValue)
                            }
                            .tag(role)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Account Information")) {
                    HStack {
                        Text("Member Since")
                        Spacer()
                        Text(userService.getFormattedJoinDate())
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Account Status")
                        Spacer()
                        HStack {
                            Circle()
                                .fill((userService.currentUser.isActive ?? true) ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text((userService.currentUser.isActive ?? true) ? "Active" : "Inactive")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color("BBMSGold"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .foregroundColor(Color("BBMSGold"))
                    .fontWeight(.semibold)
                }
            }
            .alert("Profile Updated", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your profile has been successfully updated.")
            }
        }
        .onAppear {
            loadCurrentUserData()
        }
    }
    
    // MARK: - Helper Methods
    private func loadCurrentUserData() {
        editedName = userService.currentUser.name
        editedEmail = userService.currentUser.email
        editedDepartment = userService.currentUser.department
        selectedRole = userService.currentUser.role
    }
    
    private func saveChanges() {
        // Validate inputs
        guard !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        guard !editedEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // Update user data
        userService.updateUserName(editedName.trimmingCharacters(in: .whitespacesAndNewlines))
        userService.updateUserEmail(editedEmail.trimmingCharacters(in: .whitespacesAndNewlines))
        userService.updateUserDepartment(editedDepartment.trimmingCharacters(in: .whitespacesAndNewlines))
        userService.updateUserRole(selectedRole)
        
        // Show success alert
        showingSuccessAlert = true
    }
}

#Preview {
    EditProfileView()
}
