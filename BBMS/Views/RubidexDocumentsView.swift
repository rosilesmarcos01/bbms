import SwiftUI

struct RubidexDocumentsView: View {
    @ObservedObject private var rubidexService = RubidexService.shared
    @State private var showingAllDocuments = false
    @State private var isRefreshing = false
    @State private var lastRefreshTime = Date()
    
    // Pull-to-refresh function
    @MainActor
    private func refreshAllData() async {
        isRefreshing = true
        lastRefreshTime = Date()
        
        print("🔄 Pull-to-refresh triggered in RubidexDocumentsView")
        
        // Refresh Rubidex data
        rubidexService.refreshData()
        
        // Add a small delay to ensure the refresh completes
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        isRefreshing = false
        print("✅ Pull-to-refresh completed in RubidexDocumentsView")
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "cube.box")
                            .foregroundColor(Color("BBMSGold"))
                            .font(.title2)
                        
                        Text("Rubidex Blockchain Data")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color("BBMSBlack"))
                        
                        // Subtle loading indicator during refresh
                        if rubidexService.isLoading || isRefreshing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color("BBMSGold")))
                                .scaleEffect(0.6)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            Task {
                                await refreshAllData()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(Color("BBMSBlue"))
                                .font(.title3)
                        }
                        .disabled(rubidexService.isLoading)
                        
                        // Add API test button for debugging
                        Button(action: {
                            Task {
                                let result = await rubidexService.testAPIConnection()
                                print("API Test Result: \(result)")
                            }
                        }) {
                            Image(systemName: "network")
                                .foregroundColor(Color("BBMSGold"))
                                .font(.title3)
                        }
                        .disabled(rubidexService.isLoading)
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.seal")
                            .foregroundColor(Color("BBMSGreen"))
                            .font(.caption)
                        
                        Text("Blockchain Verified")
                            .font(.caption)
                            .foregroundColor(Color("BBMSGreen"))
                        
                        // Show last refresh time if recently refreshed
                        if Date().timeIntervalSince(lastRefreshTime) < 10 {
                            Text("• Updated")
                                .font(.caption2)
                                .foregroundColor(Color("BBMSGold"))
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color("BBMSWhite"))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                if rubidexService.isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color("BBMSGold")))
                        Text("Loading blockchain data...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = rubidexService.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.title)
                        Text("Error loading data")
                            .font(.headline)
                            .foregroundColor(Color("BBMSBlack"))
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            rubidexService.refreshData()
                        }
                        .padding()
                        .background(Color("BBMSBlue"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Latest Document Card
                            if let latestDocument = rubidexService.latestDocument {
                                VStack(spacing: 16) {
                                    HStack {
                                        Text("Latest Document")
                                            .font(.headline)
                                            .foregroundColor(Color("BBMSBlack"))
                                        
                                        Spacer()
                                        
                                        Text("LATEST")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color("BBMSGreen"))
                                            .cornerRadius(4)
                                    }
                                    
                                    Divider()
                                        .background(Color("BBMSGold"))
                                    
                                    DocumentDetailView(document: latestDocument)
                                }
                                .padding()
                                .background(Color("BBMSWhite"))
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            }
                            
                            // View Previous Documents Button
                            if rubidexService.documents.count > 1 {
                                Button(action: {
                                    showingAllDocuments = true
                                }) {
                                    HStack {
                                        Text("View Previous Documents")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        Text("(\(rubidexService.documents.count - 1))")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                    }
                                    .foregroundColor(Color("BBMSBlue"))
                                    .padding()
                                    .background(Color("BBMSBlue").opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await refreshAllData()
                    }
                }
                
                Spacer()
            }
            .background(.gray.opacity(0.05))
            .navigationTitle("Blockchain Data")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if rubidexService.documents.isEmpty {
                    rubidexService.refreshData()
                }
            }
            .sheet(isPresented: $showingAllDocuments) {
                AllDocumentsView(documents: rubidexService.documents)
            }
        }
    }
}

struct DocumentDetailView: View {
    let document: RubidexDocument
    
    // Parse blockchain data to extract temperature and battery values
    private func parseBlockchainData(_ data: String) -> (temperature: String?, battery: String?) {
        // Try to parse JSON format first
        if let jsonData = data.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            
            var temperature: String?
            var battery: String?
            
            // Extract temperature
            if let temp = json["temp"] as? String {
                let tempInfo = parseTemperatureString(temp)
                if !tempInfo.unit.isEmpty {
                    temperature = "\(tempInfo.value) ºC"
                }
            } else if let temp = json["temperature"] as? String {
                let tempInfo = parseTemperatureString(temp)
                if !tempInfo.unit.isEmpty {
                    temperature = "\(tempInfo.value) ºC"
                }
            } else if let temp = json["temp"] as? Double {
                temperature = "\(String(format: "%.1f", temp)) ºC"
            } else if let temp = json["temperature"] as? Double {
                temperature = "\(String(format: "%.1f", temp)) ºC"
            }
            
            // Extract battery
            if let batt = json["battery"] as? String {
                if let battValue = Double(batt.replacingOccurrences(of: "V", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) {
                    battery = "\(String(format: "%.1f", battValue)) V"
                } else {
                    battery = batt.contains("V") ? batt : "\(batt) V"
                }
            } else if let batt = json["battery"] as? Double {
                battery = "\(String(format: "%.1f", batt)) V"
            } else if let batt = json["volt"] as? String {
                if let battValue = Double(batt.replacingOccurrences(of: "V", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) {
                    battery = "\(String(format: "%.1f", battValue)) V"
                } else {
                    battery = batt.contains("V") ? batt : "\(batt) V"
                }
            } else if let batt = json["volt"] as? Double {
                battery = "\(String(format: "%.1f", batt)) V"
            }
            
            return (temperature: temperature, battery: battery)
        }
        
        // Try to parse non-JSON formats
        var temperature: String?
        var battery: String?
        
        // Look for temperature patterns
        let tempPatterns = [
            #"([0-9]+\.?[0-9]*)\s*ºC"#,
            #"([0-9]+\.?[0-9]*)\s*°C"#,
            #"([0-9]+\.?[0-9]*)\s*C"#,
            #"temp[:\s]+([0-9]+\.?[0-9]*)"#,
            #"temperature[:\s]+([0-9]+\.?[0-9]*)"#
        ]
        
        for pattern in tempPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: data, range: NSRange(data.startIndex..., in: data)),
               let range = Range(match.range(at: 1), in: data) {
                let value = String(data[range])
                temperature = "\(value) ºC"
                break
            }
        }
        
