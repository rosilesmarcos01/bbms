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
        devices = [
            Device(
                name: "Main Lobby Temperature",
                type: .temperature,
                location: "Floor 1 - Lobby",
                status: .online,
                value: 22.5,
                unit: "°C",
                lastUpdated: Date()
            ),
            Device(
                name: "Water Tank Level",
                type: .waterLevel,
                location: "Roof - Tank 1",
                status: .warning,
                value: 65.0,
                unit: "%",
                lastUpdated: Date()
            ),
            Device(
                name: "Gas Level Monitor",
                type: .gasLevel,
                location: "Basement - Storage",
                status: .online,
                value: 85.0,
                unit: "%",
                lastUpdated: Date()
            ),
            Device(
                name: "Conference Room AC",
                type: .airConditioning,
                location: "Floor 3 - Room 301",
                status: .online,
                value: 20.0,
                unit: "°C",
                lastUpdated: Date()
            ),
            Device(
                name: "Emergency Lighting",
                type: .lighting,
                location: "All Floors",
                status: .critical,
                value: 0.0,
                unit: "Status",
                lastUpdated: Date()
            ),
            Device(
                name: "Main Entrance Security",
                type: .security,
                location: "Floor 1 - Main Door",
                status: .online,
                value: 1.0,
                unit: "Active",
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
                name: "Conference Room Lighting",
                type: .lighting,
                location: "Floor 2 - Room 205",
                status: .online,
                value: 85.0,
                unit: "%",
                lastUpdated: Date()
            ),
            Device(
                name: "Gas Monitor System",
                type: .gasLevel,
                location: "Basement - Utility Room",
                status: .warning,
                value: 25.0,
                unit: "ppm",
                lastUpdated: Date()
            ),
            Device(
                name: "Meeting Room AC Unit",
                type: .airConditioning,
                location: "Floor 4 - Room 401",
                status: .online,
                value: 21.0,
                unit: "°C",
                lastUpdated: Date()
            )
        ]
    }
    
    private func startDeviceUpdates() {
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.simulateDeviceUpdates()
        }
    }
    
    private func simulateDeviceUpdates() {
        for i in devices.indices {
            // Simulate random value changes
            let variation = Double.random(in: -5.0...5.0)
            devices[i].value = max(0, devices[i].value + variation)
            
            // Randomly change status occasionally
            if Double.random(in: 0...1) < 0.1 {
                devices[i].status = Device.DeviceStatus.allCases.randomElement() ?? .online
            }
            
            devices[i] = Device(
                name: devices[i].name,
                type: devices[i].type,
                location: devices[i].location,
                status: devices[i].status,
                value: devices[i].value,
                unit: devices[i].unit,
                lastUpdated: Date()
            )
        }
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