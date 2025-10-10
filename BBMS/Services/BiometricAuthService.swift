import Foundation
import SwiftUI
import LocalAuthentication
import CryptoKit

// MARK: - Biometric Authentication Service
@MainActor
class BiometricAuthService: ObservableObject {
    @Published var isEnrolled = false
    @Published var enrollmentProgress: Double = 0.0
    @Published var enrollmentStatus: String = ""
    @Published var isEnrolling = false
    @Published var errorMessage: String?
    
    private let keychain = KeychainService.shared
    // Configuration is managed in Config/AppConfig.swift
    // Update IP by running ./update-ip.sh and rebuilding the app
    private let authBaseURL = AppConfig.authBaseURL
    
    static let shared = BiometricAuthService()
    
    private init() {
        checkEnrollmentStatus()
    }
    
    // MARK: - Check if user is enrolled in AuthID
    func checkEnrollmentStatus() {
        Task {
            do {
                print("🔍 BiometricAuthService: Checking enrollment status...")
                
                // First, check if there's a stored enrollment flag in keychain
                let isEnrolledInKeychain = keychain.isBiometricEnrolled()
                let enrollmentId = keychain.getBiometricEnrollmentId()
                
                print("📦 Keychain check:")
                print("  - isEnrolled: \(isEnrolledInKeychain)")
                print("  - enrollmentId: \(enrollmentId ?? "nil")")
                
                // Debug: Check the raw keychain value
                let rawValue = keychain.get(forKey: "biometric_enrolled")
                print("  - raw biometric_enrolled value: '\(rawValue ?? "nil")'")
                
                if isEnrolledInKeychain {
                    await MainActor.run {
                        self.isEnrolled = true
                        print("✅ Set isEnrolled = true from keychain")
                    }
                } else {
                    print("⚠️ isEnrolled = false in keychain")
                }
                
                // Then verify with backend if we have a user ID
                guard let userId = await getCurrentUserId() else { 
                    print("ℹ️ No user logged in, using keychain enrollment status only")
                    
                    // IMPORTANT: If we have an enrollment ID but no enrollment flag,
                    // this might mean enrollment completed but wasn't saved to keychain
                    // Try to check one more time with the backend using the stored email
                    if let enrollmentId = enrollmentId, !isEnrolledInKeychain {
                        print("🔄 Found enrollmentId but not enrolled - attempting to verify with backend")
                        await checkEnrollmentProgress(enrollmentId: enrollmentId)
                    }
                    return 
                }
                
                print("👤 User ID found: \(userId)")
                
                if let enrollmentId = enrollmentId {
                    print("🔄 Checking enrollment progress with backend...")
                    await checkEnrollmentProgress(enrollmentId: enrollmentId)
                }
            } catch {
                print("❌ Error checking enrollment status: \(error)")
            }
        }
    }
    
    // MARK: - Start Biometric Enrollment with AuthID
    func startBiometricEnrollment() async throws -> BiometricEnrollmentResult {
        isEnrolling = true
        errorMessage = nil
        
        guard let userId = await getCurrentUserId(),
              let user = await getCurrentUser() else {
            throw BiometricError.userNotFound
        }
        
        // Step 1: Initiate enrollment with AuthID
        let enrollmentRequest = BiometricEnrollmentRequest(
            userId: userId,
            userData: AuthIDUserData(
                name: user.name,
                email: user.email,
                department: user.department,
                role: user.role.rawValue,
                accessLevel: user.accessLevel.rawValue
            )
        )
        
        let response: BiometricEnrollmentAPIResponse = try await performAPIRequest(
            endpoint: "/biometric/enroll",
            method: "POST",
            body: enrollmentRequest
        )
        
        // Check if user is already enrolled
        if response.alreadyEnrolled == true {
            await MainActor.run {
                self.isEnrolled = true
                self.isEnrolling = false
                self.enrollmentStatus = "Already enrolled"
                self.enrollmentProgress = 1.0
            }
            
            // Return a result indicating they're already enrolled
            throw BiometricError.alreadyEnrolled
        }
        
        // Store enrollment ID for tracking
        keychain.setBiometricEnrollmentId(response.enrollment.enrollmentId)
        
        await MainActor.run {
            self.enrollmentStatus = "Enrollment initiated"
            self.enrollmentProgress = 0.1
        }
        
        return BiometricEnrollmentResult(
            enrollmentId: response.enrollment.enrollmentId,
            enrollmentUrl: response.enrollment.enrollmentUrl ?? "",
            qrCode: response.enrollment.qrCode ?? "",
            expiresAt: response.enrollment.expiresAt ?? ""
        )
    }
    
