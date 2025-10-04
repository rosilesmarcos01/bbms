import Foundation
import BackgroundTasks
import SwiftUI

class BackgroundMonitoringService: ObservableObject {
    static let shared = BackgroundMonitoringService()
    
    private let backgroundTaskIdentifier = "com.bbms.temperature-monitoring"
    @Published var isMonitoringEnabled = false
    @Published var lastBackgroundCheck: Date?
    
    private var monitoringDevices: [Device] = []
    private var deviceLimits: [String: Double] = [:]
    
    private init() {
        registerBackgroundTask()
    }
    
    // MARK: - Background Task Registration
    
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    // MARK: - Monitoring Management
    
    func startMonitoring(devices: [Device], limits: [String: Double]) {
        self.monitoringDevices = devices.filter { $0.type == .temperature }
        self.deviceLimits = limits
        self.isMonitoringEnabled = true
        
        scheduleBackgroundRefresh()
        print("Background temperature monitoring started for \(monitoringDevices.count) devices")
    }
    
    func stopMonitoring() {
        isMonitoringEnabled = false
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
        print("Background temperature monitoring stopped")
    }
    
    func updateDeviceLimits(_ limits: [String: Double]) {
        self.deviceLimits = limits
    }
    
    // MARK: - Background Task Scheduling
    
    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background refresh task scheduled")
        } catch {
            print("Could not schedule background refresh: \(error)")
        }
    }
    
    // MARK: - Background Task Handler
    
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // Schedule the next background refresh
        scheduleBackgroundRefresh()
        
        // Set expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Perform temperature check
        performBackgroundTemperatureCheck { success in
            task.setTaskCompleted(success: success)
        }
    }
    
    // MARK: - Background Temperature Monitoring
    
    private func performBackgroundTemperatureCheck(completion: @escaping (Bool) -> Void) {
        lastBackgroundCheck = Date()
        
        guard isMonitoringEnabled else {
            completion(false)
            return
        }
        
        // Create a background task to check temperatures
        Task {
            let success = await checkAllDeviceTemperatures()
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    private func checkAllDeviceTemperatures() async -> Bool {
        for device in monitoringDevices {
            guard let temperatureLimit = deviceLimits[device.id.uuidString] else {
                continue
            }
            
            // Simulate getting current temperature (in a real app, this would be an API call)
            let currentTemp = await getCurrentTemperature(for: device)
            
            // Check if temperature exceeds limits
            if currentTemp > temperatureLimit {
                // Create alert based on severity
                let criticalLimit = temperatureLimit + 10.0
                let severity: Alert.AlertSeverity = currentTemp >= criticalLimit ? .critical : .warning
                
                // Create alert object
                let alert = Alert(
                    title: severity == .critical ? "CRITICAL Background Alert" : "Background Temperature Alert",
                    message: "\(device.name) in \(device.location) exceeded temperature limit during background monitoring. Current: \(String(format: "%.1f", currentTemp))°C, Limit: \(String(format: "%.1f", temperatureLimit))°C",
                    severity: severity,
                    category: .hvac,
                    timestamp: Date(),
                    deviceId: device.id.uuidString,
                    zoneId: nil,
                    isRead: false,
                    isResolved: false
                )
                
                // Add alert to the alert service
                await MainActor.run {
                    AlertService.shared.addAlert(alert)
                }
                
                // Trigger notification
                NotificationService.shared.checkTemperatureThresholds(
                    for: device,
                    currentTemp: currentTemp,
                    temperatureLimit: temperatureLimit
                )
                
                print("Background check: Temperature alert triggered for \(device.name) - \(currentTemp)°C")
            }
        }
        
        return true
    }
    
    // MARK: - Temperature Data Fetching
    
    private func getCurrentTemperature(for device: Device) async -> Double {
        // For temperature devices, try to get real data from backend
        if device.type == .temperature {
            print("🔍 Background monitor: Getting real temperature data for device: \(device.name)")
            
            // Try to get real temperature data from RubidexService (which connects to backend)
            let rubidexService = RubidexService.shared
            
            // Refresh data to get latest readings from backend
            await MainActor.run {
                rubidexService.refreshData()
            }
            
            // Give it a moment to fetch the data
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            if let latestDocument = rubidexService.latestDocument {
                print("🔍 Background monitor: Latest document found")
                
                // Extract temperature from the latest document
                let temperatureValue = extractTemperatureValue(latestDocument.fields.data)
                
                if let temp = Double(temperatureValue.value) {
                    print("📊 Background monitor got real temperature: \(temp)°C for device \(device.name)")
                    return temp
                } else {
                    print("⚠️ Background monitor: Could not convert temperature value to Double")
                }
            } else {
                print("⚠️ Background monitor: No latest document available from backend")
            }
            
            // If no real data is available, return the device's last known value
            print("⚠️ Background monitor: No real temperature data available for \(device.name), using last known value: \(device.value)°C")
            return device.value
        }
        
        // For non-temperature devices, return their current value
        return device.value
    }
    
    // Helper function to extract temperature value from data (same as other services)
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
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: cleanString, range: NSRange(cleanString.startIndex..., in: cleanString)),
               let range = Range(match.range(at: 1), in: cleanString) {
                let value = String(cleanString[range])
                return (value: value, unit: "°C")
            }
        }
        
        // If no temperature pattern found, return the original data
        return (value: cleanString, unit: "")
    }
    
    // MARK: - App Lifecycle Integration
    
    func applicationDidEnterBackground() {
        if isMonitoringEnabled {
            scheduleBackgroundRefresh()
        }
    }
    
    func applicationWillEnterForeground() {
        // Cancel any pending background tasks since app is now active
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
        
        // Perform an immediate check if monitoring is enabled
        if isMonitoringEnabled {
            Task {
                await checkAllDeviceTemperatures()
            }
        }
    }
    
    // MARK: - Debug Utilities
    
    func getMonitoringStatus() -> String {
        var status = "Background Monitoring Status:\n"
        status += "Enabled: \(isMonitoringEnabled)\n"
        status += "Monitoring \(monitoringDevices.count) temperature devices\n"
        status += "Device limits: \(deviceLimits.count) configured\n"
        
        if let lastCheck = lastBackgroundCheck {
            status += "Last background check: \(formatDate(lastCheck))\n"
        } else {
            status += "No background checks performed yet\n"
        }
        
        return status
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}