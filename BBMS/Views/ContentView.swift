import SwiftUI

struct ContentView: View {
    @EnvironmentObject var globalMonitor: GlobalTemperatureMonitor
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                AuthenticatedView()
                    .environmentObject(authService)
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
        .onAppear {
            authService.checkAuthenticationStatus()
        }
    }
}

struct AuthenticatedView: View {
    @EnvironmentObject var globalMonitor: GlobalTemperatureMonitor
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        NavigationView {
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
                
                ZoneReservationView()
                    .tabItem {
                        Image(systemName: "calendar.badge.clock")
                        Text("Reservations")
                    }
                
                AccountView()
                    .tabItem {
                        Image(systemName: "person.circle")
                        Text("Account")
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
        }
        .onAppear {
            // Only check auth status once when the view appears
            if !authService.isAuthenticated {
                authService.checkAuthenticationStatus()
            }
        }
    }
}

#Preview {
    ContentView()
}