    // MARK: - Check Enrollment Progress
    func checkEnrollmentProgress(enrollmentId: String) async {
        do {
            print("🔍 Checking enrollment progress for ID: \(enrollmentId)")
            print("📤 Calling: GET /biometric/enrollment/status?enrollmentId=\(enrollmentId)")
            
            let response: EnrollmentStatusResponse = try await performAPIRequest(
                endpoint: "/biometric/enrollment/status?enrollmentId=\(enrollmentId)",
                method: "GET"
            )
            
            print("✅ Received enrollment status response!")
            print("📊 Enrollment status response:")
            print("  - enrollment.enrollmentId: \(response.enrollment.enrollmentId)")
            print("  - enrollment.status: \(response.enrollment.status)")
            print("  - enrollment.progress: \(response.enrollment.progress)")
            print("  - enrollment.completed: \(response.enrollment.completed)")
            print("  - computed status: \(response.status)")
            print("  - computed progress: \(response.progress)")
            print("  - computed completed: \(response.completed)")
            
            await MainActor.run {
                self.enrollmentProgress = Double(response.progress) / 100.0
                self.enrollmentStatus = response.status
                self.isEnrolled = response.completed
                
                print("🎯 Setting isEnrolled to: \(response.completed)")
                
                if response.completed {
                    self.isEnrolling = false
                    // Store that user is enrolled
                    self.keychain.setBiometricEnrolled(true)
                    self.keychain.setBiometricEnrollmentId(response.enrollment.enrollmentId)
                    print("✅ Saved biometric_enrolled = true to keychain")
                    print("✅ Saved enrollmentId = \(response.enrollment.enrollmentId) to keychain")
                    print("🔍 Verifying keychain save:")
                    print("   - isBiometricEnrolled: \(self.keychain.isBiometricEnrolled())")
                    print("   - enrollmentId: \(self.keychain.getBiometricEnrollmentId() ?? "nil")")
                } else {
                    print("⏳ Enrollment not yet completed (status: \(response.status))")
                }
            }
            
        } catch {
            print("❌ Error checking enrollment progress: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                print("❌ Decoding error: \(decodingError)")
            }
            
            await MainActor.run {
                self.errorMessage = "Failed to check enrollment status: \(error.localizedDescription)"
                self.isEnrolling = false
            }
        }
    }
    
    // MARK: - Perform Biometric Authentication
    func authenticateWithBiometrics() async throws -> BiometricAuthResult {
        // Step 1: Get current user email from AuthService or Keychain
        guard let userEmail = await getCurrentUserEmail() else {
            throw BiometricError.userNotFound
        }
        
        print("🔐 Starting biometric authentication for: \(userEmail)")
        
        // Step 2: Initiate biometric login with backend
        let initiateResponse = try await initiateBiometricLogin(email: userEmail)
        
        print("✅ Received AuthID URL: \(initiateResponse.authIdUrl)")
        print("📋 Operation ID: \(initiateResponse.operationId)")
        
        // Step 3: Open Safari for user to complete face scan
        await openAuthIDUrl(initiateResponse.authIdUrl)
        
        // Step 4: Poll for authentication result
        print("⏳ Polling for authentication result...")
        let pollResponse = try await pollForAuthenticationResult(operationId: initiateResponse.operationId)
        
        if pollResponse.status == "completed" {
            print("✅ Biometric authentication completed successfully")
            
            // Return result with tokens
            return BiometricAuthResult(
                success: true,
                user: pollResponse.user,
                verification: nil,
                tokens: pollResponse.tokens
            )
        } else if pollResponse.status == "failed" {
            print("❌ Biometric authentication failed")
            throw BiometricError.authenticationFailed
        } else {
            print("⚠️ Biometric authentication timed out")
            throw BiometricError.authenticationFailed
        }
    }
    
