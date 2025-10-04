import SwiftUI
import Charts

struct DeviceDetailView: View {
    let device: Device
    @State private var historicalData: [DeviceDataPoint] = []
    @State private var selectedTimeRange: TimeRange = .hour
    @State private var lastLectureData: [String: Any] = [:]
    @State private var isLoading = false
    @State private var dataCache: [String: [DeviceDataPoint]] = [:]
    @State private var lastDataLoadTime: Date = Date.distantPast
    @ObservedObject private var rubidexService = RubidexService.shared
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
            print("🔄 DeviceDetailView appeared for device: \(device.name)")
            loadTemperatureLimitFromGlobalMonitor()
            
            // Clean old cache entries (keep only current device)
            let currentDevicePrefix = device.id.uuidString
            dataCache = dataCache.filter { $0.key.hasPrefix(currentDevicePrefix) }
            
            // Load historical data
            loadHistoricalData()
            
            // Refresh Rubidex data
            rubidexService.refreshData()
        }
        .onDisappear {
            // Clean up cache when view disappears
            if dataCache.count > 4 { // Keep only 4 time ranges cached
                dataCache.removeAll()
            }
        }
        .onChange(of: selectedTimeRange) { _, _ in
            // Use debounced loading for time range changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.loadHistoricalData()
            }
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
            // Only reload if we have significantly new data
            if newDocuments.count != dataCache.values.first?.count {
                print("🔄 Significant Rubidex data change, clearing cache and reloading")
                dataCache.removeAll()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
            timeAxisStride: timeAxisStride(),
            timeAxisCount: timeAxisCount(),
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
    
    private func timeAxisStride() -> Calendar.Component {
        switch selectedTimeRange {
        case .hour: return .minute
        case .day: return .hour
        case .week: return .hour
        case .month: return .day
        }
    }
    
    private func timeAxisCount() -> Int {
        switch selectedTimeRange {
        case .hour: return 10
        case .day: return 4
        case .week: return 12
        case .month: return 5
        }
    }
    
    private func loadHistoricalData() {
        // Prevent multiple concurrent loads and rate limiting
        guard !isLoading else { return }
        
        // Rate limiting: don't reload more than once every 2 seconds
        let now = Date()
        if now.timeIntervalSince(lastDataLoadTime) < 2.0 {
            print("⏱️ Rate limited: skipping data reload")
            return
        }
        
        lastDataLoadTime = now
        
        // Check cache first
        let cacheKey = "\(device.id.uuidString)-\(selectedTimeRange.rawValue)"
        if let cachedData = dataCache[cacheKey], !cachedData.isEmpty {
            print("💾 Using cached data for \(selectedTimeRange.rawValue)")
            self.historicalData = cachedData
            return
        }
        
        isLoading = true
        print("🔄 Loading historical data for device: \(device.name)")
        
        // Use background queue for data processing
        DispatchQueue.global(qos: .userInitiated).async {
            // Try to get real data from Rubidex service first
            if !self.rubidexService.documents.isEmpty {
                self.loadHistoricalDataFromRubidexAsync()
            } else {
                // If no Rubidex data, generate consistent device-based data
                self.loadHistoricalDataFromDeviceAsync()
            }
        }
    }
    
    private func loadHistoricalDataFromRubidexAsync() {
        print("📊 Processing Rubidex documents (\(rubidexService.documents.count) documents)")
        
        var data: [DeviceDataPoint] = []
        
        // Convert Rubidex documents to data points
        for document in rubidexService.documents.sorted(by: { $0.updateDate < $1.updateDate }) {
            let extracted = extractTemperatureValue(document.fields.data)
            if let value = Double(extracted.value), value > 0 {
                data.append(DeviceDataPoint(
                    id: UUID(),
                    timestamp: document.updateDate,
                    value: value
                ))
            }
        }
        
        // Filter by time range
        let filteredData = filterDataByTimeRange(data)
        
        DispatchQueue.main.async {
            // If we don't have enough data points, supplement with device-based data
            if filteredData.count < 5 {
                print("⚠️ Insufficient Rubidex data (\(filteredData.count) points), using device data")
                self.loadHistoricalDataFromDeviceAsync()
                return
            }
            
            // Cache the result
            let cacheKey = "\(self.device.id.uuidString)-\(self.selectedTimeRange.rawValue)"
            self.dataCache[cacheKey] = filteredData
            
            self.historicalData = filteredData
            self.isLoading = false
            print("✅ Loaded \(filteredData.count) real data points from Rubidex")
        }
    }
    
    private func loadHistoricalDataFromDeviceAsync() {
        print("📊 Generating consistent data from device value")
        
        // Pre-calculate time parameters
        let calendar = Calendar.current
        let endDate = Date()
        var startDate: Date
        var interval: TimeInterval
        var numberOfPoints: Int
        
        switch selectedTimeRange {
        case .hour:
            startDate = calendar.date(byAdding: .hour, value: -1, to: endDate) ?? endDate
            interval = 300 // 5 minutes
            numberOfPoints = 12
        case .day:
            startDate = calendar.date(byAdding: .day, value: -1, to: endDate) ?? endDate
            interval = 3600 // 1 hour
            numberOfPoints = 24
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
            interval = 14400 // 4 hours
            numberOfPoints = 42
        case .month:
            startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
            interval = 86400 // 1 day
            numberOfPoints = 30
        }
        
        // Pre-calculate base value
        let baseValue: Double
        if device.type == .temperature {
            baseValue = currentTemperatureValue > 0 ? currentTemperatureValue : 22.0
        } else {
            baseValue = device.value > 0 ? device.value : 50.0
        }
        
        // Generate data points efficiently
        var data: [DeviceDataPoint] = []
        data.reserveCapacity(numberOfPoints) // Pre-allocate capacity
        
        let seed = device.id.uuidString.hash
        var generator = SeededRandomNumberGenerator(seed: seed)
        
        for i in 0..<numberOfPoints {
            let pointDate = startDate.addingTimeInterval(Double(i) * interval)
            
            // Simplified pattern calculation
            let timeProgress = Double(i) / Double(numberOfPoints)
            let dailyPattern = sin(timeProgress * 2 * .pi) * 1.5
            let randomVariation = Double.random(in: -1.5...1.5, using: &generator)
            let trendVariation = cos(timeProgress * .pi) * 0.8
            
            let value: Double
            if device.type == .temperature {
                value = max(10.0, min(50.0, baseValue + dailyPattern + randomVariation + trendVariation))
            } else {
                value = max(0, baseValue + randomVariation + trendVariation * 0.5)
            }
            
            data.append(DeviceDataPoint(
                id: UUID(),
                timestamp: pointDate,
                value: value
            ))
        }
        
        DispatchQueue.main.async {
            // Cache the result
            let cacheKey = "\(self.device.id.uuidString)-\(self.selectedTimeRange.rawValue)"
            self.dataCache[cacheKey] = data
            
            self.historicalData = data
            self.isLoading = false
            print("✅ Generated \(data.count) consistent data points")
        }
    }
    
    private func filterDataByTimeRange(_ data: [DeviceDataPoint]) -> [DeviceDataPoint] {
        let calendar = Calendar.current
        let endDate = Date()
        var startDate: Date
        
        switch selectedTimeRange {
        case .hour:
            startDate = calendar.date(byAdding: .hour, value: -1, to: endDate) ?? endDate
        case .day:
            startDate = calendar.date(byAdding: .day, value: -1, to: endDate) ?? endDate
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        }
        
        return data.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
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
    @Binding var selectedTimeRange: DeviceDetailView.TimeRange
    let device: Device
    let temperatureLimit: Double
    let isLoading: Bool
    let formatAxisLabel: (Date) -> String
    let timeAxisStride: Calendar.Component
    let timeAxisCount: Int
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
                    Text("\(historicalData.count) points")
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
                    
                    Text("Loading historical data...")
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
                            x: .value("Time", dataPoint.timestamp),
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
                            x: .value("Time", dataPoint.timestamp),
                            y: .value("Value", dataPoint.value)
                        )
                        .foregroundStyle(Color("BBMSGold"))
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .interpolationMethod(.catmullRom)
                        
                        // Data points for better visibility
                        PointMark(
                            x: .value("Time", dataPoint.timestamp),
                            y: .value("Value", dataPoint.value)
                        )
                        .foregroundStyle(Color("BBMSGold"))
                        .symbolSize(25)
                        
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
                        AxisMarks(values: .stride(by: timeAxisStride, count: timeAxisCount)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.gray.opacity(0.3))
                            
                            AxisTick(stroke: StrokeStyle(lineWidth: 1))
                                .foregroundStyle(Color("BBMSBlack").opacity(0.6))
                            
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
                    .id("chart-\(selectedTimeRange.rawValue)") // Simplified ID
                    .padding()
                }
                .frame(height: 260) // Fixed container height including padding
                .background(Color("BBMSWhite"))
                .clipShape(RoundedRectangle(cornerRadius: 12)) // Clip the entire container
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("BBMSGold"), lineWidth: 1)
                )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No Data Available")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("Historical data will appear here once readings are collected")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 260) // Fixed height matching chart container
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            }
            
            // Time Range Buttons
            HStack(spacing: 12) {
                ForEach(DeviceDetailView.TimeRange.allCases, id: \.self) { range in
                    Button(action: { 
                        selectedTimeRange = range 
                        print("📊 Selected time range: \(range.rawValue)")
                    }) {
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

#Preview {
    NavigationView {
        DeviceDetailView(device: Device(
            name: "Water Tank Level",
            type: .waterLevel,
            location: "Storage Area",
            status: .online,
            value: 75.0,
            unit: "L",
            lastUpdated: Date()
        ))
    }
}
