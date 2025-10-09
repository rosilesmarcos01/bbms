import Foundation
import SwiftUI

// MARK: - Device Data Service
/// Handles all data fetching, writing, generation, and caching for device details
/// This service separates business logic from UI presentation in DeviceDetailView
class DeviceDataService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var historicalData: [DeviceDataPoint] = []
    @Published var isLoading = false
    @Published var dataCache: [DeviceDataPoint] = []
    @Published var lastDataLoadTime: Date = Date.distantPast
    @Published var cachedLatestDocument: RubidexDocument?
    @Published var isRefreshing = false
    @Published var lastRefreshTime = Date()
    @Published var temperatureLimit: Double = 40.0
    
    // MARK: - Private Properties
    private let device: Device
    private let rubidexService: RubidexService
    private let alertService: AlertService
    private var notificationService: NotificationService
    private let globalMonitor: GlobalTemperatureMonitor
    
    // MARK: - Computed Properties
    
    /// Storage key for device-specific temperature limit
    private var temperatureLimitKey: String {
        return "temperatureLimit_\(device.id.uuidString)"
    }
    
    /// Current temperature extracted from latest document or device value
    var currentTemperature: (value: String, unit: String) {
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
    
    /// Numeric temperature value for calculations
    var currentTemperatureValue: Double {
        if let value = Double(currentTemperature.value) {
            return value
        }
        return device.value
    }
    
    /// Check if temperature exceeds limit
    var isTemperatureExceeded: Bool {
        return device.type == .temperature && currentTemperatureValue > temperatureLimit
    }
    
    // MARK: - Initialization
    
    init(device: Device) {
        self.device = device
        self.rubidexService = RubidexService.shared
        self.alertService = AlertService.shared
        self.notificationService = NotificationService()  // Create a default instance
        self.globalMonitor = GlobalTemperatureMonitor.shared
        
        // Load temperature limit from storage
        loadTemperatureLimitFromGlobalMonitor()
    }
    
    // MARK: - Service Updates
    /// Update the notification service reference (called from view)
    func updateNotificationService(_ service: NotificationService) {
        self.notificationService = service
    }
    
    // MARK: - Temperature Extraction Functions
    
    /// Extract temperature value from data string (JSON or plain text)
    func extractTemperatureValue(_ data: String) -> (value: String, unit: String) {
        // Try to parse JSON format first
        if let jsonData = data.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let temp = json["temp"] as? String {
            return parseTemperatureString(temp)
        }
        
        // Try to parse direct temperature string
        return parseTemperatureString(data)
    }
    
    /// Parse temperature string with various formats
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
    
    // MARK: - Blockchain Data Parsing
    
    /// Parse blockchain data to extract temperature and battery values
    func parseBlockchainData(_ data: String) -> (temperature: String?, battery: String?) {
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
    
    // MARK: - Historical Data Loading
    
    /// Load historical data with rate limiting and caching
    func loadHistoricalData() {
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
    
    /// Load historical data from Rubidex backend documents
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
    
    /// Generate fallback historical data using device value
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
    
    // MARK: - Data Refresh Functions
    
    /// Refresh all data sources
    @MainActor
    func refreshAllData() async {
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
    
    /// Clear data cache
    func clearCache() {
        dataCache.removeAll()
    }
    
    /// Update cached latest document
    func updateCachedLatestDocument(_ document: RubidexDocument?) {
        if let newDoc = document {
            cachedLatestDocument = newDoc
            print("🔄 Latest document updated with value: \(newDoc.fields.data)")
        }
    }
    
    // MARK: - Temperature Limit Management
    
    /// Load temperature limit from global monitor and local storage
    func loadTemperatureLimitFromGlobalMonitor() {
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
    
    /// Save temperature limit to local storage
    func saveTemperatureLimit(_ limit: Double) {
        if device.type == .temperature {
            print("💾 Saving temperature limit \(limit) for device \(device.id.uuidString) to key \(temperatureLimitKey)")
            UserDefaults.standard.set(limit, forKey: temperatureLimitKey)
            temperatureLimit = limit
        }
    }
    
    /// Update temperature limit
    func updateTemperatureLimit(_ newLimit: Double) {
        print("🌡️ Temperature limit changed to \(newLimit) for device \(device.id.uuidString)")
        // Save to both storage mechanisms for redundancy
        saveTemperatureLimit(newLimit)
        // Update the global monitor with new limit
        globalMonitor.updateDeviceLimit(deviceId: device.id.uuidString, limit: newLimit)
    }
    
    // MARK: - Alert Creation and Writing
    
    /// Check temperature limit and create alert if exceeded
    func checkTemperatureLimit(_ temperature: Double) {
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
    
    /// Create high temperature alert
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
    
    /// Send manual alert for testing
    func sendManualAlert() {
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
        }
    }
    
    // MARK: - Utility Functions
    
    /// Format JSON values for display
    func formatJSONValue(_ value: Any) -> String {
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

// MARK: - Supporting Structures

/// Data point for historical device readings
struct DeviceDataPoint: Identifiable {
    let id: UUID
    let timestamp: Date
    let value: Double
    let position: Int // Add position for even distribution on X-axis
}

/// Seeded random number generator for consistent data generation
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
