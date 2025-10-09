import SwiftUI
import SafariServices
import LocalAuthentication
import CoreImage.CIFilterBuiltins

struct BiometricEnrollmentView: View {
    @StateObject private var biometricService = BiometricAuthService.shared
    @State private var showingEnrollmentSheet = false
    @State private var enrollmentURL: URL?
    @State private var showingQRCode = false
    @State private var qrCodeImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: biometricIconName)
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Biometric Authentication")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Secure your BBMS access with biometric authentication")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                
                // Status Section
                VStack(spacing: 16) {
                    if biometricService.isEnrolled {
                        BiometricStatusCard(
                            icon: "checkmark.circle.fill",
                            title: "Enrollment Complete",
                            subtitle: "You can now use biometric authentication",
                            color: .green
                        )
                    } else if biometricService.isEnrolling {
                        VStack(spacing: 12) {
                            ProgressView(value: biometricService.enrollmentProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .scaleEffect(x: 1, y: 2, anchor: .center)
                            
                            Text(biometricService.enrollmentStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    } else {
                        BiometricStatusCard(
                            icon: "exclamationmark.triangle",
                            title: "Enrollment Required",
                            subtitle: "Set up biometric authentication to enhance security",
                            color: .orange
                        )
                    }
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    if !biometricService.isEnrolled && !biometricService.isEnrolling {
                        Button(action: startEnrollment) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                Text("Start Enrollment")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                    } else if biometricService.isEnrolled {
                        VStack(spacing: 12) {
                            Button(action: testAuthentication) {
                                HStack {
                                    Image(systemName: biometricIconName)
                                    Text("Test Authentication")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                            
                            Button(action: reEnroll) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Re-enroll")
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                    
                    if biometricService.isEnrolling {
                        Button("Check Progress") {
                            Task {
                                if let enrollmentId = KeychainService.shared.getBiometricEnrollmentId() {
                                    await biometricService.checkEnrollmentProgress(enrollmentId: enrollmentId)
                                }
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
                .padding(.bottom, 32)
                
                if let errorMessage = biometricService.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 24)
            .navigationTitle("Biometric Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingEnrollmentSheet) {
                if let url = enrollmentURL {
                    SafariView(url: url)
                        .onDisappear {
                            // When Safari closes, refresh enrollment status
                            refreshEnrollmentStatus()
                        }
                }
            }
            .sheet(isPresented: $showingQRCode) {
                QRCodeView(image: qrCodeImage)
            }
            .onAppear {
                // Refresh enrollment status when view appears
                refreshEnrollmentStatus()
            }
        }
    }
    
    private func refreshEnrollmentStatus() {
        // Check if there's a pending enrollment
        if let enrollmentId = KeychainService.shared.getBiometricEnrollmentId() {
            Task {
                await biometricService.checkEnrollmentProgress(enrollmentId: enrollmentId)
            }
        } else {
            // Just check general enrollment status
            biometricService.checkEnrollmentStatus()
        }
    }
    
    private var biometricIconName: String {
        let context = LAContext()
        switch context.biometryType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        default:
            return "person.crop.circle"
        }
    }
    
    private func startEnrollment() {
        Task {
            do {
                let result = try await biometricService.startBiometricEnrollment()
                
                await MainActor.run {
                    // Show enrollment options
                    showEnrollmentOptions(result: result)
                }
            } catch BiometricError.alreadyEnrolled {
                await MainActor.run {
                    // User is already enrolled, show success message
                    let alert = UIAlertController(
                        title: "✅ Already Enrolled",
                        message: "You are already enrolled in biometric authentication! You can now use it to log in.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        rootViewController.present(alert, animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    biometricService.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func showEnrollmentOptions(result: BiometricEnrollmentResult) {
        let alert = UIAlertController(
            title: "Complete Enrollment",
            message: "Choose how you'd like to complete your biometric enrollment:",
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "Open in Browser", style: .default) { _ in
            if let url = URL(string: result.enrollmentUrl) {
                enrollmentURL = url
                showingEnrollmentSheet = true
            }
        })
        
        alert.addAction(UIAlertAction(title: "Show QR Code", style: .default) { _ in
            generateQRCode(from: result.qrCode)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
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
    
    private func testAuthentication() {
        Task {
            do {
                let result = try await biometricService.authenticateWithBiometrics()
                
                await MainActor.run {
                    if result.success {
                        let alert = UIAlertController(
                            title: "Authentication Successful",
                            message: "Biometric authentication completed successfully!",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            rootViewController.present(alert, animated: true)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    biometricService.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func reEnroll() {
        Task {
            do {
                try await biometricService.reEnrollBiometrics(reason: "User requested re-enrollment")
                
                await MainActor.run {
                    let alert = UIAlertController(
                        title: "Re-enrollment Started",
                        message: "Please complete the enrollment process again.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                        startEnrollment()
                    })
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        rootViewController.present(alert, animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    biometricService.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct QRCodeView: View {
    let image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Scan QR Code")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Use your AuthID app to scan this QR code and complete enrollment")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if let image = image {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(width: 250, height: 250)
                        .overlay(
                            Text("Failed to generate QR code")
                                .foregroundColor(.secondary)
                        )
                }
                
                Spacer()
            }
            .padding()
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

#Preview {
    BiometricEnrollmentView()
}