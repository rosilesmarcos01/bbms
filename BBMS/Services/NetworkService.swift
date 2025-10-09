import Foundation

// MARK: - Network Service with Self-Signed Certificate Support
class NetworkService: NSObject {
    static let shared = NetworkService()
    
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    private override init() {
        super.init()
    }
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await session.data(for: request)
    }
}

// MARK: - URLSession Delegate for Self-Signed Certificates
extension NetworkService: URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // Only trust certificates from our development servers
        let allowedHosts = [
            "192.168.100.9",
            "localhost",
            "10.10.62.45"
        ]
        
        guard let serverTrust = challenge.protectionSpace.serverTrust,
              let host = challenge.protectionSpace.host as String?,
              allowedHosts.contains(host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Accept the self-signed certificate for development
        #if DEBUG
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
        #else
        // In production, use default handling
        completionHandler(.performDefaultHandling, nil)
        #endif
    }
}
