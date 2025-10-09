import SwiftUI
import LocalAuthentication
import SafariServices
import CoreImage.CIFilterBuiltins

struct LoginView: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var biometricService = BiometricAuthService.shared
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
                    VStack(spacing: 0) {
                        ModernLogoView(size: 160)
                        
                        Text("Hello there!")
                            .font(.title)
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
                            biometricLoginSection
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
            BiometricEnrollmentView()
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
                .background(Color("BBMSGold"))
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
    
    // MARK: - Biometric Login Section
    private var biometricLoginSection: some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color.gray.opacity(0.3))
            
            if biometricService.isEnrolled {
                // User is enrolled - show biometric login button
                Button(action: {
                    Task { await authService.biometricLogin() }
                }) {
                    HStack {
                        if authService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color("BBMSGold")))
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
                    .background(Color("BBMSGold").opacity(0.1))
                    .foregroundColor(Color("BBMSGold"))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color("BBMSGold"), lineWidth: 1)
                    )
                }
                .disabled(authService.isLoading)
            } else {
                // User not enrolled - show setup button
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: biometricIcon)
                            .foregroundColor(.orange)
                        Text("Biometric Authentication Available")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    Button("Set Up \(biometricName)") {
                        showingBiometricSetup = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
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
                        .foregroundColor(Color("BBMSGold"))
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
    @State private var enrollmentResponse: AuthServiceBiometricEnrollmentResponse?
    @State private var isEnrolling = false
    @State private var showingQRCode = false
    @State private var qrCodeImage: UIImage?
    @State private var showingEnrollmentURL = false
    
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
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("Enrollment Ready!")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Text("Complete your biometric enrollment using the AuthID web interface:")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            // Open Enrollment Page Button
                            Button(action: {
                                if let urlString = enrollment.enrollmentUrl {
                                    print("🔍 Attempting to open enrollment URL: \(urlString)")
                                    if let url = URL(string: urlString) {
                                        print("✅ Valid URL created: \(url)")
                                        showingEnrollmentURL = true
                                    } else {
                                        print("❌ Invalid URL: \(urlString)")
                                    }
                                } else {
                                    print("❌ No enrollment URL available")
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.up.right.square")
                                    Text("Open Enrollment Page")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            
                            // Show QR Code Button
                            if let qrCodeString = enrollment.qrCode {
                                Button(action: {
                                    generateQRCode(from: qrCodeString)
                                }) {
                                    HStack {
                                        Image(systemName: "qrcode")
                                        Text("Show QR Code")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Show enrollment details for reference
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enrollment Details:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .bold()
                            
                            DetailRow(label: "Status", value: "Ready ✅")
                            DetailRow(label: "ID", value: enrollment.enrollmentId ?? "N/A")
                            DetailRow(label: "Expires", value: enrollment.expiresAt ?? "N/A")
                            
                            // Show URL for debugging
                            VStack(alignment: .leading, spacing: 4) {
                                Text("URL:")
                                    .foregroundColor(.secondary)
                                Text(enrollment.enrollmentUrl ?? "No URL available")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                                    .lineLimit(2)
                            }
                        }
                        .font(.caption2)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                } else {
                    Button(action: {
                        Task {
                            isEnrolling = true
                            enrollmentResponse = await authService.initiateBiometricEnrollment()
                            isEnrolling = false
                            
                            // Check if already enrolled
                            if let response = enrollmentResponse, response.status == "completed" {
                                // Show success message
                                let alert = UIAlertController(
                                    title: "✅ Already Enrolled",
                                    message: "You are already enrolled in biometric authentication! You can close this window.",
                                    preferredStyle: .alert
                                )
                                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                                    dismiss()
                                })
                                
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let rootViewController = windowScene.windows.first?.rootViewController {
                                    rootViewController.present(alert, animated: true)
                                }
                            }
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
            .sheet(isPresented: $showingQRCode) {
                QRCodeDisplayView(image: qrCodeImage, enrollmentURL: enrollmentResponse?.enrollmentUrl)
            }
            .sheet(isPresented: $showingEnrollmentURL) {
                if let enrollment = enrollmentResponse,
                   let urlString = enrollment.enrollmentUrl,
                   let url = URL(string: urlString) {
                    SafariView(url: url)
                        .onDisappear {
                            // When Safari closes, check if enrollment completed
                            checkEnrollmentCompletion()
                        }
                }
            }
        }
    }
    
    // Check if enrollment completed after closing Safari
    private func checkEnrollmentCompletion() {
        Task {
            do {
                // Give the backend a moment to process
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                // Check enrollment status
                let enrollmentStatus = try await authService.checkBiometricEnrollmentStatus()
                
                await MainActor.run {
                    if enrollmentStatus.isEnrolled {
                        // Clear enrollment response
                        enrollmentResponse = nil
                        
                        // Show success alert
                        let alert = UIAlertController(
                            title: "✅ Enrollment Complete",
                            message: "Your biometric authentication has been set up successfully!",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                            // Dismiss the BiometricSetupView after showing success
                            dismiss()
                        })
                        
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            rootViewController.present(alert, animated: true)
                        }
                    }
                }
            } catch {
                print("Error checking enrollment completion: \(error)")
            }
        }
    }
    
    // Helper method to generate QR code
    private func generateQRCode(from string: String) {
        let data = Data(string.utf8)
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        
        if let qrCodeImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledQRCode = qrCodeImage.transformed(by: transform)
            self.qrCodeImage = UIImage(ciImage: scaledQRCode)
            showingQRCode = true
        }
    }
}

// MARK: - QR Code Display View
struct QRCodeDisplayView: View {
    let image: UIImage?
    let enrollmentURL: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Scan this QR Code")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Use your phone's camera or a QR code scanner to open the enrollment page")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if let qrImage = image {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                } else {
                    ProgressView()
                        .frame(width: 250, height: 250)
                }
                
                if let urlString = enrollmentURL {
                    VStack(spacing: 8) {
                        Text("Or copy this URL:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(urlString)
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            UIPasteboard.general.string = urlString
                        }) {
                            Label("Copy URL", systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Enrollment QR Code")
            .navigationBarTitleDisplayMode(.inline)
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

// Helper view for displaying detail rows
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

#Preview {
    LoginView()
}
