import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Dashboard")
                }
            
            DeviceMonitoringView()
                .tabItem {
                    Image(systemName: "sensor.tag.radiowaves.forward")
                    Text("Devices")
                }
            
            AlertsView()
                .tabItem {
                    Image(systemName: "bell.badge")
                    Text("Alerts")
                }
            
            ZoneReservationView()
                .tabItem {
                    Image(systemName: "calendar.badge.clock")
                    Text("Reservations")
                }
        }
        .accentColor(Color("BBMSGold"))
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color(.systemBackground).opacity(0.95)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
}