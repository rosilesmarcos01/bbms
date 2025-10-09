import Foundation

// MARK: - App Configuration
struct AppConfig {
    // MARK: - Network Configuration
    // This IP is automatically updated by running ./update-ip.sh in project root
    static let hostIP = "192.168.100.9"
    
    // MARK: - Service URLs
    static let authBaseURL = "https://\(hostIP):3001/api"
    static let backendBaseURL = "http://\(hostIP):3000/api"
    static let authIDWebURL = "https://\(hostIP):3002"
    
    // MARK: - Environment Detection
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - API Configuration
    static let requestTimeout: TimeInterval = 30
    static let maxRetryAttempts = 3
    
    // MARK: - Feature Flags
    static let enableBiometrics = true
    static let enableNotifications = true
    static let enableRubidexAlerts = true
    
    // MARK: - Helper Methods
    static func printConfiguration() {
        print("""
        
        ╔═══════════════════════════════════════╗
        ║     BBMS Configuration                ║
        ╠═══════════════════════════════════════╣
        ║ Host IP: \(hostIP)              ║
        ║ Auth URL: \(authBaseURL)
        ║ Backend URL: \(backendBaseURL)
        ║ AuthID Web: \(authIDWebURL)
        ║ Environment: \(isDebug ? "DEBUG" : "PRODUCTION")               ║
        ╚═══════════════════════════════════════╝
        
        """)
    }
}
