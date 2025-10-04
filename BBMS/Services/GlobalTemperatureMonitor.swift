import Foundation
import SwiftUI
import Combine

class GlobalTemperatureMonitor: ObservableObject {
    static let shared = GlobalTemperatureMonitor()
    
    @Published var monitoredDevices: [Device] = []
    @Published var temperatureLimits: [String: Double] = [:]
    @Published var isMonitoring = false
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let notificationService = NotificationService.shared
    private let backgroundMonitoring = BackgroundMonitoringService.shared
    private var deviceService: DeviceService?
    private var rubidexService: RubidexService?
    
    // Check interval when app is active (30 seconds)
    private let activeCheckInterval: TimeInterval = 30
    
    private init() {
        loadStoredSettings()
        setupNotificationObserver()
    }
    
    // MARK: - Public Interface
    
    func startGlobalMonitoring(with deviceService: DeviceService? = nil) {
        guard !isMonitoring else { 
            print("🌡️ Global temperature monitoring already running, skipping restart...")
            return 
        }
        
        print("🌡️ Starting global temperature monitoring...")
        isMonitoring = true
        
        // Store reference to device service for dynamic updates
        self.deviceService = deviceService
        
        // Use shared RubidexService instance for consistency
        rubidexService = RubidexService.shared
        
        // Load all temperature devices only if we don't have any monitored devices yet
        if monitoredDevices.isEmpty {
            loadTemperatureDevices()
        } else {
            print("🌡️ Using existing monitored devices: \(monitoredDevices.count)")
        }
        
        // Start periodic monitoring when app is active
        startActiveMonitoring()
        
        // Setup background monitoring
        setupBackgroundMonitoring()
        
        print("✅ Global temperature monitoring started for \(monitoredDevices.count) devices")
    }
    
    func stopGlobalMonitoring() {
        guard isMonitoring else { return }
        
        print("🛑 Stopping global temperature monitoring...")
        isMonitoring = false
        
        // Stop active monitoring
        stopActiveMonitoring()
        
        // Stop background monitoring
        backgroundMonitoring.stopMonitoring()
        
        print("✅ Global temperature monitoring stopped")
    }
    
    func updateDeviceLimit(deviceId: String, limit: Double) {
        temperatureLimits[deviceId] = limit
        saveStoredSettings()
        
        // Update background monitoring with new limits
        backgroundMonitoring.updateDeviceLimits(temperatureLimits)
        
        print("📊 Updated temperature limit for device \(deviceId): \(limit)°C")
    }
    
    func getTemperatureLimit(for deviceId: String) -> Double {
        return temperatureLimits[deviceId] ?? 40.0 // Default limit
    }
    
    // MARK: - Active Monitoring (when app is in foreground)
    
    private func startActiveMonitoring() {
        stopActiveMonitoring() // Ensure no duplicate timers
        
        timer = Timer.scheduledTimer(withTimeInterval: activeCheckInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performTemperatureCheck()
            }
        }
        
