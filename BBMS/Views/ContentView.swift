import SwiftUI

struct ContentView: View {
    @EnvironmentObject var globalMonitor: GlobalTemperatureMonitor
    @StateObject private var authService = AuthService.shared
    @State private var showLoadingTransition = false
    @State private var showAuthenticatedView = false
    
    var body: some View {
        Group {
            if showLoadingTransition {
                LoadingTransitionView()
                    .transition(.opacity)
            } else if showAuthenticatedView {
                AuthenticatedView()
                    .environmentObject(authService)
                    .transition(.opacity)
            } else {
                LoginView()
                    .environmentObject(authService)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showLoadingTransition)
        .animation(.easeInOut(duration: 0.3), value: showAuthenticatedView)
        .onAppear {
            authService.checkAuthenticationStatus()
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                // Show loading transition
                showLoadingTransition = true
                
                // After 1.5 seconds, show the authenticated view
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showLoadingTransition = false
                    showAuthenticatedView = true
                }
            } else {
                // User logged out - reset states
                showLoadingTransition = false
                showAuthenticatedView = false
            }
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