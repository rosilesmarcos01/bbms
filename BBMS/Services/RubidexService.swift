import Foundation

class RubidexService: ObservableObject {
    static let shared = RubidexService()
    
    // Backend API connection (unified endpoint for all data)
    // Local testing - your Mac's IP address
    private let backendURL = "http://10.10.62.45:3000/api"
    private let keychain = KeychainService.shared
    
    @Published var documents: [RubidexDocument] = []
    @Published var latestDocument: RubidexDocument?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Helper Methods
    private func addAuthHeaders(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let accessToken = keychain.getAccessToken() {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            print("Added authorization header with token")
        } else {
            print("No access token found in keychain")
        }
    }
    
    func fetchDocuments() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Use backend endpoint instead of direct Rubidex call
        let urlString = "\(backendURL)/documents/all"
        
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                errorMessage = "Invalid URL: \(urlString)"
                isLoading = false
            }
            return
        }
        
        print("Making GET request to backend: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeaders(to: &request)
        
        // Add timeout
        request.timeoutInterval = 30.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    errorMessage = "Invalid response"
                    isLoading = false
                }
                return
            }
            
            print("HTTP Status Code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 404 {
                await MainActor.run {
                    errorMessage = "Backend endpoint not found (404). Please check if the server is running."
                    isLoading = false
                }
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                // Log response body for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Error response body: \(responseString)")
                }
                
                await MainActor.run {
                    errorMessage = "Backend Error: \(httpResponse.statusCode)"
                    isLoading = false
                }
                return
            }
            
            // Try to decode the response
            let decoder = JSONDecoder()
            
            // Log the raw response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw Backend Response: \(jsonString.prefix(1000))")
            }
            
            // Decode as RubidexAPIResponse which contains result array
            do {
                let apiResponse = try decoder.decode(RubidexAPIResponse.self, from: data)
                print("✅ Successfully decoded backend response with \(apiResponse.result.count) documents")
                print("📄 Latest document ID: \(apiResponse.latestDocument?.id ?? "None")")
                print("🔄 Updating UI with new data...")
                
                await MainActor.run {
                    self.documents = apiResponse.result
                    self.latestDocument = apiResponse.latestDocument
                    self.isLoading = false
                    print("✅ UI updated successfully")
                }
                return
            } catch {
                print("❌ Failed to decode as API response: \(error)")
                print("🔍 Decoder error details: \(error.localizedDescription)")
                
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .dataCorrupted(let context):
                        print("Data corrupted: \(context)")
                    case .keyNotFound(let key, let context):
                        print("Key '\(key)' not found: \(context.debugDescription)")
                        print("Missing key path: \(context.codingPath)")
                    case .typeMismatch(let type, let context):
                        print("Type '\(type)' mismatch: \(context.debugDescription)")
                    case .valueNotFound(let value, let context):
                        print("Value '\(value)' not found: \(context.debugDescription)")
                    @unknown default:
                        print("Unknown decoding error")
                    }
                }
                
                // Try to parse individual documents and skip the problematic ones
                await tryPartialDecoding(from: data)
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Network error: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func refreshData() {
        Task {
            await fetchDocuments()
        }
    }
    
        // Test function to debug backend connectivity
    func testAPIConnection() async -> String {
        let urlString = "\(backendURL)/documents/test"
        
        guard let url = URL(string: urlString) else {
            return "❌ Invalid URL: \(urlString)"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeaders(to: &request)
        request.timeoutInterval = 15.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return "❌ Invalid HTTP response"
            }
            
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            let statusIcon = httpResponse.statusCode == 200 ? "✅" : "❌"
            
            return """
            \(statusIcon) Backend Test Results:
            
            📡 URL: \(urlString)
            📊 Status Code: \(httpResponse.statusCode)
            📝 Response Body: \(responseBody.prefix(1000))...
            
            Headers:
            \(httpResponse.allHeaderFields.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
            """
            
        } catch {
            return "❌ Network Error: \(error.localizedDescription)"
        }
    }
    
    // Try to parse individual documents and skip problematic ones
    private func tryPartialDecoding(from data: Data) async {
        print("🔧 Attempting partial decoding to recover valid documents...")
        
        do {
            // Parse as raw JSON first
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? [[String: Any]] {
                
                var validDocuments: [RubidexDocument] = []
                let decoder = JSONDecoder()
                
                for (index, documentDict) in result.enumerated() {
                    do {
                        let documentData = try JSONSerialization.data(withJSONObject: documentDict)
                        let document = try decoder.decode(RubidexDocument.self, from: documentData)
                        validDocuments.append(document)
                        print("✅ Successfully parsed document \(index + 1): \(document.id.prefix(16))...")
                    } catch {
                        print("⚠️ Skipping document \(index + 1) due to parsing error: \(error.localizedDescription)")
                        // Continue with next document
                    }
                }
                
                if !validDocuments.isEmpty {
                    // Process valid documents outside the concurrent context to avoid Swift 6 errors
                    let finalDocuments = validDocuments
                    let latestDoc = finalDocuments.max { first, second in
                        first.creationDate < second.creationDate
                    }
                    
                    await MainActor.run {
                        self.documents = finalDocuments
                        self.latestDocument = latestDoc
                        self.isLoading = false
                        self.errorMessage = finalDocuments.count < result.count ? 
                            "⚠️ Loaded \(finalDocuments.count)/\(result.count) documents (some had data issues)" : nil
                        print("✅ Partial decoding successful: \(finalDocuments.count) valid documents")
                    }
                    return
                }
            }
        } catch {
            print("❌ Partial decoding also failed: \(error.localizedDescription)")
        }
        
        await MainActor.run {
            self.errorMessage = "Failed to decode response. Database documents may have inconsistent structure."
            self.isLoading = false
        }
    }
    
    // MARK: - Backend API Methods
    
    // Test backend connection
    func testBackendConnection() async -> String {
        guard let url = URL(string: "\(backendURL)/temperature/test") else {
            return "❌ Invalid backend URL"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.timeoutInterval = 15.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return "❌ Invalid HTTP response"
            }
            
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            let statusIcon = httpResponse.statusCode == 200 ? "✅" : "❌"
            
            return """
            \(statusIcon) Backend Test Results:
            
            📡 URL: \(backendURL)
            📊 Status Code: \(httpResponse.statusCode)
            📝 Response: \(responseBody)
            🔗 Rubidex Integration: Connected
            """
            
        } catch {
            return "❌ Backend Connection Error: \(error.localizedDescription)"
        }
    }
    
    // Write temperature reading through backend
    func writeTemperatureReading(deviceId: String, temperature: Double, location: String, alertLimit: Double? = nil) async -> Bool {
        guard let url = URL(string: "\(backendURL)/temperature/reading") else {
            print("❌ Invalid backend URL")
            return false
        }
        
        let requestBody: [String: Any] = [
            "deviceId": deviceId,
            "temperature": temperature,
            "location": location,
            "alertLimit": alertLimit ?? 40.0,
            "deviceName": "iOS Temperature Sensor"
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.timeoutInterval = 30.0
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("✅ Temperature reading written to blockchain via backend")
                return true
            } else {
                print("❌ Failed to write temperature reading")
                return false
            }
        } catch {
            print("❌ Error writing temperature reading: \(error.localizedDescription)")
            return false
        }
    }
    
    // Get current temperature readings from backend
    func getCurrentTemperatures() async -> [BackendDevice] {
        guard let url = URL(string: "\(backendURL)/temperature/current") else {
            print("❌ Invalid backend URL for current temperatures")
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeaders(to: &request)
        request.timeoutInterval = 30.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("❌ Failed to get current temperatures")
                return []
            }
            
            let temperatures = try JSONDecoder().decode([BackendDevice].self, from: data)
            print("✅ Retrieved \(temperatures.count) current temperature readings from backend")
            return temperatures
            
        } catch {
            print("❌ Error getting current temperatures: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Temperature Alert Documentation
    
    // Write temperature alert document via backend
    func writeTemperatureAlertDocument(
        deviceId: String,
        deviceName: String,
        currentTemp: Double,
        limit: Double,
        location: String,
        severity: String
    ) async -> Bool {
        
        // Use backend endpoint instead of calling Rubidex directly
        let urlString = "\(backendURL)/documents/temperature-alert"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid backend URL")
            return false
        }
        
        // Create the request body for the backend
        let requestBody: [String: Any] = [
            "deviceId": deviceId,
            "deviceName": deviceName,
            "currentTemp": currentTemp,
            "limit": limit,
            "location": location,
            "severity": severity
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.timeoutInterval = 30.0
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            print("🚨 Writing temperature alert document via backend...")
            print("   Device: \(deviceName) (\(deviceId))")
            print("   Location: \(location)")
            print("   Temperature: \(String(format: "%.1f", currentTemp))°C")
            print("   Limit: \(String(format: "%.1f", limit))°C")
            print("   Severity: \(severity)")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Backend API response status: \(httpResponse.statusCode)")
                
                if let responseData = String(data: data, encoding: .utf8) {
                    print("📝 Backend API response: \(responseData)")
                }
                
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    print("✅ Temperature alert document successfully written via backend to Rubidex blockchain")
                    return true
                } else {
                    print("❌ Failed to write temperature alert document via backend. Status: \(httpResponse.statusCode)")
                    return false
                }
            } else {
                print("❌ Invalid HTTP response from backend API")
                return false
            }
            
        } catch {
            print("❌ Error writing temperature alert document via backend: \(error.localizedDescription)")
            return false
        }
    }
    
    // Update temperature alert document to mark as resolved via backend
    func updateTemperatureAlertResolved(
        deviceId: String,
        deviceName: String,
        resolvedAt: Date = Date()
    ) async -> Bool {
        
        // Use backend endpoint instead of calling Rubidex directly
        let urlString = "\(backendURL)/documents/temperature-alert-resolved"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid backend URL")
            return false
        }
        
        // Create the request body for the backend
        let requestBody: [String: Any] = [
            "deviceId": deviceId,
            "deviceName": deviceName
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        request.timeoutInterval = 30.0
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            print("✅ Writing temperature alert resolution document via backend...")
            print("   Device: \(deviceName) (\(deviceId))")
            print("   Resolved at: \(resolvedAt)")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Backend API response status: \(httpResponse.statusCode)")
                
                if let responseData = String(data: data, encoding: .utf8) {
                    print("📝 Backend API response: \(responseData)")
                }
                
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    print("✅ Temperature alert resolution document successfully written via backend to Rubidex blockchain")
                    return true
                } else {
                    print("❌ Failed to write temperature alert resolution document via backend. Status: \(httpResponse.statusCode)")
                    return false
                }
            } else {
                print("❌ Invalid HTTP response from backend API")
                return false
            }
            
        } catch {
            print("❌ Error writing temperature alert resolution document via backend: \(error.localizedDescription)")
            return false
        }
    }
}

// Backend device model for decoding API responses
struct BackendDevice: Codable {
    let id: String
    let name: String
    let type: String
    let location: String
    let status: String
    let value: Double
    let unit: String
    let lastUpdated: String
}