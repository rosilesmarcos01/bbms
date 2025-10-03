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
        // In a real app, this would make an API call
        // For simulation, we'll add some random variation to the base value
        let variation = Double.random(in: -5...15)
        let currentTemp = device.value + variation
        return max(0, currentTemp)
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