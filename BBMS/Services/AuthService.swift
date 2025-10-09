import Foundation
import SwiftUI
import LocalAuthentication

// MARK: - Authentication Service
@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Configuration
    // Configuration is managed in Config/AppConfig.swift
    // Update IP by running ./update-ip.sh and rebuilding the app
    private let authBaseURL = AppConfig.authBaseURL
    private let keychain = KeychainService.shared
    
    // Rate limiting to prevent too many auth requests
    private var lastProfileCheck: Date = .distantPast
    private var lastTokenValidation: Date = .distantPast
    private let minRequestInterval: TimeInterval = 60 // Minimum 60 seconds between profile/token checks
    
    static let shared = AuthService()
    
    private init() {
        checkAuthenticationStatus()
    }
    
    // MARK: - Authentication Status
    func checkAuthenticationStatus() {
        if let token = keychain.getAccessToken() {
            Task {
                await validateToken(token)
            }
        }
    }
    
    // MARK: - Registration
    func register(name: String, email: String, password: String, department: String, role: String = "user") async {
        isLoading = true
        errorMessage = nil
        
        do {
            let registrationData = RegistrationRequest(
                name: name,
                email: email,
                password: password,
                department: department,
                role: role,
                accessLevel: "basic"
            )
            
            let response = try await performRequest(
                endpoint: "/auth/register",
                method: "POST",
                body: registrationData
            ) as AuthResponse
            
            await handleAuthSuccess(response)
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Email/Password Login
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        print("🔐 AuthService: Starting login for email: \(email)")
        print("🌐 AuthService: Using base URL: \(authBaseURL)")
        
        do {
            let loginData = LoginRequest(email: email, password: password)
            
            print("📤 AuthService: Sending login request...")
            let response = try await performRequest(
                endpoint: "/auth/login",
                method: "POST",
                body: loginData
            ) as AuthResponse
            
            print("✅ AuthService: Login successful")
            await handleAuthSuccess(response)
            
        } catch {
            print("❌ AuthService: Login failed with error: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Biometric Authentication (Updated for AuthID Integration)
    func biometricLogin() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Check if user is enrolled in AuthID biometrics
            let biometricService = BiometricAuthService.shared
            
            if !biometricService.isEnrolled {
                throw AuthError.biometricNotEnrolled
            }
            
            // Use the new BiometricAuthService for AuthID integration
            let result = try await biometricService.authenticateWithBiometrics()
            
            if result.success, let user = result.user, let tokens = result.tokens {
                // Store tokens and update authentication state
                keychain.saveAccessToken(tokens.accessToken)
                if let refreshToken = tokens.refreshToken, !refreshToken.isEmpty {
                    keychain.saveRefreshToken(refreshToken)
                }
                
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                }
                
                print("✅ Biometric authentication successful via AuthID")
            } else {
                throw AuthError.biometricAuthenticationFailed
            }
            
        } catch {
            if let biometricError = error as? BiometricError {
                switch biometricError {
                case .biometricNotAvailable:
                    errorMessage = "Biometric authentication not available"
                case .authenticationFailed:
                    errorMessage = "Biometric authentication failed"
                case .enrollmentRequired:
                    errorMessage = "Please complete biometric enrollment first"
                default:
                    errorMessage = biometricError.localizedDescription
                }
            } else if let laError = error as? LAError {
                switch laError.code {
                case .userCancel, .userFallback:
                    errorMessage = "Biometric authentication cancelled"
                case .biometryNotAvailable:
                    errorMessage = "Biometric authentication not available"
                case .biometryNotEnrolled:
                    errorMessage = "No biometric data enrolled on device"
                default:
                    errorMessage = "Biometric authentication failed"
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Logout
    func logout() async {
        isLoading = true
        
        do {
            // Call logout endpoint
            try await performRequestVoid(
                endpoint: "/auth/logout",
                method: "POST",
                requiresAuth: true
            )
        } catch {
            print("Logout API call failed: \(error)")
        }
        
        // Clear local authentication state
        await handleLogout()
        isLoading = false
    }
    
    // MARK: - Profile Management
    func getCurrentProfile() async {
        guard isAuthenticated else { return }
        
        // Rate limiting: don't check profile more than once per minute
        let now = Date()
        if now.timeIntervalSince(lastProfileCheck) < minRequestInterval {
            print("🛡️ AuthService: Skipping profile check due to rate limiting")
            return
        }
        lastProfileCheck = now
        
        do {
            let response = try await performRequest(
                endpoint: "/auth/me",
                method: "GET",
                requiresAuth: true
            ) as ProfileResponse
            
            currentUser = response.user
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateProfile(name: String, department: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let updateData = ProfileUpdateRequest(
                name: name,
                department: department
            )
            
            let response = try await performRequest(
                endpoint: "/users/profile",
                method: "PUT",
                body: updateData,
                requiresAuth: true
            ) as ProfileUpdateResponse
            
            currentUser = response.user
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Biometric Enrollment
    func initiateBiometricEnrollment() async -> AuthServiceBiometricEnrollmentResponse? {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await performRequest(
                endpoint: "/biometric/enroll",
                method: "POST",
                requiresAuth: true
            ) as AuthServiceBiometricEnrollmentAPIResponse
            
            isLoading = false
            return response.enrollment
            
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }
    
    func getBiometricEnrollmentStatus() async -> BiometricEnrollmentStatus? {
        do {
            let response = try await performRequest(
                endpoint: "/biometric/enrollment/status",
                method: "GET",
                requiresAuth: true
            ) as BiometricEnrollmentStatusResponse
            
            return response.enrollment
            
        } catch {
            print("Failed to get biometric enrollment status: \(error)")
            return nil
        }
    }
    
    // Check if biometric enrollment is complete
    func checkBiometricEnrollmentStatus() async throws -> (isEnrolled: Bool, status: String?) {
        let enrollmentStatus = await getBiometricEnrollmentStatus()
        
        if let status = enrollmentStatus {
            return (isEnrolled: status.status == "completed", status: status.status)
        }
        
        return (isEnrolled: false, status: nil)
    }
    
    // MARK: - Building Access
    func checkZoneAccess(zoneId: String) async -> ZoneAccessPermission? {
        do {
            let response = try await performRequest(
                endpoint: "/building-access/permissions/\(zoneId)",
                method: "GET",
                requiresAuth: true
            ) as ZoneAccessPermission
            
            return response
            
        } catch {
            print("Failed to check zone access: \(error)")
            return nil
        }
    }
    
    func logBuildingAccess(zoneId: String, accessType: String, method: String = "mobile_app") async {
        do {
            let accessData = BuildingAccessLog(
                zoneId: zoneId,
                accessType: accessType,
                method: method
            )
            
            try await performRequestVoid(
                endpoint: "/building-access/log",
                method: "POST",
                body: accessData,
                requiresAuth: true
            )
            
        } catch {
            print("Failed to log building access: \(error)")
        }
    }
    
    // MARK: - Private Helper Methods
    private func handleAuthSuccess(_ response: AuthResponse) async {
        currentUser = response.user
        isAuthenticated = true
        
        // Store tokens securely
        keychain.saveAccessToken(response.accessToken)
        
        // Update user service with authenticated user
        UserService.shared.setAuthenticatedUser(response.user)
    }
    
    private func handleLogout() async {
        currentUser = nil
        isAuthenticated = false
        keychain.clearAllTokens()
        
        // Clear user service
        UserService.shared.clearUser()
    }
    
    private func validateToken(_ token: String) async {
        // Rate limiting: don't validate token more than once per minute
        let now = Date()
        if now.timeIntervalSince(lastTokenValidation) < minRequestInterval {
            print("🛡️ AuthService: Skipping token validation due to rate limiting")
            isAuthenticated = true // Assume valid if recently checked
            return
        }
        lastTokenValidation = now
        
        do {
            let response = try await performAuthenticatedRequest(
                endpoint: "/auth/me",
                method: "GET",
                token: token
            ) as ProfileResponse
            
            currentUser = response.user
            isAuthenticated = true
            
        } catch {
            // Token is invalid, clear it
            keychain.clearAllTokens()
            isAuthenticated = false
        }
    }
    
    private func getBiometricType(context: LAContext) -> String {
        switch context.biometryType {
        case .faceID:
            return "face"
        case .touchID:
            return "fingerprint"
        default:
            return "biometric"
        }
    }
    
    // MARK: - Network Requests
    private func performRequest<T: Codable>(
        endpoint: String,
        method: String,
        body: Codable? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        
        let token = requiresAuth ? keychain.getAccessToken() : nil
        return try await performAuthenticatedRequest(
            endpoint: endpoint,
            method: method,
            body: body,
            token: token
        )
    }
    
    // Non-generic version for when we don't need the response
    private func performRequestVoid(
        endpoint: String,
        method: String,
        body: Codable? = nil,
        requiresAuth: Bool = false
    ) async throws {
        
        let token = requiresAuth ? keychain.getAccessToken() : nil
        let _: EmptyResponse = try await performAuthenticatedRequest(
            endpoint: endpoint,
            method: method,
            body: body,
            token: token
        )
    }
    
    private func performAuthenticatedRequest<T: Codable>(
        endpoint: String,
        method: String,
        body: Codable? = nil,
        token: String? = nil
    ) async throws -> T {
        
        let fullURL = "\(authBaseURL)\(endpoint)"
        print("🌐 AuthService: Making request to: \(fullURL)")
        
        guard let url = URL(string: fullURL) else {
            print("❌ AuthService: Invalid URL: \(fullURL)")
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
            print("📤 AuthService: Request body set")
        }
        
        print("🚀 AuthService: Sending \(method) request...")
        let (data, response) = try await NetworkService.shared.data(for: request)
        
        print("📨 AuthService: Received response")
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ AuthService: Invalid HTTP response")
            throw AuthError.networkError
        }
        
        print("📊 AuthService: HTTP Status Code: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 401 {
            // Token expired, try to refresh
            if let refreshedToken = await refreshToken() {
                // Retry with new token
                var retryRequest = request
                retryRequest.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")
                
                let (retryData, retryResponse) = try await NetworkService.shared.data(for: retryRequest)
                guard let retryHttpResponse = retryResponse as? HTTPURLResponse,
                      retryHttpResponse.statusCode < 400 else {
                    throw AuthError.unauthorized
                }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: retryData)
            } else {
                await handleLogout()
                throw AuthError.unauthorized
            }
        }
        
        guard httpResponse.statusCode < 400 else {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let errorData = try? decoder.decode(ErrorResponse.self, from: data) {
                throw AuthError.serverError(errorData.error)
            }
            throw AuthError.serverError("Request failed with status \(httpResponse.statusCode)")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
    
    private func refreshToken() async -> String? {
        do {
            let response = try await performAuthenticatedRequest(
                endpoint: "/auth/refresh",
                method: "POST"
            ) as RefreshTokenResponse
            
            keychain.saveAccessToken(response.accessToken)
            return response.accessToken
            
        } catch {
            return nil
        }
    }
}

// MARK: - Data Models
struct RegistrationRequest: Codable {
    let name: String
    let email: String
    let password: String
    let department: String
    let role: String
    let accessLevel: String
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct BiometricLoginRequest: Codable {
    let verificationData: BiometricVerificationData
    let accessPoint: String
}

struct BiometricVerificationData: Codable {
    let timestamp: Date
    let deviceId: String
    let biometricType: String
}

struct ProfileUpdateRequest: Codable {
    let name: String
    let department: String
}

struct BuildingAccessLog: Codable {
    let zoneId: String
    let accessType: String
    let method: String
}

struct AuthResponse: Codable {
    let message: String
    let user: User
    let accessToken: String
    let refreshToken: String?
    let biometricEnrollment: AuthServiceBiometricEnrollmentResponse?
}

struct ProfileResponse: Codable {
    let user: User
}

struct ProfileUpdateResponse: Codable {
    let message: String
    let user: User
}

struct RefreshTokenResponse: Codable {
    let message: String
    let accessToken: String
}

struct AuthServiceBiometricEnrollmentAPIResponse: Codable {
    let message: String
    let enrollment: AuthServiceBiometricEnrollmentResponse
    let alreadyEnrolled: Bool?
}

struct AuthServiceBiometricEnrollmentResponse: Codable {
    let enrollmentId: String
    let enrollmentUrl: String?
    let qrCode: String?
    let expiresAt: String?
    let status: String?
    let completedAt: String?
}

struct BiometricEnrollmentStatusResponse: Codable {
    let enrollment: BiometricEnrollmentStatus
}

struct BiometricEnrollmentStatus: Codable {
    let enrollmentId: String
    let status: String
    let progress: Int
    let completed: Bool
    let createdAt: String
    let expiresAt: String
}

struct ZoneAccessPermission: Codable {
    let zoneId: String
    let zoneName: String
    let hasAccess: Bool
    let requiresBiometric: Bool
    let userAccessLevel: String
    let userRole: String
    let accessReason: String
}

struct ErrorResponse: Codable {
    let error: String
    let code: String
}

// MARK: - Auth Errors
enum AuthError: Error, LocalizedError {
    case invalidURL
    case networkError
    case unauthorized
    case biometricNotAvailable
    case biometricNotEnrolled
    case biometricAuthenticationFailed
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network error occurred"
        case .unauthorized:
            return "Authentication failed"
        case .biometricNotAvailable:
            return "Biometric authentication not available"
        case .biometricNotEnrolled:
            return "Biometric enrollment required"
        case .biometricAuthenticationFailed:
            return "Biometric authentication failed"
        case .serverError(let message):
            return message
        }
    }
}

// MARK: - Empty Response for void requests
private struct EmptyResponse: Codable {
    // Empty struct for requests that don't return data
}
