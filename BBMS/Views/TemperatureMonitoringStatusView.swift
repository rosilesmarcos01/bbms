import SwiftUI

struct TemperatureMonitoringStatusView: View {
    @EnvironmentObject var globalMonitor: GlobalTemperatureMonitor
    @EnvironmentObject var notificationService: NotificationService
    
    var body: some View {
        VStack(spacing: 16) {
            Text("🌡️ Temperature Monitoring")
                .font(.headline)
                .foregroundColor(Color("BBMSBlack"))
            
            VStack(spacing: 12) {
                // Monitoring Status
                HStack {
                    Image(systemName: globalMonitor.isMonitoring ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(globalMonitor.isMonitoring ? .green : .red)
                    
                    Text("Global Monitoring")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(globalMonitor.isMonitoring ? "Active" : "Inactive")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(globalMonitor.isMonitoring ? .green : .red)
                }
                
                // Notification Status
                HStack {
                    Image(systemName: notificationService.permissionGranted ? "bell.fill" : "bell.slash.fill")
                        .foregroundColor(notificationService.permissionGranted ? .green : .red)
                    
                    Text("Notifications")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(notificationService.permissionGranted ? "Enabled" : "Disabled")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(notificationService.permissionGranted ? .green : .red)
                }
                
                // Device Count
                HStack {
                    Image(systemName: "thermometer")
                        .foregroundColor(Color("BBMSGold"))
                    
                    Text("Temperature Devices")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(globalMonitor.monitoredDevices.count)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color("BBMSBlack"))
                }
                
                // Quick Actions
                if !notificationService.permissionGranted {
                    Button("Enable Notifications") {
                        notificationService.requestPermission()
                    }
                    .font(.caption)
                    .foregroundColor(Color("BBMSWhite"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color("BBMSGold"))
                    .cornerRadius(6)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
        .padding()
        .background(Color("BBMSWhite"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    TemperatureMonitoringStatusView()
        .environmentObject(GlobalTemperatureMonitor.shared)
        .environmentObject(NotificationService.shared)
}