        // Look for battery/voltage patterns
        let battPatterns = [
            #"([0-9]+\.?[0-9]*)\s*V"#,
            #"battery[:\s]+([0-9]+\.?[0-9]*)"#,
            #"volt[:\s]+([0-9]+\.?[0-9]*)"#,
            #"batt[:\s]+([0-9]+\.?[0-9]*)"#
        ]
        
        for pattern in battPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: data, range: NSRange(data.startIndex..., in: data)),
               let range = Range(match.range(at: 1), in: data) {
                let value = String(data[range])
                battery = "\(value) V"
                break
            }
        }
        
        return (temperature: temperature, battery: battery)
    }
    
    private func parseTemperatureString(_ tempString: String) -> (value: String, unit: String) {
        // Handle various temperature formats
        let cleanString = tempString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Pattern for number followed by optional space and temperature unit
        let patterns = [
            #"([0-9]+\.?[0-9]*)\s*ºC"#,
            #"([0-9]+\.?[0-9]*)\s*°C"#,
            #"([0-9]+\.?[0-9]*)\s*C"#
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            guard let match = regex.firstMatch(in: cleanString, range: NSRange(cleanString.startIndex..., in: cleanString)) else { continue }
            guard let range = Range(match.range(at: 1), in: cleanString) else { continue }
            
            let value = String(cleanString[range])
            return (value: value, unit: "°C")
        }
        
        // If no temperature pattern found, return the original data
        return (value: cleanString, unit: "")
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Main data value with temperature and battery formatting
            VStack(spacing: 8) {
                Text("Data Value")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                let parsedData = parseBlockchainData(document.fields.data)
                
                if parsedData.temperature != nil || parsedData.battery != nil {
                    VStack(spacing: 6) {
                        // Temperature display
                        if let temperature = parsedData.temperature {
                            Text(temperature)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(Color("BBMSBlack"))
                        }
                        
                        // Battery display with icon
                        if let battery = parsedData.battery {
                            HStack(spacing: 6) {
                                Image(systemName: "battery.75")
                                    .foregroundColor(Color("BBMSGreen"))
                                    .font(.title2)
                                
                                Text(battery)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color("BBMSBlack"))
                            }
                        }
                    }
                } else {
                    // Fallback to original data display
                    Text(document.fields.data)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color("BBMSBlack"))
                }
            }
            .padding()
            .background(Color("BBMSGold").opacity(0.1))
            .cornerRadius(12)
            
            // Document details
            VStack(spacing: 8) {
                DocumentRow(label: "Document ID", value: String(document.id.prefix(16)) + "...")
                DocumentRow(label: "Core ID", value: document.fields.coreid ?? "N/A")
                DocumentRow(label: "Name", value: document.fields.name ?? "N/A")
                DocumentRow(label: "Published", value: document.fields.formattedPublishedDate)
                DocumentRow(label: "TTL", value: document.fields.ttl != nil ? "\(document.fields.ttl!)s" : "N/A")
                DocumentRow(label: "Clearance", value: "\(document.clearance ?? 0)")
                DocumentRow(label: "Created", value: document.formattedCreationDate)
                DocumentRow(label: "Updated", value: document.formattedUpdateDate)
            }
        }
    }
}

struct DocumentRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color("BBMSBlue"))
                .frame(minWidth: 80, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundColor(Color("BBMSBlack"))
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct AllDocumentsView: View {
    let documents: [RubidexDocument]
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var rubidexService = RubidexService.shared
    @State private var isRefreshing = false
    
    // Pull-to-refresh function
    @MainActor
    private func refreshAllData() async {
        isRefreshing = true
        
        print("🔄 Pull-to-refresh triggered in AllDocumentsView")
        
        // Refresh Rubidex data
        rubidexService.refreshData()
        
        // Add a small delay to ensure the refresh completes
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        isRefreshing = false
        print("✅ Pull-to-refresh completed in AllDocumentsView")
    }
    
    var sortedDocuments: [RubidexDocument] {
        documents.sorted { first, second in
            first.creationDate > second.creationDate
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(sortedDocuments.enumerated()), id: \.element.id) { index, document in
                        VStack(spacing: 16) {
                            HStack {
                                Text("Document #\(index + 1)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color("BBMSBlack"))
                                
                                Spacer()
                                
                                if index == 0 {
                                    Text("LATEST")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color("BBMSGreen"))
                                        .cornerRadius(4)
                                }
                            }
                            
                            Divider()
                                .background(Color("BBMSGold"))
                            
                            DocumentDetailView(document: document)
                        }
                        .padding()
                        .background(Color("BBMSWhite"))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                }
                .padding()
            }
            .refreshable {
                await refreshAllData()
            }
            .background(.gray.opacity(0.05))
            .navigationTitle("All Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color("BBMSBlue"))
                }
            }
        }
    }
}

#Preview {
    RubidexDocumentsView()
}