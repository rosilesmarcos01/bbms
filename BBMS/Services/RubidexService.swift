import Foundation

class RubidexService: ObservableObject {
    static let shared = RubidexService()
    
    private let baseURL = "https://app.rubidex.ai/api/v1/chaincode/document/all"
    private let collectionId = "fb9147b198b1f7ccc2c91cb8d9bc29bff48d3e34a908d72c95d387f8b8db8771"
    private let apiKey = "22d9eef8-9d41-4251-bcf0-3f09b4023085"
    
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
                    case .typeMismatch(let type, let context):
                        print("Type '\(type)' mismatch: \(context.debugDescription)")
                    case .valueNotFound(let value, let context):
                        print("Value '\(value)' not found: \(context.debugDescription)")
                    @unknown default:
                        print("Unknown decoding error")
                    }
                }
            }
            
            await MainActor.run {
                errorMessage = "Failed to decode response. Check console for details."
                isLoading = false
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
}