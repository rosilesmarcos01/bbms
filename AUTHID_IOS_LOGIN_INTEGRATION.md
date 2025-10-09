# iOS App - Biometric Login Integration Guide

## Overview

This guide shows how to integrate AuthID biometric login into your BBMS iOS app using the new backend endpoints and web component.

---

## Architecture Flow

```
┌─────────────┐
│  iOS App    │
│  Login      │
│  Screen     │
└──────┬──────┘
       │
       │ 1. POST /api/biometric/login/initiate
       │    { email: "user@example.com" }
       ▼
┌──────────────┐
│   Backend    │
│   Creates    │
│   Operation  │
└──────┬───────┘
       │
       │ 2. Returns verificationUrl
       ▼
┌──────────────┐
│   WKWebView  │
│   Opens URL  │
│   (Safari)   │
└──────┬───────┘
       │
       │ 3. User takes selfie
       │    AuthID verifies face
       ▼
┌──────────────┐
│   Callback   │
│   bbms://    │
│   login?     │
│   token=xxx  │
└──────┬───────┘
       │
       │ 4. Store token, navigate to main app
       ▼
┌──────────────┐
│  Main App    │
│  Screen      │
└──────────────┘
```

---

## Step 1: Add URL Scheme to Info.plist

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>bbms</string>
        </array>
        <key>CFBundleURLName</key>
        <string>ai.bbms.app</string>
    </dict>
</array>
```

---

## Step 2: Create Login Service

Create `BiometricLoginService.swift`:

```swift
import Foundation

class BiometricLoginService {
    private let authServiceURL = "https://192.168.100.9:3001/api"
    
    struct LoginInitResponse: Codable {
        let success: Bool
        let userId: String
        let operationId: String
        let verificationUrl: String
        let qrCode: String
        let expiresAt: String
    }
    
    struct LoginCompleteResponse: Codable {
        let success: Bool
        let status: String
        let token: String
        let refreshToken: String
        let user: UserInfo
        
        struct UserInfo: Codable {
            let id: String
            let email: String
            let name: String
            let role: String
            let department: String?
            let biometricEnabled: Bool
        }
    }
    
    /// Initiate biometric login
    func initiateLogin(email: String, completion: @escaping (Result<LoginInitResponse, Error>) -> Void) {
        guard let url = URL(string: "\(authServiceURL)/biometric/login/initiate") else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email]
        request.httpBody = try? JSONEncoder().encode(body)
        
        print("🔐 Initiating biometric login for: \(email)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Login initiation failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: 0)))
                return
            }
            
            // Debug: Print raw response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📨 Response: \(jsonString)")
            }
            
            do {
                let result = try JSONDecoder().decode(LoginInitResponse.self, from: data)
                print("✅ Login initiated successfully")
                print("📋 Operation ID: \(result.operationId)")
                print("🔗 Verification URL: \(result.verificationUrl)")
                completion(.success(result))
            } catch {
                print("❌ Failed to decode response: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
}
```

---

## Step 3: Create Biometric Login View

Create `BiometricLoginView.swift`:

```swift
import SwiftUI
import WebKit

struct BiometricLoginView: View {
    @State private var email: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showWebView: Bool = false
    @State private var verificationURL: String?
    
    private let loginService = BiometricLoginService()
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "667eea"), Color(hex: "764ba2")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if showWebView, let urlString = verificationURL {
                // Show web view for biometric verification
                BiometricWebView(urlString: urlString, onComplete: handleLoginComplete)
                    .ignoresSafeArea()
            } else {
                // Show login form
                VStack(spacing: 24) {
                    Spacer()
                    
                    // Logo or icon
                    Image(systemName: "faceid")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .padding(.bottom, 8)
                    
                    Text("Biometric Login")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Secure face verification")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                    
                    // Email input
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                        
                        Button(action: startLogin) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "faceid")
                                    Text("Login with Face ID")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                        }
                        .disabled(isLoading || email.isEmpty)
                    }
                    .padding(.horizontal, 32)
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(8)
                            .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                    
                    Button("Use Password Instead") {
                        // Navigate to password login
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, 32)
                }
            }
        }
    }
    
    private func startLogin() {
        isLoading = true
        errorMessage = nil
        
        print("🚀 Starting biometric login for: \(email)")
        
        loginService.initiateLogin(email: email) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let response):
                    print("✅ Login initiated, opening web view")
                    verificationURL = response.verificationUrl
                    showWebView = true
                    
                case .failure(let error):
                    print("❌ Login failed: \(error.localizedDescription)")
                    errorMessage = "Login failed. Please check your email and try again."
                }
            }
        }
    }
    
    private func handleLoginComplete(token: String, user: BiometricLoginService.LoginCompleteResponse.UserInfo) {
        print("✅ Login completed successfully!")
        print("🔑 Token: \(token.prefix(20))...")
        print("👤 User: \(user.name) (\(user.email))")
        
        // Store token
        UserDefaults.standard.set(token, forKey: "authToken")
        UserDefaults.standard.set(user.id, forKey: "userId")
        UserDefaults.standard.set(user.email, forKey: "userEmail")
        UserDefaults.standard.set(user.name, forKey: "userName")
        
        // Navigate to main app
        // TODO: Update app state or use NavigationLink
        showWebView = false
    }
}

// Helper for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

---

## Step 4: Create WebView with URL Scheme Handling

Create `BiometricWebView.swift`:

