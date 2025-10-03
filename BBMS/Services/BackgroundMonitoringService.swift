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
        // In a real application, this would make an API call to get the current temperature
        // For now, we'll simulate this with some logic
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Simulate temperature reading (in a real app, this would be from your API)
        // For demo purposes, we'll generate a semi-realistic temperature
        let baseTemp = device.value
        let variation = Double.random(in: -5...15) // Random variation
        let currentTemp = baseTemp + variation
        
        return max(0, currentTemp) // Ensure non-negative temperature
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