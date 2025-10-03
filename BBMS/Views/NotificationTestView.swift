import SwiftUI

struct NotificationTestView: View {
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var globalMonitor: GlobalTemperatureMonitor
    @State private var testTemperature: Double = 45.0
    @State private var testLimit: Double = 40.0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Notification Test")
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack(spacing: 16) {
                    Text("Permission Status")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: notificationService.permissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(notificationService.permissionGranted ? .green : .red)
                        
                        Text(notificationService.permissionGranted ? "Granted" : "Not Granted")
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        if !notificationService.permissionGranted {
                            Button("Request Permission") {
                                notificationService.requestPermission()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                VStack(spacing: 16) {
                    Text("Test Temperature Alert")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Temperature:")
                            Spacer()
                            Text("\(Int(testTemperature))°C")
                                .fontWeight(.medium)
                        }
                        
                        Slider(value: $testTemperature, in: 20...60, step: 1)
                        
                        HStack {
                            Text("Limit:")
                            Spacer()
                            Text("\(Int(testLimit))°C")
                                .fontWeight(.medium)
                        }
                        
                        Slider(value: $testLimit, in: 20...50, step: 1)
                    }
                    
                    Button("Send Test Alert") {
                        sendTestAlert()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!notificationService.permissionGranted || testTemperature <= testLimit)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                VStack(spacing: 16) {
                    Text("Global Monitoring Status")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Status:")
                            Spacer()
                            Text(globalMonitor.isMonitoring ? "Active" : "Inactive")
                                .fontWeight(.medium)
                                .foregroundColor(globalMonitor.isMonitoring ? .green : .red)
                        }
                        
                        HStack {
                            Text("Monitored Devices:")
                            Spacer()
                            Text("\(globalMonitor.monitoredDevices.count)")
                                .fontWeight(.medium)
                        }
                        
                        if globalMonitor.isMonitoring {
                            Button("View Full Status") {
                                print(globalMonitor.getMonitoringStatus())
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                VStack(spacing: 16) {
                    Text("Critical Alert Test")
                        .font(.headline)
                    
                    Button("Send Critical Alert") {
                        sendCriticalTestAlert()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(!notificationService.permissionGranted)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Notification Test")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func sendTestAlert() {
        let testDevice = Device(
            name: "Test Temperature Sensor",
            type: .temperature,
            location: "Test Lab",
            status: .warning,
            value: testTemperature,
            unit: "°C",
            lastUpdated: Date()
        )
        
        notificationService.sendTemperatureAlert(
            deviceName: testDevice.name,
            deviceId: testDevice.id.uuidString,
            currentTemp: testTemperature,
            limit: testLimit,
            location: testDevice.location
        )
    }
    
    private func sendCriticalTestAlert() {
        let testDevice = Device(
            name: "Critical Test Sensor",
            type: .temperature,
            location: "Critical Zone",
            status: .critical,
            value: 55.0,
            unit: "°C",
            lastUpdated: Date()
        )
        
        notificationService.sendCriticalTemperatureAlert(
            deviceName: testDevice.name,
            deviceId: testDevice.id.uuidString,
            currentTemp: 55.0,
            criticalLimit: 50.0,
            location: testDevice.location
        )
    }
}

#Preview {
    NotificationTestView()
        .environmentObject(NotificationService.shared)
        .environmentObject(GlobalTemperatureMonitor.shared)
}