    // MARK: - Initiate Biometric Login
    private func initiateBiometricLogin(email: String) async throws -> InitiateLoginResponse {
        print("📤 Initiating biometric login for: \(email)")
        
        let request = InitiateLoginRequest(email: email)
        
        let response: InitiateLoginResponse = try await performAPIRequest(
            endpoint: "/auth/biometric-login/initiate",
            method: "POST",
            body: request,
            requiresAuth: false  // No auth token needed - user is logging in!
        )
        
        print("✅ Initiate response received")
        return response
    }
    
    // MARK: - Open AuthID URL in Safari
    @MainActor
    private func openAuthIDUrl(_ urlString: String) async {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid AuthID URL: \(urlString)")
            return
        }
        
        print("🌐 Opening Safari for face scan...")
        UIApplication.shared.open(url, options: [:]) { success in
            if success {
                print("✅ Safari opened successfully")
            } else {
                print("❌ Failed to open Safari")
            }
        }
        
        // Wait a moment for Safari to open before starting to poll
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
    }
    
    // MARK: - Poll for Authentication Result
    private func pollForAuthenticationResult(operationId: String) async throws -> PollLoginResponse {
        let maxAttempts = 60 // 2 minutes max (60 attempts x 2 seconds)
        var attempt = 0
        
        while attempt < maxAttempts {
            attempt += 1
            
            do {
                let response: PollLoginResponse = try await performPollRequest(
                    operationId: operationId
                )
                
                print("📊 Poll attempt \(attempt): status=\(response.status)")
                
                if response.status == "completed" {
                    // Check if we have tokens
                    if let tokens = response.tokens {
                        print("✅ Poll completed with tokens!")
                        print("   - accessToken: \(tokens.accessToken.prefix(20))...")
                        print("   - refreshToken: \(tokens.refreshToken?.prefix(20) ?? "none")...")
                        if let user = response.user {
                            print("   - user: \(user.email)")
                        }
                        return response
                    } else {
                        print("⚠️ Poll completed but no tokens - session may have expired")
                        throw BiometricError.authenticationFailed
                    }
                } else if response.status == "failed" {
                    print("❌ Poll failed")
                    throw BiometricError.authenticationFailed
                }
                
                // Wait 2 seconds before next poll
                try await Task.sleep(nanoseconds: 2_000_000_000)
                
            } catch {
                // If we get a network error, wait and retry
                print("⚠️ Poll attempt \(attempt) failed: \(error.localizedDescription)")
                
                if attempt >= maxAttempts {
                    throw error
                }
                
                try await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        
        // If we've exhausted all attempts, throw timeout error
        throw BiometricError.authenticationFailed
    }
    
    // MARK: - Generate Biometric Template (Secure Implementation)
    private func generateBiometricTemplate(context: LAContext) async throws -> String {
        // In a real implementation, this would:
        // 1. Capture actual biometric data (face scan, etc.)
        // 2. Process it into AuthID's expected format
        // 3. Encrypt it properly
        
        // For now, we'll create a secure hash based on device and user info
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let timestamp = Date().timeIntervalSince1970
        let biometricType = getBiometricType(context: context)
        
        let dataString = "\(deviceId)-\(biometricType)-\(timestamp)"
        let data = Data(dataString.utf8)
        let hash = SHA256.hash(data: data)
        
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Biometric Type Detection
    private func getBiometricType(context: LAContext) -> String {
        switch context.biometryType {
        case .faceID:
            return "face"
        case .touchID:
            return "fingerprint"
        case .opticID:
            return "optic"
        default:
            return "unknown"
        }
    }
    
    // MARK: - Helper Methods
    private func getCurrentUserId() async -> String? {
        // Get current user ID from AuthService or storage
        return AuthService.shared.currentUser?.id.uuidString
    }
    
    private func getCurrentUserEmail() async -> String? {
        // First try to get from current user
        if let email = AuthService.shared.currentUser?.email {
            return email
        }
        
        // If no current user, try to get from keychain (for logout/login scenario)
        return keychain.get(forKey: "last_user_email")
    }
    
    // MARK: - Specialized Poll Request (No Caching)
    private func performPollRequest(operationId: String) async throws -> PollLoginResponse {
        guard let url = URL(string: "\(authBaseURL)/auth/biometric-login/poll/\(operationId)") else {
            throw BiometricError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // CRITICAL: Disable caching for polling to prevent stale responses
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        
        // Add timestamp to prevent any caching
        request.setValue(String(Date().timeIntervalSince1970), forHTTPHeaderField: "X-Poll-Timestamp")
        
        print("🔄 Polling with cache disabled: \(operationId)")
        
        let (data, response) = try await NetworkService.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BiometricError.networkError
        }
        
        print("📡 Poll response: \(httpResponse.statusCode) - \(data.count) bytes")
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw BiometricError.networkError
        }
        
        // Debug: Print raw JSON for large responses (likely containing tokens)
        if data.count > 500 {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔍 Raw JSON response (\(data.count) bytes):")
                print(jsonString)
            }
        }
        
        do {
            let pollResponse = try JSONDecoder().decode(PollLoginResponse.self, from: data)
            return pollResponse
        } catch {
            print("❌ JSON Decode Error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 Failed to decode JSON:")
                print(jsonString)
            }
            throw error
        }
    }

    
    private func getCurrentUser() async -> User? {
        return AuthService.shared.currentUser
    }
    
    // MARK: - API Request Helper
    private func performAPIRequest<T: Codable, U: Encodable>(
        endpoint: String,
        method: String,
        body: U?,
        requiresAuth: Bool = true
    ) async throws -> T {
        
        guard let url = URL(string: "\(authBaseURL)\(endpoint)") else {
            throw BiometricError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if required and available
        if requiresAuth {
            if let token = keychain.getAccessToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                print("🔑 Added auth token to request")
            } else {
                print("⚠️ No access token available for authenticated request")
            }
        } else {
            print("🌐 Making unauthenticated request to \(endpoint)")
        }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await NetworkService.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw BiometricError.networkError
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // Overload for requests without body
    private func performAPIRequest<T: Codable>(
        endpoint: String,
        method: String,
        requiresAuth: Bool = true
    ) async throws -> T {
        let nilBody: String? = nil
        return try await performAPIRequest(endpoint: endpoint, method: method, body: nilBody, requiresAuth: requiresAuth)
    }
    
    // MARK: - Re-enrollment
    func reEnrollBiometrics(reason: String) async throws {
        guard let userId = await getCurrentUserId() else {
            throw BiometricError.userNotFound
        }
        
        let reEnrollRequest = BiometricReEnrollRequest(
            userId: userId,
            reason: reason
        )
        
        let _: BiometricEnrollmentAPIResponse = try await performAPIRequest(
            endpoint: "/biometric/re-enroll",
            method: "POST",
            body: reEnrollRequest
        )
        
        // Clear old enrollment data
        keychain.setBiometricEnrolled(false)
        keychain.setBiometricEnrollmentId(nil)
        
        await MainActor.run {
            self.isEnrolled = false
            self.enrollmentProgress = 0.0
        }
    }
}

