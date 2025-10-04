import Foundation

class RubidexService: ObservableObject {
    static let shared = RubidexService()
    
    // Direct Rubidex connection (for reading)
    private let baseURL = "https://app.rubidex.ai/api/v1/chaincode/document/all"
    private let collectionId = "fb9147b198b1f7ccc2c91cb8d9bc29bff48d3e34a908d72c95d387f8b8db8771"
    private let apiKey = "22d9eef8-9d41-4251-bcf0-3f09b4023085"
    
    // Backend API connection (for writing and real-time updates)
    // TODO: Replace with your Railway deployment URL
    private let backendURL = "http://localhost:3000/api" // Change this after Railway deployment
    
    @Published var documents: [RubidexDocument] = []
    @Published var latestDocument: RubidexDocument?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchDocuments() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Use GET method with query parameter as confirmed by testing
        let urlString = "https://app.rubidex.ai/api/v1/chaincode/document/all?collection-id=\(collectionId)"
        
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                errorMessage = "Invalid URL: \(urlString)"
                isLoading = false
            }
            return
        }
        
        print("Making GET request to: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"  // Changed to GET
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        
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
                    errorMessage = "API endpoint not found (404). Please verify the URL and collection ID."
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
                    errorMessage = "HTTP Error: \(httpResponse.statusCode)"
                    isLoading = false
                }
                return
            }
            
            // Try to decode the response
            let decoder = JSONDecoder()
            
            // Log the raw response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw API Response: \(jsonString.prefix(1000))")
            }
            
            // Decode as RubidexAPIResponse which contains result array
            do {
                let apiResponse = try decoder.decode(RubidexAPIResponse.self, from: data)
                print("✅ Successfully decoded API response with \(apiResponse.result.count) documents")
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
    
        // Test function to debug API connectivity
    func testAPIConnection() async -> String {
        let urlString = "https://app.rubidex.ai/api/v1/chaincode/document/all?collection-id=\(collectionId)"
        
        guard let url = URL(string: urlString) else {
            return "❌ Invalid URL: \(urlString)"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"  // Changed to GET
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return "❌ Invalid HTTP response"
            }
            
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            let statusIcon = httpResponse.statusCode == 200 ? "✅" : "❌"
            
            return """
            \(statusIcon) API Test Results:
            
            📡 URL: \(urlString)
            🔐 Auth Header: Key \(String(apiKey.prefix(8)))...
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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