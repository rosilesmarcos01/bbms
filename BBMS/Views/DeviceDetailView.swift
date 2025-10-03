import SwiftUI
import Charts

struct DeviceDetailView: View {
    let device: Device
    @State private var historicalData: [DeviceDataPoint] = []
    @State private var selectedTimeRange: TimeRange = .day
    @State private var lastLectureData: [String: Any] = [:]
    @State private var isLoading = false
    @StateObject private var rubidexService = RubidexService()
    @State private var showingAllDocuments = false
    @State private var showingAPITest = false
    @State private var temperatureLimit: Double = 40.0
    @State private var showingLimitAlert = false
    @StateObject private var alertService = AlertService()
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var backgroundMonitoring: BackgroundMonitoringService
    @EnvironmentObject var globalMonitor: GlobalTemperatureMonitor
    
    // Computed property for device-specific storage key
    private var temperatureLimitKey: String {
        return "temperatureLimit_\(device.id.uuidString)"
    }
    
    enum TimeRange: String, CaseIterable {
        case hour = "1H"
        case day = "24H"
        case week = "7D"
        case month = "30D"
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
        .navigationTitle("Device Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(.gray.opacity(0.05))
        .onAppear {
            if historicalData.isEmpty {
                loadHistoricalData()
            }
            rubidexService.refreshData()
            loadTemperatureLimitFromGlobalMonitor()
        }
        .onChange(of: selectedTimeRange) { _, _ in
            loadHistoricalData()
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
            // Refresh chart when temperature limit changes to update the limit line
            if device.type == .temperature {
                loadHistoricalData()
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
            selectedTimeRange: $selectedTimeRange,
            device: device,
            temperatureLimit: temperatureLimit,
            isLoading: isLoading,
            formatAxisLabel: formatAxisLabel,
            timeAxisStride: timeAxisStride()
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
                        }
                        
                        Spacer()
                        
                        HStack {
                            Image(systemName: "checkmark.seal")
                                .foregroundColor(Color("BBMSGreen"))
                                .font(.caption)
                            
                            Text("Blockchain Verified")
                                .font(.caption)
                                .foregroundColor(Color("BBMSGreen"))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color("BBMSGreen").opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    Divider()
                        .background(Color("BBMSGold"))
                    
                    if rubidexService.isLoading {
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color("BBMSGold")))
                            Text("Loading blockchain data...")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        }
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                    } else if let errorMessage = rubidexService.errorMessage {
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
                                rubidexService.refreshData()
                            }
                            .font(.caption)
                            .foregroundColor(Color("BBMSBlue"))
                            .padding(.top, 4)
                        }
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                    } else if let latestDocument = rubidexService.latestDocument {
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
                                        rubidexService.refreshData()
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
                            VStack(spacing: 4) {
                                Text("Data Value")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Text(latestDocument.fields.data)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color("BBMSBlack"))
                            }
                            .padding()
                            .background(Color("BBMSGold").opacity(0.1))
                            .cornerRadius(8)
                            
                            // Document details
                            VStack(spacing: 6) {
                                RubidexDataRow(label: "Document ID", value: String(latestDocument.id.prefix(16)) + "...")
                                RubidexDataRow(label: "Core ID", value: latestDocument.fields.coreid)
                                RubidexDataRow(label: "Name", value: latestDocument.fields.name)
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
                            Text("No blockchain data available")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Button("Load Data") {
                                rubidexService.refreshData()
                            }
                            .font(.caption)
                            .foregroundColor(Color("BBMSBlue"))
                            .padding(.top, 4)
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
    
    private func formatAxisLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch selectedTimeRange {
        case .hour:
            formatter.dateFormat = "HH:mm"
        case .day:
            formatter.dateFormat = "HH:mm"
        case .week:
            formatter.dateFormat = "MM/dd"
        case .month:
            formatter.dateFormat = "MM/dd"
        }
        return formatter.string(from: date)
    }
    
    private func timeAxisStride() -> Int {
        switch selectedTimeRange {
        case .hour: return 1
        case .day: return 4
        case .week: return 24
        case .month: return 168 // 7 days
        }
    }
    
    private func loadHistoricalData() {
        // Prevent multiple concurrent loads
        guard !isLoading else { return }
        isLoading = true
        
        // Simulated loading historical data
        let calendar = Calendar.current
        let endDate = Date()
        var startDate: Date
        var interval: TimeInterval
        
        switch selectedTimeRange {
        case .hour:
            startDate = calendar.date(byAdding: .hour, value: -1, to: endDate) ?? endDate
            interval = 300 // 5 minutes
        case .day:
            startDate = calendar.date(byAdding: .day, value: -1, to: endDate) ?? endDate
            interval = 3600 // 1 hour
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
            interval = 21600 // 6 hours
        case .month:
            startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
            interval = 86400 // 1 day
        }
        
        var data: [DeviceDataPoint] = []
        var currentDate = startDate
        
        // Use current temperature value as base for temperature sensors
        let baseValue: Double
        if device.type == .temperature {
            baseValue = currentTemperatureValue
        } else {
            baseValue = device.value
        }
        
        while currentDate <= endDate {
            // Create realistic temperature variations around the current reading
            let variation: Double
            if device.type == .temperature {
                // More realistic temperature variations (±3°C for temperature sensors)
                variation = Double.random(in: -3...3)
            } else {
                // Generic variation for other sensor types
                variation = Double.random(in: -5...5)
            }
            
            let value = max(0, baseValue + variation)
            
            data.append(DeviceDataPoint(
                id: UUID(),
                timestamp: currentDate,
                value: value
            ))
            
            currentDate = currentDate.addingTimeInterval(interval)
        }
        
        // Use a small delay to simulate network loading, but keep it stable
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.historicalData = data
            self.isLoading = false
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
    @Binding var selectedTimeRange: DeviceDetailView.TimeRange
    let device: Device
    let temperatureLimit: Double
    let isLoading: Bool
    let formatAxisLabel: (Date) -> String
    let timeAxisStride: Int
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Historical Data")
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
            }
            
            // Chart
            if !historicalData.isEmpty {
                Chart(historicalData) { dataPoint in
                    LineMark(
                        x: .value("Time", dataPoint.timestamp),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(Color("BBMSGold"))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Time", dataPoint.timestamp),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color("BBMSGold").opacity(0.3), Color("BBMSGold").opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Add temperature limit line for temperature sensors
                    if device.type == .temperature {
                        RuleMark(y: .value("Limit", temperatureLimit))
                            .foregroundStyle(.red)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: timeAxisStride)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(formatAxisLabel(date))
                                    .font(.caption)
                                    .foregroundStyle(Color("BBMSBlack"))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if device.type == .temperature {
                                Text("\(value.as(Double.self) ?? 0, specifier: "%.0f")°C")
                                    .font(.caption)
                                    .foregroundStyle(Color("BBMSBlack"))
                            } else {
                                Text("\(value.as(Double.self) ?? 0, specifier: "%.0f")")
                                    .font(.caption)
                                    .foregroundStyle(Color("BBMSBlack"))
                            }
                        }
                    }
                }
                .chartBackground { chartProxy in
                    Rectangle()
                        .fill(Color("BBMSWhite"))
                }
                .padding()
                .background(Color("BBMSWhite"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("BBMSGold"), lineWidth: 1)
                )
            } else {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color("BBMSGold")))
                        .scaleEffect(1.2)
                    
                    Text("Loading historical data...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            }
            
            // Time Range Buttons
            HStack(spacing: 12) {
                ForEach(DeviceDetailView.TimeRange.allCases, id: \.self) { range in
                    Button(action: { selectedTimeRange = range }) {
                        Text(range.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedTimeRange == range ? Color("BBMSWhite") : Color("BBMSBlack"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedTimeRange == range ? Color("BBMSGold") : Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color("BBMSWhite"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
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

#Preview {
    NavigationView {
        DeviceDetailView(device: Device(
            name: "Temperature Sensor",
            type: .temperature,
            location: "Main Lobby",
            status: .online,
            value: 22.5,
            unit: "°C",
            lastUpdated: Date()
        ))
    }
}
