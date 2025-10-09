import SwiftUI
import LocalAuthentication

// MARK: - Biometric Settings Row for Settings View
struct BiometricSettingsRow: View {
    @StateObject private var biometricService = BiometricAuthService.shared
    @State private var showingBiometricSetup = false
    
    var body: some View {
        Button(action: {
            showingBiometricSetup = true
        }) {
            HStack {
                Image(systemName: biometricIconName)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Biometric Authentication")
                        .foregroundColor(.primary)
                    
                    Text(biometricService.isEnrolled ? "Enabled" : "Not Set Up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if biometricService.isEnrolled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
        .sheet(isPresented: $showingBiometricSetup) {
            BiometricEnrollmentView()
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
}

// MARK: - Biometric Status Card Component
struct BiometricStatusCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    VStack {
        BiometricSettingsRow()
        BiometricStatusCard(
            icon: "checkmark.circle.fill",
            title: "Enrollment Complete",
            subtitle: "You can now use biometric authentication",
            color: .green
        )
    }
    .padding()
}