import SwiftUI
import Charts

struct DeviceDetailView: View {
    let device: Device
    @ObservedObject private var rubidexService = RubidexService.shared
    @ObservedObject private var alertService = AlertService.shared
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var backgroundMonitoring: BackgroundMonitoringService
    @EnvironmentObject var globalMonitor: GlobalTemperatureMonitor
    
    // Data service to handle all data operations
    @StateObject private var dataService: DeviceDataService
    
    // UI state
    @State private var showingAllDocuments = false
    @State private var showingAPITest = false
    @State private var showingLimitAlert = false
    @State private var showingManualAlertSent = false
    @State private var showingDeviceAlerts = false
    
    // Initialize data service
    init(device: Device) {
        self.device = device
        self._dataService = StateObject(wrappedValue: DeviceDataService(device: device))
    }
    
    // Computed properties using data service
    private var currentTemperature: (value: String, unit: String) {
        return dataService.currentTemperature
    }
    
    private var currentTemperatureValue: Double {
        return dataService.currentTemperatureValue
    }
    
    private var isTemperatureExceeded: Bool {
        return dataService.isTemperatureExceeded
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 24) {
                // Header
                HeaderView(device: device)
                
                // Current Status Card
                CurrentStatusView(
                    device: device,
                    currentTemperature: currentTemperature,
                    rubidexService: rubidexService
                )
                
                // Temperature controls (only for temperature sensors)
                if device.type == .temperature {
                    temperatureLimitView
                    notificationSettingsView
                }
                
                // Historical Data - Load this section conditionally to prevent blocking
                HistoricalDataView(
                    historicalData: dataService.historicalData,
                    device: device,
                    temperatureLimit: dataService.temperatureLimit,
                    isLoading: dataService.isLoading,
                    onRefresh: dataService.loadHistoricalData
                )
                
                // Rubidex Data
                rubidexDataSection
                
                Spacer(minLength: 100) // Ensure enough space to scroll
            }
            .padding()
        }
        .refreshable {
            await dataService.refreshAllData()
        }
        .navigationTitle("Device Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(.gray.opacity(0.05))
        .onAppear {
            print("🔄 DeviceDetailView appeared for device: \(device.name)")
        }
        .task {
            // Delay all operations to ensure view renders first
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            print("🌐 Starting delayed data loading task...")
            
            // Setup operations
            dataService.updateNotificationService(notificationService)
            dataService.loadTemperatureLimitFromGlobalMonitor()
            
            // Cache current document before refresh to prevent UI wiping
            if let currentDoc = rubidexService.latestDocument {
                dataService.updateCachedLatestDocument(currentDoc)
            }
            
            // Load data asynchronously
            await dataService.refreshAllData()
            print("📊 Delayed data loading task completed")
        }
        .onDisappear {
            // Clean up cache when view disappears
            dataService.clearCache()
        }
        .onChange(of: currentTemperatureValue) { _, newValue in
            dataService.checkTemperatureLimit(newValue)
        }
        .onChange(of: dataService.temperatureLimit) { oldValue, newValue in
            dataService.updateTemperatureLimit(newValue)
        }
        .onChange(of: rubidexService.documents) { _, newDocuments in
            // Update cache when new documents arrive
            if let latest = rubidexService.latestDocument {
                dataService.updateCachedLatestDocument(latest)
            }
            // Immediately reload when new backend data arrives
            print("🔄 Backend documents changed! Old count: \(dataService.dataCache.count), New count: \(newDocuments.count)")
            if !newDocuments.isEmpty {
                dataService.clearCache()
                Task { @MainActor in
                    print("📊 Reloading chart with new backend data...")
                    dataService.loadHistoricalData()
                }
            }
        }
        .onChange(of: rubidexService.latestDocument) { _, newDocument in
            // Update cache when latest document changes
            dataService.updateCachedLatestDocument(newDocument)
            // When latest document updates, refresh to show current value
            if newDocument != nil {
                dataService.clearCache()
                Task { @MainActor in
                    dataService.loadHistoricalData()
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
                    
                    Text("\(Int(dataService.temperatureLimit))°C")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isTemperatureExceeded ? .red : Color("BBMSBlack"))
                }
                
                HStack {
                    Text("1°C")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Slider(value: $dataService.temperatureLimit, in: 1...100, step: 1)
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
                            
                            Text("Warning Alert: > \(Int(dataService.temperatureLimit))°C")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            
                            Text("Critical Alert: > \(Int(dataService.temperatureLimit + 10))°C")
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
                                        dataService.sendManualAlert()
                                        showingManualAlertSent = true
                                        // Hide feedback after 2 seconds
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                            showingManualAlertSent = false
                                        }
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
            historicalData: dataService.historicalData,
            device: device,
            temperatureLimit: dataService.temperatureLimit,
            isLoading: dataService.isLoading,
            onRefresh: dataService.loadHistoricalData
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
                            if rubidexService.isLoading || dataService.isRefreshing {
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
                            if Date().timeIntervalSince(dataService.lastRefreshTime) < 10 {
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
                    let displayDocument = rubidexService.latestDocument ?? dataService.cachedLatestDocument
                    
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
                                    await dataService.refreshAllData()
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
                                            await dataService.refreshAllData()
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
                                
                                let parsedData = dataService.parseBlockchainData(latestDocument.fields.data)
                                
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
                                        await dataService.refreshAllData()
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
    
    private func showDeviceAlerts() {
        print("📋 Showing alerts for device: \(device.name)")
        showingDeviceAlerts = true
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
                Text("Historical Data")
                    .font(.headline)
                    .foregroundColor(Color("BBMSBlack"))
                
                Spacer()
                
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
                
                // Refresh button
                Button(action: {
                    print("🔄 Manual refresh of historical data")
                    onRefresh()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(Color("BBMSBlue"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color("BBMSBlue").opacity(0.1))
                        .cornerRadius(6)
                }
                .disabled(isLoading)
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
                                .annotation(position: .top, alignment: .leading) {
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
                    .animation(.easeOut(duration: 0.2), value: temperatureLimit) // Faster animation
                    .animation(.easeOut(duration: 0.2), value: historicalData.count) // Smooth data updates
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
                            unit: "Issues"
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
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            if !alert.isRead {
                alertService.markAsRead(alert)
            }
            // Use async dispatch to ensure sheet presentation happens after view update
            DispatchQueue.main.async {
                showingDetail = true
            }
        }) {
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
                    
                    // Status badges and quick action
                    HStack(spacing: 8) {
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
                }
                
                // Alert message
                Text(alert.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Timestamp only (removed action buttons since we have swipe actions now)
                HStack {
                    Text(timeAgo(from: alert.timestamp))
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color("BBMSWhite"))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Always show resolve option if not resolved
            if !alert.isResolved {
                Button {
                    alertService.markAsResolved(alert)
                } label: {
                    Label("Resolve", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            }
            
            // Always show mark as read option if not read
            if !alert.isRead {
                Button {
                    alertService.markAsRead(alert)
                } label: {
                    Label("Mark Read", systemImage: "envelope.open.fill")
                }
                .tint(.blue)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                showingDetail = true
            } label: {
                Label("Details", systemImage: "info.circle.fill")
            }
            .tint(Color("BBMSGold"))
        }
        .sheet(isPresented: $showingDetail) {
            AlertDetailView(alert: alert, alertService: alertService)
        }
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
    .environmentObject(NotificationService.shared)
    .environmentObject(BackgroundMonitoringService.shared)
    .environmentObject(GlobalTemperatureMonitor.shared)
}
