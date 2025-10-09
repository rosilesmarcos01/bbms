import SwiftUI
import LocalAuthentication

struct BiometricSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared
    @StateObject private var biometricService = BiometricAuthService.shared
    @State private var enrollmentStatus: BiometricEnrollmentStatus?
    @State private var isLoadingStatus = false
    @State private var showingEnrollment = false
    @State private var biometricType: LABiometryType = .none
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    biometricHeader
                    
                    // Enrollment Status
                    enrollmentStatusSection
                    
                    // Biometric Actions
                    biometricActions
                    
                    // Security Information
                    securityInfo
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Biometric Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadEnrollmentStatus()
            setupBiometricType()
        }
        .sheet(isPresented: $showingEnrollment) {
            BiometricSetupView()
        }
    }
    
    // MARK: - Biometric Header
    private var biometricHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: biometricIcon)
                .font(.system(size: 60))
                .foregroundColor(Color("BBMSBlue"))
            
            Text("Biometric Authentication")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Use \(biometricName) for secure and convenient access to the building management system.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("BBMSBlue").opacity(0.05))
        )
    }
    
    // MARK: - Enrollment Status Section
    private var enrollmentStatusSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Enrollment Status")
                    .font(.headline)
                Spacer()
                if isLoadingStatus {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let status = enrollmentStatus {
                EnrollmentStatusCard(status: status)
            } else {
                notEnrolledCard
            }
        }
    }
    
    // MARK: - Not Enrolled Card
    private var notEnrolledCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            
            Text("Not Enrolled")
                .font(.headline)
                .foregroundColor(.orange)
            
            Text("Biometric authentication is not set up for your account.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Biometric Actions
    private var biometricActions: some View {
        VStack(spacing: 12) {
            if enrollmentStatus?.completed == true {
                // Re-enroll button
                Button(action: {
                    showingEnrollment = true
                }) {
                    ActionButtonContent(
                        title: "Re-enroll Biometrics",
                        subtitle: "Update your biometric data",
                        icon: "arrow.clockwise",
                        color: .blue
                    )
                }
                
                // Test verification button
                Button(action: {
                    Task {
                        await testBiometricVerification()
                    }
                }) {
                    ActionButtonContent(
                        title: "Test Verification",
                        subtitle: "Test your biometric authentication",
                        icon: "checkmark.shield",
                        color: .green
                    )
                }
                
            } else {
                // Initial enrollment button
                Button(action: {
                    showingEnrollment = true
                }) {
                    ActionButtonContent(
                        title: "Set Up Biometric Authentication",
                        subtitle: "Enable secure biometric login",
                        icon: "plus.circle",
                        color: Color("BBMSBlue")
                    )
                }
            }
        }
    }
    
    // MARK: - Security Information
    private var securityInfo: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Security Information")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                SecurityInfoRow(
                    icon: "shield.checkered",
                    title: "Data Protection",
                    description: "Your biometric data is encrypted and stored securely"
                )
                
                SecurityInfoRow(
                    icon: "eye.slash",
                    title: "Privacy",
                    description: "Biometric templates cannot be reverse-engineered"
                )
                
                SecurityInfoRow(
                    icon: "trash",
                    title: "Data Removal",
                    description: "You can remove your biometric data at any time"
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    private func loadEnrollmentStatus() async {
        isLoadingStatus = true
        enrollmentStatus = await authService.getBiometricEnrollmentStatus()
        isLoadingStatus = false
    }
    
    private func setupBiometricType() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        }
    }
    
    private func testBiometricVerification() async {
        // Implement biometric test verification
        print("Testing biometric verification...")
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

// MARK: - Enrollment Status Card
struct EnrollmentStatusCard: View {
    let status: BiometricEnrollmentStatus
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: statusIcon)
                    .font(.system(size: 20))
                    .foregroundColor(statusColor)
                
                Text(statusText)
                    .font(.headline)
                    .foregroundColor(statusColor)
                
                Spacer()
            }
            
            if !status.completed {
                ProgressView(value: Double(status.progress), total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: statusColor))
                
                Text("\(status.progress)% Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                BiometricInfoRow(label: "Enrollment ID", value: status.enrollmentId)
                BiometricInfoRow(label: "Status", value: status.status.capitalized)
                BiometricInfoRow(label: "Created", value: formatDate(status.createdAt))
                if !status.completed {
                    BiometricInfoRow(label: "Expires", value: formatDate(status.expiresAt))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(statusColor.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var statusIcon: String {
        switch status.status {
        case "completed":
            return "checkmark.circle.fill"
        case "failed":
            return "xmark.circle.fill"
        case "initiated", "in_progress":
            return "clock.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch status.status {
        case "completed":
            return .green
        case "failed":
            return .red
        case "initiated", "in_progress":
            return .orange
        default:
            return .gray
        }
    }
    
    private var statusText: String {
        switch status.status {
        case "completed":
            return "Enrolled Successfully"
        case "failed":
            return "Enrollment Failed"
        case "initiated":
            return "Enrollment Started"
        case "in_progress":
            return "Enrollment In Progress"
        default:
            return "Unknown Status"
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Supporting Views
struct ActionButtonContent: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

struct SecurityInfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color("BBMSBlue"))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct BiometricInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    BiometricSettingsView()
}