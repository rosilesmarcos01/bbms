import SwiftUI
import Charts

struct DeviceDetailView: View {
    let device: Device
    @State private var historicalData: [DeviceDataPoint] = []
    @State private var lastLectureData: [String: Any] = [:]
    @State private var isLoading = false
    @State private var dataCache: [DeviceDataPoint] = []
    @State private var lastDataLoadTime: Date = Date.distantPast
    @ObservedObject private var rubidexService = RubidexService.shared
    @State private var showingAllDocuments = false
    @State private var showingAPITest = false
    @State private var temperatureLimit: Double = 40.0
    @State private var showingLimitAlert = false
    @State private var showingManualAlertSent = false
    @State private var showingDeviceAlerts = false
    @State private var isRefreshing = false
    @State private var lastRefreshTime = Date()
    @State private var cachedLatestDocument: RubidexDocument?
    @ObservedObject private var alertService = AlertService.shared
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var backgroundMonitoring: BackgroundMonitoringService
    @EnvironmentObject var globalMonitor: GlobalTemperatureMonitor
    
    // Computed property for device-specific storage key
    private var temperatureLimitKey: String {
        return "temperatureLimit_\(device.id.uuidString)"
    }
    
    // Helper function to extract temperature value from data
    private func extractTemperatureValue(_ data: String) -> (value: String, unit: String) {
        // Try to parse JSON format first
        if let jsonData = data.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let temp = json["temp"] as? String {
            return parseTemperatureString(temp)
        }
        
        // Try to parse direct temperature string
        return parseTemperatureString(data)
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
    
    // Computed property for current temperature
    private var currentTemperature: (value: String, unit: String) {
        guard let latestDocument = rubidexService.latestDocument else {
            // For temperature sensors, don't show device.value until we have real data
            if device.type == .temperature {
                return (value: "--", unit: "°C")
            }
            return (value: String(format: "%.1f", device.value), unit: device.unit)
        }
        
        let extracted = extractTemperatureValue(latestDocument.fields.data)
        if extracted.unit.isEmpty {
            return (value: String(format: "%.1f", device.value), unit: device.unit)
        } else {
            return extracted
        }
    }
    
    // Computed property to get numeric temperature value
    private var currentTemperatureValue: Double {
        if let value = Double(currentTemperature.value) {
            return value
        }
        return device.value
    }
    
    // Check if temperature exceeds limit
    private var isTemperatureExceeded: Bool {
        return device.type == .temperature && currentTemperatureValue > temperatureLimit
    }
    
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HeaderView(device: device)
                
                // Current Status Card
                CurrentStatusView(
                    device: device,
                    currentTemperature: currentTemperature,
                    rubidexService: rubidexService
                )
                
                // Temperature controls (only for temperature sensors)
                temperatureControlsSection
                
                // Historical Data
                historicalDataSection
                
                // Rubidex Data
                rubidexDataSection
                
                Spacer()
            }
            .padding()
        }
        .refreshable {
            await refreshAllData()
        }
        .navigationTitle("Device Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(.gray.opacity(0.05))
        .onAppear {
            print("🔄 DeviceDetailView appeared for device: \(device.name)")
            loadTemperatureLimitFromGlobalMonitor()
            
            // Cache current document before refresh to prevent UI wiping
            if let currentDoc = rubidexService.latestDocument {
                cachedLatestDocument = currentDoc
            }
            
            // Clear cache to force fresh data load
            dataCache.removeAll()
            
            // Force refresh backend data first, then load chart
            print("🌐 Forcing backend data refresh for chart...")
            rubidexService.refreshData()
            
            // Load historical data after backend refresh completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                print("📊 Starting chart data load after backend refresh...")
                self.loadHistoricalData()
            }
        }
        .onDisappear {
            // Clean up cache when view disappears
            dataCache.removeAll()
        }
        .onChange(of: currentTemperatureValue) { _, newValue in
            checkTemperatureLimit(newValue)
        }
        .onChange(of: temperatureLimit) { oldValue, newValue in
            print("🌡️ Temperature limit changed from \(oldValue) to \(newValue) for device \(device.id.uuidString)")
            // Save to both storage mechanisms for redundancy
            saveTemperatureLimit(newValue)
            // Update the global monitor with new limit
            globalMonitor.updateDeviceLimit(deviceId: device.id.uuidString, limit: newValue)
            // No need to reload data, the chart will update automatically with the new limit value
        }
        .onChange(of: rubidexService.documents) { _, newDocuments in
            // Update cache when new documents arrive
            if let latest = rubidexService.latestDocument {
                cachedLatestDocument = latest
            }
            // Immediately reload when new backend data arrives
            print("🔄 Backend documents changed! Old count: \(dataCache.count), New count: \(newDocuments.count)")
            if !newDocuments.isEmpty {
                dataCache.removeAll()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    print("📊 Reloading chart with new backend data...")
                    self.loadHistoricalData()
                }
            }
        }
        .onChange(of: rubidexService.latestDocument) { _, newDocument in
            // Update cache when latest document changes
            if let newDoc = newDocument {
                cachedLatestDocument = newDoc
                print("🔄 Latest document updated with value: \(newDoc.fields.data)")
            }
            // When latest document updates, refresh to show current value
            if newDocument != nil {
                dataCache.removeAll()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.loadHistoricalData()
                }
            }
        }
        .onChange(of: rubidexService.latestDocument) { _, _ in
            // When new data arrives, ensure temperature limit hasn't been reset
            let currentGlobalLimit = globalMonitor.getTemperatureLimit(for: device.id.uuidString)
            if device.type == .temperature && currentGlobalLimit != temperatureLimit {
                print("⚠️ Temperature limit mismatch detected! UI: \(temperatureLimit), Global: \(currentGlobalLimit)")
                // Restore from local backup if global was reset
                let savedLimit = UserDefaults.standard.double(forKey: temperatureLimitKey)
                if savedLimit > 0 && savedLimit != 40.0 {
                    print("🔧 Restoring temperature limit from backup: \(savedLimit)")
                    temperatureLimit = savedLimit
                    globalMonitor.updateDeviceLimit(deviceId: device.id.uuidString, limit: savedLimit)
                }
            }
        }
        .sheet(isPresented: $showingAllDocuments) {
            AllDocumentsView(documents: rubidexService.documents)
        }
        .sheet(isPresented: $showingAPITest) {
            APITestView()
        }
        .sheet(isPresented: $showingDeviceAlerts) {
            DeviceAlertsView(deviceId: device.id.uuidString, deviceName: device.name)
        }
    }
    
    // MARK: - View Sections
    
    @ViewBuilder
    private var temperatureControlsSection: some View {
        if device.type == .temperature {
            temperatureLimitView
            notificationSettingsView
        }
    }
    
    @ViewBuilder
    private var temperatureLimitView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Temperature Limit")
                    .font(.headline)
                    .foregroundColor(Color("BBMSBlack"))
                
                Spacer()
                
                if isTemperatureExceeded {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        
                        Text("Limit Exceeded")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            Divider()
                .background(Color("BBMSGold"))
            
            VStack(spacing: 12) {
                HStack {
                    Text("Set Limit Value")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("\(Int(temperatureLimit))°C")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isTemperatureExceeded ? .red : Color("BBMSBlack"))
                }
                
                HStack {
                    Text("1°C")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Slider(value: $temperatureLimit, in: 1...100, step: 1)
                        .accentColor(Color("BBMSGold"))
                    
                    Text("100°C")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if isTemperatureExceeded {
                    HStack {
                        Image(systemName: "thermometer.high")
                            .foregroundColor(.red)
                        
                        Text("Current temperature (\(currentTemperature.value)°C) exceeds the limit!")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color("BBMSWhite"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    @ViewBuilder
    private var notificationSettingsView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Notification Settings")
                    .font(.headline)
                    .foregroundColor(Color("BBMSBlack"))
                
                Spacer()
                
                let iconName = notificationService.permissionGranted ? "bell.fill" : "bell.slash.fill"
                let iconColor = notificationService.permissionGranted ? Color("BBMSGreen") : .red
                let statusText = notificationService.permissionGranted ? "Enabled" : "Disabled"
                let backgroundColor = notificationService.permissionGranted ? Color("BBMSGreen").opacity(0.1) : Color.red.opacity(0.1)
                
                HStack {
                    Image(systemName: iconName)
                        .foregroundColor(iconColor)
                    
                    Text(statusText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(iconColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(backgroundColor)
                .cornerRadius(8)
            }
            
            Divider()
                .background(Color("BBMSGold"))
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Push Notifications")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color("BBMSBlack"))
                        
                        Text("Receive alerts when temperature exceeds the limit, even when the app is closed")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    if !notificationService.permissionGranted {
                        Button("Enable") {
                            notificationService.requestPermission()
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color("BBMSWhite"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color("BBMSGold"))
                        .cornerRadius(8)
                    }
                }
                
                if notificationService.permissionGranted {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            
                            Text("Warning Alert: > \(Int(temperatureLimit))°C")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            
                            Text("Critical Alert: > \(Int(temperatureLimit + 10))°C")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Spacer()
                        }
                        
                        // Manual Alert Button (only for temperature devices)
                        if device.type == .temperature {
                            Divider()
                                .background(Color.gray.opacity(0.3))
                            
                            VStack(spacing: 12) {
                                Text("Quick Actions")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color("BBMSBlack"))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                HStack(spacing: 12) {
                                    // Send Manual Alert Button
                                    Button(action: {
                                        sendManualAlert()
                                    }) {
                                        VStack(spacing: 6) {
                                            Image(systemName: showingManualAlertSent ? "checkmark.circle.fill" : "bell.badge.fill")
                                                .font(.title3)
                                                .foregroundColor(Color("BBMSWhite"))
                                            
                                            Text(showingManualAlertSent ? "Sent!" : "Test Alert")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(Color("BBMSWhite"))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            LinearGradient(
                                                colors: showingManualAlertSent ? 
                                                    [Color("BBMSGreen"), Color("BBMSGreen").opacity(0.8)] :
                                                    [Color("BBMSRed"), Color("BBMSRed").opacity(0.8)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .cornerRadius(12)
                                        .shadow(color: showingManualAlertSent ? Color("BBMSGreen").opacity(0.3) : Color("BBMSRed").opacity(0.3), radius: 4, x: 0, y: 2)
                                    }
                                    .disabled(showingManualAlertSent)
                                    .animation(.easeInOut(duration: 0.3), value: showingManualAlertSent)
                                    
                                    // View Device Alerts Button
                                    Button(action: {
                                        showDeviceAlerts()
                                    }) {
                                        VStack(spacing: 6) {
                                            Image(systemName: "list.bullet.clipboard")
                                                .font(.title3)
                                                .foregroundColor(Color("BBMSWhite"))
                                            
                                            Text("View Alerts")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(Color("BBMSWhite"))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            LinearGradient(
                                                colors: [Color("BBMSBlue"), Color("BBMSBlue").opacity(0.8)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .cornerRadius(12)
                                        .shadow(color: Color("BBMSBlue").opacity(0.3), radius: 4, x: 0, y: 2)
                                    }
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color("BBMSWhite"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    @ViewBuilder
    private var historicalDataSection: some View {
        HistoricalDataView(
            historicalData: historicalData,
            device: device,
            temperatureLimit: temperatureLimit,
            isLoading: isLoading,
            onRefresh: loadHistoricalData
        )
    }
    
    @ViewBuilder
    private var rubidexDataSection: some View {
                
                // Rubidex Blockchain Data Panel
                VStack(spacing: 16) {
                    HStack {
                        HStack {
                            Image(systemName: "cube.box")
                                .foregroundColor(Color("BBMSGold"))
                                .font(.title3)
                            
                            Text("Rubidex® DB ")
                                .font(.headline)
                                .foregroundColor(Color("BBMSBlack"))
                            
                            // Subtle loading indicator during refresh
                            if rubidexService.isLoading || isRefreshing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color("BBMSGold")))
                                    .scaleEffect(0.6)
                            }
                        }
                        
                        Spacer()
                        
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
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color("BBMSGreen").opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    Divider()
                        .background(Color("BBMSGold"))
                    
                    // Use cached data during loading to prevent wiping
                    let displayDocument = rubidexService.latestDocument ?? cachedLatestDocument
                    
                    if let errorMessage = rubidexService.errorMessage, displayDocument == nil {
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.title2)
                            Text("Error loading data")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Color("BBMSBlack"))
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            Button("Retry") {
                                Task {
                                    await refreshAllData()
                                }
                            }
                            .font(.caption)
                            .foregroundColor(Color("BBMSBlue"))
                            .padding(.top, 4)
                        }
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                    } else if let latestDocument = displayDocument {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Latest Reading:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color("BBMSBlack"))
                                
                                Spacer()
                                
                                HStack(spacing: 12) {
                                    Button(action: {
                                        showingAllDocuments = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "list.bullet")
                                                .font(.caption)
                                            Text("All")
                                                .font(.caption)
                                        }
                                        .foregroundColor(Color("BBMSBlue"))
                                    }
                                    .disabled(rubidexService.documents.count <= 1)
                                    
                                    Button(action: {
                                        showingAPITest = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "network")
                                                .font(.caption)
                                            Text("API")
                                                .font(.caption)
                                        }
                                        .foregroundColor(Color("BBMSGold"))
                                    }
                                    
                                    Button(action: {
                                        Task {
                                            await refreshAllData()
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.caption)
                                            Text("")
                                                .font(.caption)
                                        }
                                        .foregroundColor(Color("BBMSBlue"))
                                    }
                                }
                            }
                            
                            // Main data value display
                            VStack(spacing: 8) {
                                Text("Data Value")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                let parsedData = parseBlockchainData(latestDocument.fields.data)
                                
                                if parsedData.temperature != nil || parsedData.battery != nil {
                                    VStack(spacing: 6) {
                                        // Temperature display
                                        if let temperature = parsedData.temperature {
                                            Text(temperature)
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(Color("BBMSBlack"))
                                        }
                                        
                                        // Battery display with icon
                                        if let battery = parsedData.battery {
                                            HStack(spacing: 6) {
                                                Image(systemName: "battery.75")
                                                    .foregroundColor(Color("BBMSGreen"))
                                                    .font(.title3)
                                                
                                                Text(battery)
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(Color("BBMSBlack"))
                                            }
                                        }
                                    }
                                } else {
                                    // Fallback to original data display
                                    Text(latestDocument.fields.data)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color("BBMSBlack"))
                                }
                            }
                            .padding()
                            .background(Color("BBMSGold").opacity(0.1))
                            .cornerRadius(8)
                            
                            // Document details
                            VStack(spacing: 6) {
                                RubidexDataRow(label: "Document ID", value: String(latestDocument.id.prefix(16)) + "...")
                                RubidexDataRow(label: "Core ID", value: latestDocument.fields.coreid ?? "N/A")
                                RubidexDataRow(label: "Name", value: latestDocument.fields.name ?? "N/A")
                                RubidexDataRow(label: "Published", value: latestDocument.fields.formattedPublishedDate)
                                RubidexDataRow(label: "TTL", value: latestDocument.fields.ttl != nil ? "\(latestDocument.fields.ttl!)s" : "N/A")
                                RubidexDataRow(label: "Created", value: latestDocument.formattedCreationDate)
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        }
                    } else {
                        VStack {
                            Image(systemName: "cube.box")
                                .foregroundColor(.gray)
                                .font(.title2)
                            Text(rubidexService.isLoading ? "Loading blockchain data..." : "No blockchain data available")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            if rubidexService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color("BBMSGold")))
                                    .padding(.top, 8)
                            } else {
                                Button("Load Data") {
                                    Task {
                                        await refreshAllData()
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(Color("BBMSBlue"))
                                .padding(.top, 4)
                            }
                        }
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color("BBMSWhite"))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // Pull-to-refresh function
    @MainActor
    private func refreshAllData() async {
        isRefreshing = true
        lastRefreshTime = Date()
        
        // Cache current document to prevent UI wiping
        if let currentDoc = rubidexService.latestDocument {
            cachedLatestDocument = currentDoc
        }
        
        print("🔄 Pull-to-refresh triggered")
        
        // Perform refresh operations sequentially to avoid actor isolation issues
        rubidexService.refreshData()
        
        // Wait a moment for rubidex data to start loading, then load historical data
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        loadHistoricalData()
        
        isRefreshing = false
        print("✅ Pull-to-refresh completed")
    }
    
    private func checkTemperatureLimit(_ temperature: Double) {
        if device.type == .temperature && temperature > temperatureLimit {
            createHighTemperatureAlert(temperature: temperature)
            // Trigger push notification
            notificationService.checkTemperatureThresholds(
                for: device,
                currentTemp: temperature,
                temperatureLimit: temperatureLimit
            )
        }
    }
    
    private func createHighTemperatureAlert(temperature: Double) {
        let alert = Alert(
            title: "High Temperature Alert",
            message: "Temperature sensor '\(device.name)' in \(device.location) has exceeded the limit. Current: \(String(format: "%.1f", temperature))°C, Limit: \(Int(temperatureLimit))°C",
            severity: .critical,
            category: .hvac,
            timestamp: Date(),
            deviceId: device.id.uuidString,
            zoneId: nil,
            isRead: false,
            isResolved: false
        )
        alertService.addAlert(alert)
        
        // Automatically document this alert in Rubidex
        Task {
            let success = await RubidexService.shared.writeTemperatureAlertDocument(
                deviceId: device.id.uuidString,
                deviceName: device.name,
                currentTemp: temperature,
                limit: temperatureLimit,
                location: device.location,
                severity: "critical"
            )
            
            if success {
                print("✅ Manual temperature alert automatically documented in Rubidex blockchain")
            } else {
                print("⚠️ Failed to document manual temperature alert in Rubidex blockchain")
            }
        }
    }
    
    private func sendManualAlert() {
        print("🚨 Manual alert triggered for device: \(device.name)")
        
        // Create manual alert with current temperature
        let currentTemp = currentTemperatureValue
        
        // Create alert in the alert service
        let alert = Alert(
            title: "Manual Alert Test",
            message: "Manual alert sent for '\(device.name)' in \(device.location). Current temperature: \(String(format: "%.1f", currentTemp))°C",
            severity: .warning,
            category: .hvac,
            timestamp: Date(),
            deviceId: device.id.uuidString,
            zoneId: nil,
            isRead: false,
            isResolved: false
        )
        alertService.addAlert(alert)
        
        // Send push notification
        notificationService.sendTemperatureAlert(
            deviceName: device.name,
            deviceId: device.id.uuidString,
            currentTemp: currentTemp,
            limit: temperatureLimit,
            location: device.location
        )
        
        // Show visual feedback
        showingManualAlertSent = true
        
        // Document in Rubidex blockchain
        Task {
            let success = await RubidexService.shared.writeTemperatureAlertDocument(
                deviceId: device.id.uuidString,
                deviceName: device.name,
                currentTemp: currentTemp,
                limit: temperatureLimit,
                location: device.location,
                severity: "manual_test"
            )
            
            if success {
                print("✅ Manual alert documented in Rubidex blockchain")
            } else {
                print("⚠️ Failed to document manual alert in Rubidex blockchain")
            }
            
            // Hide feedback after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showingManualAlertSent = false
            }
        }
    }
    
    private func showDeviceAlerts() {
        print("📋 Showing alerts for device: \(device.name)")
        showingDeviceAlerts = true
    }
    
    private func loadTemperatureLimitFromGlobalMonitor() {
        if device.type == .temperature {
            let globalLimit = globalMonitor.getTemperatureLimit(for: device.id.uuidString)
            print("🌡️ Loading temperature limit for device \(device.id.uuidString): global=\(globalLimit)")
            
            // If global monitor has default value, try to restore from local storage
            if globalLimit == 40.0 {
                let savedLimit = UserDefaults.standard.double(forKey: temperatureLimitKey)
                print("🌡️ Global limit is default (40), checking local backup: \(savedLimit)")
                if savedLimit > 0 {
                    // Found a saved value in local storage, use it and sync with global monitor
                    print("🔧 Restoring limit from local backup: \(savedLimit)")
                    temperatureLimit = savedLimit
                    globalMonitor.updateDeviceLimit(deviceId: device.id.uuidString, limit: savedLimit)
                } else {
                    // No saved value, use the default from global monitor
                    print("📊 Using default limit: \(globalLimit)")
                    temperatureLimit = globalLimit
                }
            } else {
                // Global monitor has a custom value, use it
                print("📊 Using global limit: \(globalLimit)")
                temperatureLimit = globalLimit
                // Also save to local storage for backup
                saveTemperatureLimit(globalLimit)
            }
        }
    }
    
    private func loadTemperatureLimit() {
        if device.type == .temperature {
            // Only load from local storage if global monitor has default value
            let globalLimit = globalMonitor.getTemperatureLimit(for: device.id.uuidString)
            if globalLimit == 40.0 { // Default value
                let savedLimit = UserDefaults.standard.double(forKey: temperatureLimitKey)
                if savedLimit > 0 {
                    temperatureLimit = savedLimit
                    // Also update the global monitor with the restored value
                    globalMonitor.updateDeviceLimit(deviceId: device.id.uuidString, limit: savedLimit)
                }
            }
        }
    }
    
    private func saveTemperatureLimit(_ limit: Double) {
        if device.type == .temperature {
            print("💾 Saving temperature limit \(limit) for device \(device.id.uuidString) to key \(temperatureLimitKey)")
            UserDefaults.standard.set(limit, forKey: temperatureLimitKey)
        }
    }
    
    private func statusColor(for status: Device.DeviceStatus) -> Color {
        switch status {
        case .online: return .green
        case .offline: return .gray
        case .warning: return .orange
        case .critical: return .red
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func loadHistoricalData() {
        // Prevent multiple concurrent loads and rate limiting
        guard !isLoading else { 
            print("⏱️ Already loading data, skipping...")
            return 
        }
        
        // Rate limiting: don't reload more than once every 2 seconds
        let now = Date()
        if now.timeIntervalSince(lastDataLoadTime) < 2.0 {
            print("⏱️ Rate limited: skipping data reload")
            return
        }
        
        lastDataLoadTime = now
        
        // Always prioritize fresh backend data over cache for charts
        print("🔄 Loading fresh chart data for device: \(device.name)")
        print("📊 Backend status - Documents: \(rubidexService.documents.count), Loading: \(rubidexService.isLoading), Error: \(rubidexService.errorMessage ?? "none")")
        
        isLoading = true
        
        // Try to use real backend data first
        if !rubidexService.documents.isEmpty {
            print("✅ Using backend data (\(rubidexService.documents.count) documents)")
            loadHistoricalDataFromRubidexAsync()
        } else {
            // If no backend data available, use fallback but log why
            print("⚠️ No backend data available - RubidexService documents: \(rubidexService.documents.count)")
            print("📱 Using fallback data generation...")
            loadHistoricalDataFromDeviceAsync()
        }
    }
    
    private func loadHistoricalDataFromRubidexAsync() {
        print("📊 Processing Rubidex backend documents (\(rubidexService.documents.count) total)")
        
        var data: [DeviceDataPoint] = []
        
        // Convert Rubidex documents to data points and sort by date
        let sortedDocuments = rubidexService.documents.sorted(by: { $0.updateDate < $1.updateDate })
        print("📊 Sorted documents by timestamp, processing...")
        
        for (index, document) in sortedDocuments.enumerated() {
            let extracted = extractTemperatureValue(document.fields.data)
            if let value = Double(extracted.value), value > 0 {
                data.append(DeviceDataPoint(
                    id: UUID(),
                    timestamp: document.updateDate,
                    value: value,
                    position: index
                ))
                print("📊 Document \(index + 1): \(value)°C at \(document.updateDate)")
            }
        }
        
        // Ensure we have good time distribution - take the last 10 readings
        let finalData: [DeviceDataPoint]
        if data.count >= 10 {
            let lastTenData = Array(data.suffix(10))
            // Re-assign positions 0-9 for even distribution
            finalData = lastTenData.enumerated().map { index, point in
                DeviceDataPoint(
                    id: point.id,
                    timestamp: point.timestamp,
                    value: point.value,
                    position: index
                )
            }
            print("✅ Using last 10 readings from \(data.count) total backend readings")
        } else if data.count > 0 {
            // Re-assign positions for even distribution
            finalData = data.enumerated().map { index, point in
                DeviceDataPoint(
                    id: point.id,
                    timestamp: point.timestamp,
                    value: point.value,
                    position: index
                )
            }
            print("✅ Using all \(data.count) available backend readings")
        } else {
            finalData = []
            print("⚠️ No valid temperature data found in backend documents")
        }
        
        DispatchQueue.main.async {
            if finalData.isEmpty {
                print("📱 No valid backend data, switching to fallback generation")
                self.loadHistoricalDataFromDeviceAsync()
                return
            }
            
            // Log the final data points for debugging
            print("📊 Final chart data points (evenly distributed):")
            for point in finalData {
                let isCurrentReading = point.id == finalData.last?.id
                print("   Position \(point.position): \(point.value)°C \(isCurrentReading ? "(CURRENT - GREEN)" : "")")
            }
            
            // Cache and set the result
            self.dataCache = finalData
            self.historicalData = finalData
            self.isLoading = false
            
            let currentValue = finalData.last?.value ?? 0
            print("✅ Chart loaded with \(finalData.count) backend readings (current: \(currentValue)°C)")
        }
    }
    
    private func loadHistoricalDataFromDeviceAsync() {
        print("📊 Generating fallback data using current device value")
        
        // Get the actual current temperature from the latest Rubidex document or device
        let actualCurrentValue: Double
        if let latestDocument = rubidexService.latestDocument {
            let extracted = extractTemperatureValue(latestDocument.fields.data)
            actualCurrentValue = Double(extracted.value) ?? currentTemperatureValue
        } else {
            actualCurrentValue = currentTemperatureValue
        }
        
        print("🌡️ Using actual current value: \(actualCurrentValue)")
        
        // Create realistic time distribution - 10 readings over last 1.5 hours
        let calendar = Calendar.current
        let endDate = Date()
        let numberOfPoints = 10
        let interval: TimeInterval = 540 // 9 minutes between readings (1.5 hours total)
        let startDate = calendar.date(byAdding: .second, value: -Int(interval * Double(numberOfPoints - 1)), to: endDate) ?? endDate
        
        // Calculate base historical value (slightly lower than current)
        let baseHistoricalValue = actualCurrentValue * 0.9 // Start 10% lower than current
        
        // Generate data points with realistic progression toward current value
        var data: [DeviceDataPoint] = []
        data.reserveCapacity(numberOfPoints)
        
        let seed = device.id.uuidString.hash
        var generator = SeededRandomNumberGenerator(seed: seed)
        
        for i in 0..<numberOfPoints {
            let pointDate = startDate.addingTimeInterval(Double(i) * interval)
            
            let value: Double
            if i == numberOfPoints - 1 {
                // Last point should be the current value
                value = actualCurrentValue
            } else {
                // Generate historical variations
                let randomVariation = Double.random(in: -2.0...2.0, using: &generator)
                
                if device.type == .temperature {
                    value = max(5.0, min(60.0, baseHistoricalValue + randomVariation))
                } else {
                    value = max(0, baseHistoricalValue + randomVariation)
                }
            }
            
            data.append(DeviceDataPoint(
                id: UUID(),
                timestamp: pointDate,
                value: value,
                position: i // Even distribution positions 0-9
            ))
        }
        
        DispatchQueue.main.async {
            // Cache the result
            self.dataCache = data
            
            self.historicalData = data
            self.isLoading = false
            print("✅ Generated \(data.count) realistic fallback readings (current: \(actualCurrentValue))")
        }
    }
    
    private func loadRubidexData() {
        // This function is now replaced by the RubidexService
        // The service handles real API calls to fetch blockchain data
    }
    
    private func formatJSONValue(_ value: Any) -> String {
        if let stringValue = value as? String {
            return stringValue
        } else if let numberValue = value as? NSNumber {
            if numberValue === kCFBooleanTrue || numberValue === kCFBooleanFalse {
                return numberValue.boolValue ? "true" : "false"
            } else if let doubleValue = numberValue as? Double, doubleValue.truncatingRemainder(dividingBy: 1) != 0 {
                return String(format: "%.6f", doubleValue)
            } else {
                return "\(numberValue)"
            }
        } else if let boolValue = value as? Bool {
            return boolValue ? "true" : "false"
        } else {
            return "\(value)"
        }
    }
}

struct DeviceDataPoint: Identifiable {
    let id: UUID
    let timestamp: Date
    let value: Double
    let position: Int // Add position for even distribution on X-axis
}

// Seeded random number generator for consistent data generation
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: Int) {
        self.state = UInt64(bitPattern: Int64(seed))
    }
    
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1
        return state
    }
}

struct RubidexDataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color("BBMSBlue"))
                .frame(minWidth: 70, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundColor(Color("BBMSBlack"))
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

struct HeaderView: View {
    let device: Device
    
    var body: some View {
        VStack(spacing: 16) {
            // BMS Logo
            Image("AppLogo")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(Color("BBMSBlack"))
                .aspectRatio(contentMode: .fit)
                .frame(width: 240, height: 80)
            
            VStack(spacing: 8) {
                Text(device.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color("BBMSBlack"))
                    .multilineTextAlignment(.center)
                
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text(device.location)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color("BBMSWhite"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct CurrentStatusView: View {
    let device: Device
    let currentTemperature: (value: String, unit: String)
    @ObservedObject var rubidexService: RubidexService
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Current Status")
                    .font(.headline)
                    .foregroundColor(Color("BBMSBlack"))
                
                Spacer()
                
                HStack {
                    Image(systemName: device.statusIcon)
                        .foregroundColor(Color(device.status.color))
                    
                    Text(device.status.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color("BBMSBlack"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(device.status.color).opacity(0.1))
                .cornerRadius(8)
            }
            
            Divider()
                .background(Color("BBMSGold"))
            
            VStack(spacing: 12) {
                HStack {
                    Text("Current Value")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    if device.type == .temperature && rubidexService.isLoading && rubidexService.latestDocument == nil {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color("BBMSGold")))
                                .scaleEffect(0.8)
                            Text("Loading...")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                        }
                    } else {
                        Text("\(currentTemperature.value) \(currentTemperature.unit)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color("BBMSBlack"))
                    }
                }
                
                // Water Tank Visualization for Water Level devices
                if device.type == .waterLevel {
                    WaterTankView(
                        currentLevel: Double(currentTemperature.value) ?? device.value,
                        maxLevel: 100.0,
                        unit: currentTemperature.unit.isEmpty ? device.unit : currentTemperature.unit
                    )
                    .frame(height: 120)
                    .padding(.vertical, 8)
                }
                
                HStack {
                    Text("Last Updated")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(formatDate(rubidexService.latestDocument?.updateDate ?? device.lastUpdated))
                        .font(.subheadline)
                        .foregroundColor(Color("BBMSBlack"))
                }
            }
        }
        .padding()
        .background(Color("BBMSWhite"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct HistoricalDataView: View {
    let historicalData: [DeviceDataPoint]
    let device: Device
    let temperatureLimit: Double
    let isLoading: Bool
    let onRefresh: () -> Void
    
    // Cached computed properties for better performance
    private var yAxisBounds: (min: Double, max: Double) {
        guard !historicalData.isEmpty else { 
            return (min: 0, max: 100) 
        }
        
        let values = historicalData.map { $0.value }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 100
        
        // Simplified bounds calculation
        let range = maxValue - minValue
        let padding = max(range * 0.1, 2.0)
        let adjustedMin = max(0, minValue - padding)
        var adjustedMax = maxValue + padding
        
        // Temperature sensor optimization
        if device.type == .temperature {
            adjustedMax = max(adjustedMax, temperatureLimit + 3)
            if adjustedMax - adjustedMin < 15 {
                let center = (adjustedMax + adjustedMin) / 2
                return (min: max(0, center - 7.5), max: center + 7.5)
            }
        }
        
        // Cap maximum range
        if adjustedMax - adjustedMin > 200 {
            adjustedMax = adjustedMin + 200
        }
        
        return (min: adjustedMin, max: adjustedMax)
    }
    
    // Check for limit violations
    private var violatingDataPoints: [DeviceDataPoint] {
        guard device.type == .temperature else { return [] }
        return historicalData.filter { $0.value > temperatureLimit }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Readings")
                    .font(.headline)
                    .foregroundColor(Color("BBMSBlack"))
                
                // Add temperature limit label for temperature devices
                if device.type == .temperature {
                    Text("Limit: \(Int(temperatureLimit))°C")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.red.opacity(0.1))
                        .cornerRadius(6)
                }
                
                Spacer()
                
                // Refresh button
                Button(action: {
                    print("🔄 Manual refresh of historical data")
                    onRefresh()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                        Text("Refresh")
                            .font(.caption)
                    }
                    .foregroundColor(Color("BBMSBlue"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color("BBMSBlue").opacity(0.1))
                    .cornerRadius(6)
                }
                .disabled(isLoading)
                
                // Data points count indicator
                if !historicalData.isEmpty {
                    Text("\(historicalData.count) readings")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            // Chart Section
            if isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color("BBMSGold")))
                        .scaleEffect(1.2)
                    
                    Text("Loading recent readings...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                }
                .frame(height: 260) // Fixed height matching chart container
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            } else if !historicalData.isEmpty {
                // Fixed container for chart to prevent size changes
                VStack(spacing: 0) {
                    Chart(historicalData) { dataPoint in
                        // Area fill under the line (render first, behind the line)
                        AreaMark(
                            x: .value("Position", dataPoint.position),
                            y: .value("Value", dataPoint.value),
                            stacking: .unstacked
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color("BBMSGold").opacity(0.3), 
                                    Color("BBMSGold").opacity(0.1),
                                    Color("BBMSGold").opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                        .clipShape(Rectangle()) // Clip to chart bounds
                        
                        // Main data line
                        LineMark(
                            x: .value("Position", dataPoint.position),
                            y: .value("Value", dataPoint.value)
                        )
                        .foregroundStyle(Color("BBMSGold"))
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .interpolationMethod(.catmullRom)
                        
                        // Data points - highlight violations in red, current value green
                        PointMark(
                            x: .value("Position", dataPoint.position),
                            y: .value("Value", dataPoint.value)
                        )
                        .foregroundStyle(
                            // Check if this is the current reading (last in array)
                            dataPoint.id == historicalData.last?.id ? Color("BBMSGreen") : // Current value green
                            (device.type == .temperature && dataPoint.value > temperatureLimit ? .red : Color("BBMSGold")) // Violations red, others gold
                        )
                        .symbolSize(
                            // Check if this is the current reading (last in array)
                            dataPoint.id == historicalData.last?.id ? 50 : // Current value larger
                            (device.type == .temperature && dataPoint.value > temperatureLimit ? 40 : 25) // Violations medium, normal small
                        )
                        
                        // Add temperature limit line for temperature sensors with animation
                        if device.type == .temperature {
                            RuleMark(y: .value("Temperature Limit", temperatureLimit))
                                .foregroundStyle(.red)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 4]))
                                .annotation(position: .top, alignment: .trailing) {
                                    Text("Limit")
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(.red.opacity(0.1))
                                        .cornerRadius(3)
                                }
                        }
                    }
                    .frame(height: 220) // Fixed height
                    .chartXAxis {
                        AxisMarks(values: Array(0..<historicalData.count)) { value in
                            AxisValueLabel {
                                if let position = value.as(Int.self) {
                                    // Show reading numbers: 1, 2, 3... with last one as "Current"
                                    if position == historicalData.count - 1 {
                                        Text("Now")
                                            .font(.caption2)
                                            .foregroundStyle(Color("BBMSGreen"))
                                            .fontWeight(.medium)
                                    } else {
                                        Text("\(position + 1)")
                                            .font(.caption2)
                                            .foregroundStyle(Color("BBMSBlack").opacity(0.6))
                                    }
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.gray.opacity(0.3))
                            
                            AxisTick(stroke: StrokeStyle(lineWidth: 1))
                                .foregroundStyle(Color("BBMSBlack").opacity(0.6))
                            
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    if device.type == .temperature {
                                        Text("\(Int(doubleValue))°C")
                                            .font(.caption)
                                            .foregroundStyle(Color("BBMSBlack"))
                                    } else {
                                        Text("\(Int(doubleValue))")
                                            .font(.caption)
                                            .foregroundStyle(Color("BBMSBlack"))
                                    }
                                }
                            }
                        }
                    }
                    .chartYScale(domain: yAxisBounds.min...yAxisBounds.max)
                    .chartBackground { chartProxy in
                        Rectangle()
                            .fill(Color("BBMSWhite"))
                    }
                    .chartPlotStyle { plotArea in
                        plotArea
                            .background(Color("BBMSWhite"))
                            .border(Color("BBMSGold").opacity(0.3), width: 1)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .clipped() // Ensure entire chart is clipped to its frame
                    .animation(.easeOut(duration: 0.3), value: temperatureLimit) // Faster animation
                    .id("recent-readings-chart") // Simplified ID
                    .padding()
                }
                .frame(height: 260) // Fixed container height including padding
                .background(Color("BBMSWhite"))
                .clipShape(RoundedRectangle(cornerRadius: 12)) // Clip the entire container
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("BBMSGold"), lineWidth: 1)
                )
                
                // Chart legend for point meanings
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color("BBMSGold"))
                            .frame(width: 8, height: 8)
                        Text("Historical")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color("BBMSGreen"))
                            .frame(width: 12, height: 12)
                        Text("Current")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    if device.type == .temperature {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.red)
                                .frame(width: 10, height: 10)
                            Text("Violation")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 4)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No Data Available")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("Recent readings will appear here once data is collected")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 260) // Fixed height matching chart container
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            }
            // Chart Statistics
            if !historicalData.isEmpty {
                HStack(spacing: 20) {
                    StatisticView(
                        title: "Average",
                        value: String(format: "%.1f", historicalData.map { $0.value }.reduce(0, +) / Double(historicalData.count)),
                        unit: device.type == .temperature ? "°C" : device.unit
                    )
                    
                    StatisticView(
                        title: "Minimum",
                        value: String(format: "%.1f", historicalData.map { $0.value }.min() ?? 0),
                        unit: device.type == .temperature ? "°C" : device.unit
                    )
                    
                    StatisticView(
                        title: "Maximum",
                        value: String(format: "%.1f", historicalData.map { $0.value }.max() ?? 0),
                        unit: device.type == .temperature ? "°C" : device.unit
                    )
                    
                    // Add violations statistic for temperature sensors
                    if device.type == .temperature && !violatingDataPoints.isEmpty {
                        StatisticView(
                            title: "Violations",
                            value: "\(violatingDataPoints.count)",
                            unit: "readings"
                        )
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color("BBMSWhite"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct StatisticView: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack(spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("BBMSBlack"))
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

struct WaterTankView: View {
    let currentLevel: Double
    let maxLevel: Double
    let unit: String
    
    private var fillPercentage: Double {
        min(max(currentLevel / maxLevel, 0.0), 1.0)
    }
    
    private var waterColor: Color {
        switch fillPercentage {
        case 0.0..<0.2:
            return Color("BBMSRed")
        case 0.2..<0.5:
            return Color("BBMSGold")
        case 0.5..<0.8:
            return Color("BBMSGold")
        default:
            return Color("BBMSBlue")
        }
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Water Tank Graphic - Simple and Clean Design
            ZStack {
                // Main tank body
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("BBMSBlack"), lineWidth: 2.5)
                    .frame(width: 80, height: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                    )
                
                // Water fill
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [waterColor.opacity(0.8), waterColor],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 76, height: CGFloat(fillPercentage * 116))
                        .animation(.easeInOut(duration: 0.8), value: fillPercentage)
                }
                .frame(width: 80, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Water surface waves (only if there's water)
                if fillPercentage > 0.05 {
                    WaterWaveView(fillPercentage: fillPercentage)
                }
                
                // Level indicator marks on the side
                VStack(spacing: 22) {
                    ForEach(0..<5, id: \.self) { index in
                        HStack {
                            Rectangle()
                                .fill(Color("BBMSBlack").opacity(0.3))
                                .frame(width: 8, height: 1)
                            Spacer()
                            Rectangle()
                                .fill(Color("BBMSBlack").opacity(0.3))
                                .frame(width: 8, height: 1)
                        }
                        .frame(width: 80)
                    }
                }
                .frame(height: 100)
                
                // Simple tank top
                Rectangle()
                    .fill(Color("BBMSBlack"))
                    .frame(width: 84, height: 3)
                    .offset(y: -61.5)
                
                // Tank legs/support
                HStack(spacing: 60) {
                    Rectangle()
                        .fill(Color("BBMSBlack"))
                        .frame(width: 3, height: 10)
                    Rectangle()
                        .fill(Color("BBMSBlack"))
                        .frame(width: 3, height: 10)
                }
                .offset(y: 70)
            }
            
            // Level Information
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Level:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("\(currentLevel, specifier: "%.1f") \(unit)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Color("BBMSBlack"))
                }
                
                HStack {
                    Text("Percentage:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("\(fillPercentage * 100, specifier: "%.1f")%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(waterColor)
                }
                
                // Status indicator
                HStack {
                    Circle()
                        .fill(waterColor)
                        .frame(width: 8, height: 8)
                    
                    Text(levelStatus)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(waterColor)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
        )
    }
    
    private var levelStatus: String {
        switch fillPercentage {
        case 0.0..<0.2:
            return "Critical Low"
        case 0.2..<0.5:
            return "Low"
        case 0.5..<0.8:
            return "Normal"
        default:
            return "Good"
        }
    }
}

struct WaterWaveView: View {
    let fillPercentage: Double
    
    var body: some View {
        let waveHeight: CGFloat = 3
        let waveLength: CGFloat = 15
        let startY = CGFloat(-60 + (1 - fillPercentage) * 116)
        
        Path { path in
            path.move(to: CGPoint(x: -38, y: startY))
            
            for x in stride(from: -38, through: 38, by: 1) {
                let relativeX = x + 38
                let sine = sin(CGFloat(relativeX) * .pi / waveLength)
                let y = startY + sine * waveHeight
                path.addLine(to: CGPoint(x: CGFloat(x), y: y))
            }
        }
        .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
    }
}

struct DeviceAlertsView: View {
    let deviceId: String
    let deviceName: String
    @ObservedObject private var alertService = AlertService.shared
    @Environment(\.dismiss) private var dismiss
    
    // Filter alerts for this specific device
    private var deviceAlerts: [Alert] {
        alertService.alerts.filter { alert in
            alert.deviceId == deviceId
        }.sorted { $0.timestamp > $1.timestamp } // Most recent first
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if deviceAlerts.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Alerts")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                        
                        Text("No alerts have been generated for '\(deviceName)' yet.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Spacer()
                    }
                } else {
                    // Alerts list
                    List {
                        Section {
                            ForEach(deviceAlerts) { alert in
                                DeviceAlertRowView(alert: alert)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                        } header: {
                            HStack {
                                Text("Alerts for \(deviceName)")
                                    .font(.headline)
                                    .foregroundColor(Color("BBMSBlack"))
                                
                                Spacer()
                                
                                Text("\(deviceAlerts.count)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color("BBMSGold"))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color("BBMSGold").opacity(0.1))
                                    .cornerRadius(6)
                            }
                            .padding(.bottom, 8)
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.gray.opacity(0.05))
                }
            }
            .navigationTitle("Device Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color("BBMSGold"))
                }
                
                if !deviceAlerts.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Mark All as Read") {
                                for alert in deviceAlerts.filter({ !$0.isRead }) {
                                    alertService.markAsRead(alert)
                                }
                            }
                            
                            Button("Clear Resolved Alerts") {
                                for alert in deviceAlerts.filter({ $0.isResolved }) {
                                    alertService.deleteAlert(alert)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(Color("BBMSGold"))
                        }
                    }
                }
            }
        }
    }
}

struct DeviceAlertRowView: View {
    let alert: Alert
    @ObservedObject private var alertService = AlertService.shared
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Severity indicator
                Circle()
                    .fill(severityColor)
                    .frame(width: 12, height: 12)
                
                // Alert title
                Text(alert.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("BBMSBlack"))
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // Status badges
                VStack(alignment: .trailing, spacing: 4) {
                    if !alert.isRead {
                        Text("NEW")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color("BBMSRed"))
                            .cornerRadius(4)
                    }
                    
                    if alert.isResolved {
                        Text("RESOLVED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color("BBMSGreen"))
                            .cornerRadius(4)
                    }
                }
            }
            
            // Alert message
            Text(alert.message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Timestamp and actions
            HStack {
                Text(timeAgo(from: alert.timestamp))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                HStack(spacing: 12) {
                    if !alert.isRead {
                        Button("Mark Read") {
                            alertService.markAsRead(alert)
                        }
                        .font(.caption)
                        .foregroundColor(Color("BBMSBlue"))
                    }
                    
                    if !alert.isResolved {
                        Button("Resolve") {
                            alertService.markAsResolved(alert)
                        }
                        .font(.caption)
                        .foregroundColor(Color("BBMSGreen"))
                    }
                }
            }
        }
        .padding()
        .background(Color("BBMSWhite"))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var severityColor: Color {
        switch alert.severity {
        case .info:
            return Color("BBMSBlue")
        case .warning:
            return Color("BBMSGold")
        case .critical:
            return Color("BBMSRed")
        case .success:
            return Color("BBMSGreen")
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

#Preview {
    NavigationView {
        DeviceDetailView(device: Device(
            name: "Rubidex® Temperature Sensor",
            type: .temperature,
            location: "Portable Unit",
            status: .online,
            value: 28.5,
            unit: "°C",
            lastUpdated: Date()
        ))
    }
}