// MARK: - Data Models for AuthID Integration

struct BiometricEnrollmentRequest: Codable {
    let userId: String
    let userData: AuthIDUserData
}

struct AuthIDUserData: Codable {
    let name: String
    let email: String
    let department: String
    let role: String
    let accessLevel: String
}

struct AuthIDBiometricData: Codable {
    let biometric_template: String
    let verification_method: String
    let device_info: DeviceInfo
    let timestamp: Date
    let location_context: LocationContext
}

struct DeviceInfo: Codable {
    let device_id: String
    let platform: String
    let app_version: String
}

struct LocationContext: Codable {
    let access_point: String
    let building_id: String
}

struct AuthIDBiometricLoginRequest: Codable {
    let verificationData: AuthIDBiometricData
    let accessPoint: String
}

struct BiometricEnrollmentResult: Codable {
    let enrollmentId: String
    let enrollmentUrl: String
    let qrCode: String
    let expiresAt: String
}

struct BiometricEnrollmentAPIResponse: Codable {
    let message: String
    let enrollment: BiometricEnrollmentResponse
    let alreadyEnrolled: Bool?
}

// MARK: - Biometric Login Request/Response Models

struct InitiateLoginRequest: Codable {
    let email: String
}

struct InitiateLoginResponse: Codable {
    let operationId: String
    let authUrl: String  // Backend returns "authUrl", not "authIdUrl"
    
