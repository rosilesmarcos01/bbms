import Foundation
import Combine

class DeviceService: ObservableObject {
    @Published var devices: [Device] = []
    
    private var timer: Timer?
    
    init() {
        loadSampleData()
        startDeviceUpdates()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func loadSampleData() {
        // Only include the real Rubidex temperature sensor that connects to backend
        // All other devices will be added manually later through the backend
        devices = [
            Device(
                name: "Rubidex® Temperature Sensor",
                type: .temperature,
                location: "Portable Unit",
                status: .online,
                value: 22.0, // This will be updated with real data from backend
                unit: "°C",
                lastUpdated: Date()
            )
        ]
    }
    
    private func startDeviceUpdates() {
        // Update device data from backend every 60 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            self.updateDevicesFromBackend()
        }
    }
    
    private func updateDevicesFromBackend() {
        // Update real devices with data from backend via RubidexService
        let rubidexService = RubidexService.shared
        
        Task { @MainActor in
            // Refresh data from backend
            rubidexService.refreshData()
            
            // Update timestamp for all devices to show they're being monitored
            for i in devices.indices {
                devices[i] = Device(
                    name: devices[i].name,
                    type: devices[i].type,
                    location: devices[i].location,
                    status: devices[i].status,
                    value: devices[i].value, // Value will be updated by temperature monitoring
                    unit: devices[i].unit,
                    lastUpdated: Date()
                )
            }
        }
    }
    
    // Method to add new devices (for future manual addition)
    func addDevice(_ device: Device) {
        devices.append(device)
    }
    
    // Method to remove devices
    func removeDevice(withId id: UUID) {
        devices.removeAll { $0.id == id }
    }
    
    func getDevicesByType(_ type: Device.DeviceType) -> [Device] {
        return devices.filter { $0.type == type }
    }
    
    func getCriticalDevices() -> [Device] {
        return devices.filter { $0.status == .critical || $0.status == .warning }
    }
    
    func getDeviceStatusCounts() -> [Device.DeviceStatus: Int] {
        var counts: [Device.DeviceStatus: Int] = [:]
        for device in devices {
            counts[device.status, default: 0] += 1
        }
        return counts
    }
}