        // Perform initial check
        Task {
            await performTemperatureCheck()
        }
    }
    
    private func stopActiveMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func performTemperatureCheck() async {
        guard isMonitoring else { return }
        
        // Refresh Rubidex data to get latest temperature readings
        await refreshRubidexData()
        
        for device in monitoredDevices {
            let limit = getTemperatureLimit(for: device.id.uuidString)
            let currentTemp = await getCurrentTemperature(for: device)
            
            if currentTemp > limit {
                // Trigger notification
                notificationService.checkTemperatureThresholds(
                    for: device,
                    currentTemp: currentTemp,
                    temperatureLimit: limit
                )
                
                print("🚨 Active monitoring: Temperature alert for \(device.name) - \(currentTemp)°C > \(limit)°C")
            }
        }
    }
    
    private func refreshRubidexData() async {
        guard let rubidexService = rubidexService else { 
            print("⚠️ No RubidexService available for refresh")
            return 
        }
        
        print("🔄 Refreshing RubidexService data...")
        
        await MainActor.run {
            rubidexService.refreshData()
        }
        
        // Give it a moment to fetch the data
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds for more time
        
        print("✅ RubidexService refresh completed. Documents: \(rubidexService.documents.count), Latest: \(rubidexService.latestDocument != nil)")
    }
    
    // MARK: - Background Monitoring Setup
    
    private func setupBackgroundMonitoring() {
        let deviceLimitPairs = monitoredDevices.map { device in
            (device.id.uuidString, getTemperatureLimit(for: device.id.uuidString))
        }
        let limits = Dictionary(uniqueKeysWithValues: deviceLimitPairs)
        
        backgroundMonitoring.startMonitoring(devices: monitoredDevices, limits: limits)
    }
    
    // MARK: - Device Management
    
    private func loadTemperatureDevices() {
        // Try to load from DeviceService if available
        if let deviceService = deviceService {
            monitoredDevices = deviceService.devices.filter { $0.type == .temperature }
            print("📱 Loaded \(monitoredDevices.count) temperature devices from DeviceService")
        } else {
            // Fallback to sample devices if DeviceService is not available
            let sampleDevices = [
                Device(
                    name: "Rubidex® Temperature Sensor",
                    type: .temperature,
                    location: "Portable Unit",
                    status: .online,
                    value: 22.5,
                    unit: "°C",
                    lastUpdated: Date()
                ),
                Device(
                    name: "Outdoor Temperature Sensor",
                    type: .temperature,
                    location: "Building Exterior",
                    status: .online,
                    value: 18.5,
                    unit: "°C",
                    lastUpdated: Date()
                ),
                Device(
                    name: "Indoor Temperature Monitor",
                    type: .temperature,
                    location: "Main Lobby",
                    status: .online,
                    value: 24.0,
                    unit: "°C",
                    lastUpdated: Date()
                )
            ]
            
            monitoredDevices = sampleDevices.filter { $0.type == .temperature }
            print("📱 Loaded \(monitoredDevices.count) sample temperature devices")
        }
        
        // Load or create default limits for each device
        // Only set defaults if we don't have any stored limits at all
        var limitsChanged = false
        for device in monitoredDevices {
            if temperatureLimits[device.id.uuidString] == nil {
                // Check if there's a limit stored in individual UserDefaults as backup
                let individualKey = "temperatureLimit_\(device.id.uuidString)"
                let individualLimit = UserDefaults.standard.double(forKey: individualKey)
                
                if individualLimit > 0 {
                    // Found a backup limit, use it
                    temperatureLimits[device.id.uuidString] = individualLimit
                    limitsChanged = true
                    print("📊 Restored temperature limit for device \(device.id.uuidString) from backup: \(individualLimit)°C")
                } else {
                    // No backup found, use default
                    temperatureLimits[device.id.uuidString] = 40.0 // Default limit
                    limitsChanged = true
                    print("📊 Set default temperature limit for device \(device.id.uuidString): 40.0°C")
                }
            }
        }
        
        // Only save if we actually added new default limits
        if limitsChanged {
            saveStoredSettings()
        }
    }
    
    private func getCurrentTemperature(for device: Device) async -> Double {
        // Only try to get real temperature data for the actual Rubidex device
        if device.name.contains("Rubidex") && device.type == .temperature {
            print("🔍 Checking real data for Rubidex device...")
            
            // Try to get real temperature data from RubidexService
            if let rubidexService = rubidexService {
                print("🔍 RubidexService exists")
                
                if let latestDocument = rubidexService.latestDocument {
                    print("🔍 Latest document found: \(latestDocument.fields.data)")
                    
                    // Extract temperature from the latest document
                    let temperatureValue = extractTemperatureValue(latestDocument.fields.data)
                    print("🔍 Extracted temperature value: \(temperatureValue.value) \(temperatureValue.unit)")
                    
                    if let temp = Double(temperatureValue.value) {
                        print("📊 Global monitor got real temperature: \(temp)°C for device \(device.name)")
                        return temp
                    } else {
                        print("⚠️ Could not convert '\(temperatureValue.value)' to Double")
                    }
                } else {
                    print("⚠️ No latest document in RubidexService")
                    print("🔍 RubidexService documents count: \(rubidexService.documents.count)")
                    print("🔍 RubidexService is loading: \(rubidexService.isLoading)")
                    print("🔍 RubidexService error: \(rubidexService.errorMessage ?? "none")")
                }
            } else {
                print("⚠️ RubidexService is nil")
            }
        }
        
        // For non-Rubidex devices or when no real data is available, use simulated data
        let variation = Double.random(in: -5...15)
        let currentTemp = device.value + variation
        let result = max(0, currentTemp)
        
        if device.name.contains("Rubidex") {
            print("⚠️ Global monitor: No real data available for \(device.name), using simulated: \(result)°C")
        } else {
            print("📊 Global monitor using simulated temperature: \(result)°C for device \(device.name) (expected)")
        }
        
        return result
    }
    
    // Helper function to extract temperature value from data (same as DeviceDetailView)
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
            #"^(-?\d+(?:\.\d+)?)\s*°?([CF])$"#,  // 25.5°C, 25.5C, 25.5 C
            #"^(-?\d+(?:\.\d+)?)\s*$"#           // Just numbers like 25.5
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(cleanString.startIndex..<cleanString.endIndex, in: cleanString)
                if let match = regex.firstMatch(in: cleanString, options: [], range: range) {
                    let valueRange = Range(match.range(at: 1), in: cleanString)!
                    let value = String(cleanString[valueRange])
                    
                    // Get unit if captured
                    if match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound {
                        let unitRange = Range(match.range(at: 2), in: cleanString)!
                        let unit = String(cleanString[unitRange]).uppercased()
                        return (value: value, unit: "°\(unit)")
                    } else {
                        return (value: value, unit: "°C") // Default to Celsius
                    }
                }
            }
        }
        
        // If no pattern matches, return the original string with default unit
        return (value: cleanString, unit: "°C")
    }
    
    // MARK: - Data Persistence
    
    private func loadStoredSettings() {
        if let data = UserDefaults.standard.data(forKey: "temperatureLimits"),
           let limits = try? JSONDecoder().decode([String: Double].self, from: data) {
            self.temperatureLimits = limits
        }
    }
    
    private func saveStoredSettings() {
        if let data = try? JSONEncoder().encode(temperatureLimits) {
            UserDefaults.standard.set(data, forKey: "temperatureLimits")
        }
    }
    
    // MARK: - App Lifecycle
    
    func applicationDidBecomeActive() {
        if isMonitoring {
            startActiveMonitoring()
        }
    }
    
    func applicationDidEnterBackground() {
        stopActiveMonitoring()
        // Background monitoring continues via BackgroundMonitoringService
    }
    
    // MARK: - Notification Observer
    
    private func setupNotificationObserver() {
        // Listen for app lifecycle notifications
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.applicationDidBecomeActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.applicationDidEnterBackground()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Debug Information
    
    func getMonitoringStatus() -> String {
        var status = "Global Temperature Monitoring Status:\n"
        status += "Active: \(isMonitoring)\n"
        status += "Monitored devices: \(monitoredDevices.count)\n"
        status += "Temperature limits configured: \(temperatureLimits.count)\n"
        
        for device in monitoredDevices {
            let limit = getTemperatureLimit(for: device.id.uuidString)
            status += "- \(device.name): \(limit)°C\n"
        }
        
        return status
    }
}