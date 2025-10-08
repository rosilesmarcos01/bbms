import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @StateObject private var authService = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var name = ""
    @State private var department = ""
    @State private var showingBiometricSetup = false
    @State private var biometricType: LABiometryType = .none
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Logo and Header
                    VStack(spacing: 20) {
                        ModernLogoView()
                        
                        Text("Building Management System")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(isRegistering ? "Create Account" : "Welcome Back")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Authentication Form
                    VStack(spacing: 20) {
                        if isRegistering {
                            registrationForm
                        } else {
                            loginForm
                        }
                        
                        // Biometric Authentication (only for login)
                        if !isRegistering && biometricType != .none {
                            biometricLoginButton
                        }
                        
                        // Toggle between login/register
                        toggleModeButton
                    }
                    .padding(.horizontal, 30)
                    
                    // Error Message
                    if let errorMessage = authService.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color("BBMSBlue").opacity(0.1), Color.clear]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .onAppear {
            setupBiometricType()
        }
        .sheet(isPresented: $showingBiometricSetup) {
            BiometricSetupView()
        }
    }
    
    // MARK: - Login Form
    private var loginForm: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $email)
                .textFieldStyle(ModernTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            SecureField("Password", text: $password)
                .textFieldStyle(ModernTextFieldStyle())
            
            Button(action: {
                Task { await authService.login(email: email, password: password) }
            }) {
                HStack {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "person.circle.fill")
                        Text("Sign In")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("BBMSBlue"))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(email.isEmpty || password.isEmpty || authService.isLoading)
        }
    }
    
    // MARK: - Registration Form
    private var registrationForm: some View {
        VStack(spacing: 16) {
            TextField("Full Name", text: $name)
                .textFieldStyle(ModernTextFieldStyle())
            
            TextField("Email", text: $email)
                .textFieldStyle(ModernTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            TextField("Department", text: $department)
                .textFieldStyle(ModernTextFieldStyle())
            
            SecureField("Password", text: $password)
                .textFieldStyle(ModernTextFieldStyle())
            
            Button(action: {
                Task { 
                    await authService.register(
                        name: name,
                        email: email,
                        password: password,
                        department: department
                    )
                    // Show biometric setup after successful registration
                    if authService.isAuthenticated {
                        showingBiometricSetup = true
                    }
                }
            }) {
                HStack {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "person.badge.plus")
                        Text("Create Account")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("BBMSGreen"))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(name.isEmpty || email.isEmpty || password.isEmpty || department.isEmpty || authService.isLoading)
        }
    }
    
    // MARK: - Biometric Login Button
    private var biometricLoginButton: some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color.gray.opacity(0.3))
            
            Button(action: {
                Task { await authService.biometricLogin() }
            }) {
                HStack {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color("BBMSBlue")))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: biometricIcon)
                            .font(.system(size: 20))
                        Text("Sign in with \(biometricName)")
                            .fontWeight(.medium)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("BBMSBlue").opacity(0.1))
                .foregroundColor(Color("BBMSBlue"))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("BBMSBlue"), lineWidth: 1)
                )
            }
            .disabled(authService.isLoading)
        }
    }
    
    // MARK: - Toggle Mode Button
    private var toggleModeButton: some View {
        VStack(spacing: 16) {
            Divider()
                .background(Color.gray.opacity(0.3))
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isRegistering.toggle()
                    // Clear form fields
                    email = ""
                    password = ""
                    name = ""
                    department = ""
                }
            }) {
                HStack {
                    Text(isRegistering ? "Already have an account?" : "Don't have an account?")
                        .foregroundColor(.secondary)
                    Text(isRegistering ? "Sign In" : "Sign Up")
                        .fontWeight(.semibold)
                        .foregroundColor(Color("BBMSBlue"))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func setupBiometricType() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        }
    }
    
    private var biometricIcon: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock.fill"
        }
    }
    
    private var biometricName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "Biometrics"
        }
    }
}

// MARK: - Modern Text Field Style
struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Biometric Setup View
struct BiometricSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared
    @State private var enrollmentResponse: BiometricEnrollmentResponse?
    @State private var isEnrolling = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 20) {
                    Image(systemName: "faceid")
                        .font(.system(size: 60))
                        .foregroundColor(Color("BBMSBlue"))
                    
                    Text("Set Up Biometric Authentication")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Enable Face ID or Touch ID for secure and convenient access to the building management system.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                if let enrollment = enrollmentResponse {
                    VStack(spacing: 20) {
                        Text("Enrollment initiated successfully!")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        if enrollment.qrCode != nil {
                            Text("Scan the QR code or visit the enrollment URL to complete setup.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button("View Enrollment Details") {
                            // Open enrollment URL or show QR code
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Button(action: {
                        Task {
                            isEnrolling = true
                            enrollmentResponse = await authService.initiateBiometricEnrollment()
                            isEnrolling = false
                        }
                    }) {
                        HStack {
                            if isEnrolling {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "person.badge.plus")
                                Text("Enable Biometric Authentication")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("BBMSBlue"))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isEnrolling)
                    .padding(.horizontal)
                }
                
                Button("Skip for Now") {
                    dismiss()
                }
                .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Biometric Setup")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    LoginView()
}