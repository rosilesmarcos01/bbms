import SwiftUI

struct NotificationTestView: View {
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var globalMonitor: GlobalTemperatureMonitor
    @State private var testTemperature: Double = 45.0
    @State private var testLimit: Double = 40.0
    @State private var showingStatusDetails = false
    @State private var statusDetails = "Loading..."
    @State private var backgroundStatus = "Loading..."
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("🔔 Notification Test Center")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Permission Status Card
                    VStack(spacing: 16) {
                        Text("📱 Permission Status")
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
                        
                        // Background App Refresh Status
                        HStack {
                            Image(systemName: backgroundStatus.contains("Available") ? "arrow.clockwise.circle.fill" : "arrow.clockwise.circle")
                                .foregroundColor(backgroundStatus.contains("Available") ? .green : .red)
                            
                            Text("Background Refresh")
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text(backgroundStatus.replacingOccurrences(of: "✅ ", with: "").replacingOccurrences(of: "❌ ", with: "").replacingOccurrences(of: "⚠️ ", with: ""))
                                .font(.caption)
                                .foregroundColor(backgroundStatus.contains("Available") ? .green : .red)
                        }
                        
                        Button(showingStatusDetails ? "Hide Detailed Status" : "Show Detailed Status") {
                            showingStatusDetails.toggle()
                            if showingStatusDetails {
                                loadStatusDetails()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        
                        if showingStatusDetails {
                            Text(statusDetails)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                
                    // Test Temperature Alert Card
                    VStack(spacing: 16) {
                        Text("🌡️ Test Temperature Alert")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("Temperature:")
                                Spacer()
                                Text("\(Int(testTemperature))°C")
                                    .fontWeight(.medium)
                                    .foregroundColor(testTemperature > testLimit ? .red : .primary)
                            }
                            
                            Slider(value: $testTemperature, in: 20...60, step: 1)
                            
                            HStack {
                                Text("Limit:")
                                Spacer()
                                Text("\(Int(testLimit))°C")
                                    .fontWeight(.medium)
                            }
                            
                            Slider(value: $testLimit, in: 20...50, step: 1)
                            
                            HStack {
                                Text("Status:")
                                Spacer()
                                if testTemperature > testLimit {
                                    Text("🚨 ALERT TRIGGERED")
                                        .foregroundColor(.red)
                                        .fontWeight(.bold)
                                } else {
                                    Text("✅ Within Limits")
                                        .foregroundColor(.green)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        
                        Button("🔔 Send Test Alert") {
                            sendTestAlert()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!notificationService.permissionGranted || testTemperature <= testLimit)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                
                    // Rubidex Alert Documentation Test Card
                    VStack(spacing: 16) {
                        Text("📄 Test Rubidex Documentation")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Backend Status:")
                                Spacer()
                                Text("🟢 Connected via Backend")
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                            
                            Text("✅ API key is automatically handled by the backend server")
                                .font(.caption)
                                .foregroundColor(.green)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Button("📄 Test Alert Documentation") {
                            testRubidexDocumentation()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                
                    // Global Monitoring Status Card
                    VStack(spacing: 16) {
                        Text("🌡️ Global Monitoring Status")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Status:")
                                Spacer()
                                Text(globalMonitor.isMonitoring ? "🟢 Active" : "🔴 Inactive")
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
                                Button("📊 View Full Status") {
                                    print(globalMonitor.getMonitoringStatus())
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            } else {
                                Button("▶️ Start Monitoring") {
                                    globalMonitor.startGlobalMonitoring()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Critical Alert Test Card
                    VStack(spacing: 16) {
                        Text("🚨 Critical Alert Test")
                            .font(.headline)
                        
                        Text("Tests high-priority notifications that bypass Do Not Disturb")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("🚨 Send Critical Alert") {
                            sendCriticalTestAlert()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(!notificationService.permissionGranted)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Quick Actions Card
                    VStack(spacing: 16) {
                        Text("⚡ Quick Actions")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            Button("Clear All") {
                                notificationService.clearDeliveredNotifications()
                                notificationService.clearAllPendingNotifications()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button("Test Background") {
                                simulateBackgroundAlert()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(!notificationService.permissionGranted)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Notification Test")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                backgroundStatus = notificationService.checkBackgroundAppRefreshStatus()
            }
        }
    }
    
    private func loadStatusDetails() {
        Task {
            statusDetails = await notificationService.getNotificationStatus()
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
        
        print("🔔 Sending test alert: \(testTemperature)°C > \(testLimit)°C")
        
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
        
        print("🚨 Sending critical test alert: 55.0°C > 50.0°C")
        
        notificationService.sendCriticalTemperatureAlert(
            deviceName: testDevice.name,
            deviceId: testDevice.id.uuidString,
            currentTemp: 55.0,
            criticalLimit: 50.0,
            location: testDevice.location
        )
    }
    
    private func simulateBackgroundAlert() {
        if let firstDevice = globalMonitor.monitoredDevices.first {
            print("🌡️ Simulating background alert for device: \(firstDevice.name)")
            
            notificationService.sendTemperatureAlert(
                deviceName: firstDevice.name,
                deviceId: firstDevice.id.uuidString,
                currentTemp: 45.0,
                limit: 40.0,
                location: firstDevice.location
            )
        } else {
            print("⚠️ No monitored devices available for background simulation")
        }
    }
    
    private func testRubidexDocumentation() {
        let testDevice = Device(
            name: "Rubidex Test Sensor",
            type: .temperature,
            location: "Documentation Test Lab",
            status: .warning,
            value: 45.5,
            unit: "°C",
            lastUpdated: Date()
        )
        
        print("� Testing Rubidex alert documentation...")
        
        Task {
            let success = await RubidexService.shared.writeTemperatureAlertDocument(
                deviceId: testDevice.id.uuidString,
                deviceName: testDevice.name,
                currentTemp: 45.5,
                limit: 40.0,
                location: testDevice.location,
                severity: "high"
            )
            
            DispatchQueue.main.async {
                if success {
                    print("✅ Rubidex documentation test successful!")
                } else {
                    print("❌ Rubidex documentation test failed!")
                }
            }
        }
    }
}

#Preview {
    NotificationTestView()
        .environmentObject(NotificationService.shared)
        .environmentObject(GlobalTemperatureMonitor.shared)
}