    // Map authUrl to authIdUrl for internal use
    var authIdUrl: String {
        return authUrl
    }
}

struct PollLoginResponse: Codable {
    let status: String // "pending", "completed", "failed"
    let user: User?
    let accessToken: String?
    let refreshToken: String?
    let message: String?  // Backend returns this
    let operationId: String?  // Backend returns this
    let expiresIn: Int?  // Backend returns this
    let tokenType: String?  // Backend returns this (e.g., "Bearer")
    let code: String?  // Backend returns this (e.g., "SESSION_EXPIRED")
    
    // Computed property to match the expected tokens structure
    var tokens: AuthTokens? {
        guard let accessToken = accessToken else { return nil }
        return AuthTokens(accessToken: accessToken, refreshToken: refreshToken)
    }
    
    enum CodingKeys: String, CodingKey {
        case status
        case user
        case accessToken
        case refreshToken
        case message
        case operationId
        case expiresIn
        case tokenType
        case code
    }
}

struct BiometricEnrollmentResponse: Codable {
    let enrollmentId: String
    let enrollmentUrl: String?
    let qrCode: String?
    let expiresAt: String?
    let status: String?
    let completedAt: String?
}

struct EnrollmentStatusResponse: Codable {
    let enrollment: EnrollmentStatus
    
    // Computed properties for convenience
    var status: String { enrollment.status }
    var progress: Int { enrollment.progress }
    var completed: Bool { enrollment.completed }
}

struct EnrollmentStatus: Codable {
    let enrollmentId: String
    let status: String
    let progress: Int
    let completed: Bool
    let createdAt: String?
    let expiresAt: String?
}

struct EnrollmentData: Codable {
    let verification_methods: [String]
    let quality_score: Int?
}

struct BiometricAuthResponse: Codable {
    let success: Bool
    let message: String
    let user: User?
    let verification: VerificationResult?
    let tokens: AuthTokens?
}

struct VerificationResult: Codable {
    let confidence: Double
    let verificationId: String
}

struct AuthTokens: Codable {
    let accessToken: String
    let refreshToken: String?
}

struct BiometricAuthResult {
    let success: Bool
    let user: User?
    let verification: VerificationResult?
    let tokens: AuthTokens?
}

struct BiometricReEnrollRequest: Codable {
    let userId: String
    let reason: String
}

// MARK: - Biometric Errors
enum BiometricError: LocalizedError {
    case biometricNotAvailable
    case authenticationFailed
    case userNotFound
    case invalidURL
    case networkError
    case enrollmentRequired
    case alreadyEnrolled
    
    var errorDescription: String? {
        switch self {
        case .biometricNotAvailable:
            return "Biometric authentication is not available on this device"
        case .authenticationFailed:
            return "Biometric authentication failed"
        case .userNotFound:
            return "User not found"
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network error occurred"
        case .enrollmentRequired:
            return "Biometric enrollment required"
        case .alreadyEnrolled:
            return "You are already enrolled in biometric authentication"
        }
    }
}

// MARK: - Keychain Extensions for Biometric Data
extension KeychainService {
    func setBiometricEnrolled(_ enrolled: Bool) {
        if enrolled {
            save("1", forKey: "biometric_enrolled")
        } else {
            save("0", forKey: "biometric_enrolled")
        }
    }
    
    func isBiometricEnrolled() -> Bool {
        return get(forKey: "biometric_enrolled") == "1"
    }
    
    func setBiometricEnrollmentId(_ enrollmentId: String?) {
        if let enrollmentId = enrollmentId {
            save(enrollmentId, forKey: "biometric_enrollment_id")
        } else {
            delete(forKey: "biometric_enrollment_id")
        }
    }
    
    func getBiometricEnrollmentId() -> String? {
        return get(forKey: "biometric_enrollment_id")
    }
}