```swift
import SwiftUI
import WebKit

struct BiometricWebView: UIViewRepresentable {
    let urlString: String
    let onComplete: (String, BiometricLoginService.LoginCompleteResponse.UserInfo) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // Enable JavaScript
        configuration.preferences.javaScriptEnabled = true
        
        // Add message handler for JavaScript bridge (fallback)
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "loginSuccess")
        configuration.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Load verification URL
        if let url = URL(string: urlString) {
            print("📱 Loading verification URL: \(url)")
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // No updates needed
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: BiometricWebView
        
        init(parent: BiometricWebView) {
            self.parent = parent
        }
        
        // Handle URL scheme navigation (bbms://login?token=xxx)
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            
            if let url = navigationAction.request.url {
                print("🔗 Navigation to: \(url)")
                
                // Check for bbms:// URL scheme
                if url.scheme == "bbms", url.host == "login" {
                    print("✅ Detected login callback URL")
                    
                    // Parse query parameters
                    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                       let queryItems = components.queryItems {
                        
                        if let token = queryItems.first(where: { $0.name == "token" })?.value {
                            print("🔑 Received token from URL scheme")
                            
                            // Parse user data (if provided)
                            // For now, we'll call the backend to get user info
                            // Or you can pass it in the URL
                            
                            // Dummy user data (replace with actual parsing)
                            let user = BiometricLoginService.LoginCompleteResponse.UserInfo(
                                id: "temp",
                                email: "temp@example.com",
                                name: "User",
                                role: "user",
                                department: nil,
                                biometricEnabled: true
                            )
                            
                            parent.onComplete(token, user)
                            
                            decisionHandler(.cancel)
                            return
                        }
                    }
                }
            }
            
            decisionHandler(.allow)
        }
        
        // Handle JavaScript message (fallback method)
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "loginSuccess" {
                print("📨 Received message from JavaScript")
                
                if let body = message.body as? [String: Any],
                   let token = body["token"] as? String,
                   let userData = body["user"] as? [String: Any] {
                    
                    print("🔑 Token received via JavaScript bridge")
                    
                    // Parse user data
                    let user = BiometricLoginService.LoginCompleteResponse.UserInfo(
                        id: userData["id"] as? String ?? "",
                        email: userData["email"] as? String ?? "",
                        name: userData["name"] as? String ?? "",
                        role: userData["role"] as? String ?? "user",
                        department: userData["department"] as? String,
                        biometricEnabled: userData["biometricEnabled"] as? Bool ?? true
                    )
                    
                    parent.onComplete(token, user)
                }
            }
        }
    }
}
```

---

## Step 5: Update App Delegate for URL Scheme

In `BBMSApp.swift` or `AppDelegate.swift`:

```swift
import SwiftUI

@main
struct BBMSApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("📱 App opened with URL: \(url)")
        
        // Handle bbms://login?token=xxx
        if url.scheme == "bbms", url.host == "login" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let token = components.queryItems?.first(where: { $0.name == "token" })?.value {
                
                print("✅ Login token received: \(token.prefix(20))...")
                
                // Store token
                UserDefaults.standard.set(token, forKey: "authToken")
                
                // Update app state
                appState.isAuthenticated = true
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    
    init() {
        // Check if user is already logged in
        isAuthenticated = UserDefaults.standard.string(forKey: "authToken") != nil
    }
}
```

---

## Step 6: Update Main ContentView

```swift
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainAppView()
            } else {
                BiometricLoginView()
            }
        }
    }
}
```

---

## Testing Checklist

### ✅ Setup
1. Add URL scheme to Info.plist
2. Copy all Swift files to project
3. Update backend URL in BiometricLoginService
4. Ensure auth server is running on https://192.168.100.9:3001

### ✅ Test Flow
1. Open app → See login screen
2. Enter email → Tap "Login with Face ID"
3. WebView opens → AuthID component loads
4. Take selfie → Face verification
5. Success → Redirected back to app with token
6. App stores token and navigates to main screen

### ✅ Error Scenarios
- Invalid email → Show error message
- Biometric not enrolled → Show "Please enroll" message
- Face doesn't match → Show "Verification failed"
- Timeout → Show "Try again" message

---

## Security Considerations

### ✅ Token Storage
```swift
// Use Keychain for production (not UserDefaults)
import Security

class KeychainHelper {
    static func save(token: String) {
        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "authToken",
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "authToken",
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        if let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
```

### ✅ SSL Pinning (Production)
```swift
class PinnedSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Implement certificate pinning
        // Compare challenge.protectionSpace.serverTrust with your certificate
    }
}
```

---

## Next Steps

1. **Implement in iOS app** - Copy the Swift code above
2. **Test enrollment first** - Make sure users can enroll before trying login
3. **Test login flow** - Follow the testing checklist
4. **Add error handling** - Handle network errors, timeouts, etc.
5. **Add loading states** - Show spinners during API calls
6. **Implement logout** - Clear tokens and redirect to login

---

## Troubleshooting

### Issue: WebView doesn't redirect back to app
**Solution**: Check that URL scheme is registered in Info.plist and matches exactly

### Issue: Token not received
**Solution**: Check browser console logs in Safari, verify backend is returning token

### Issue: "User not found" error
**Solution**: Ensure user has completed biometric enrollment first

### Issue: Certificate errors
**Solution**: Visit https://192.168.100.9:3001 in Safari and accept certificate

---

## Production Checklist

- [ ] Replace UserDefaults with Keychain for token storage
- [ ] Add SSL certificate pinning
- [ ] Remove debug print statements
- [ ] Add analytics/logging
- [ ] Add biometric fallback to password
- [ ] Add session refresh logic
- [ ] Test on multiple devices
- [ ] Test network error scenarios
- [ ] Add rate limiting feedback
- [ ] Add "Remember me" feature

