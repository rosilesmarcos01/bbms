import SwiftUI
import BackgroundTasks

@main
struct BBMSApp: App {
    @State private var showSplash = true
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var backgroundMonitoring = BackgroundMonitoringService.shared
    @StateObject private var globalMonitor = GlobalTemperatureMonitor.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    ModernSplashView()
                        .transition(.opacity)
                } else {
                    ContentView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: showSplash)
            .onAppear {
                // Initialize notification service and request permissions
                initializeNotifications()
                
                // Start global temperature monitoring
                initializeGlobalMonitoring()
                
                // Show splash for 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        showSplash = false
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
            .environmentObject(notificationService)
            .environmentObject(backgroundMonitoring)
            .environmentObject(globalMonitor)
        }
    }
    
    private func initializeNotifications() {
        // Request notification permissions when app launches
        notificationService.requestPermission()
    }
    
    private func initializeGlobalMonitoring() {
        // Start global temperature monitoring
        globalMonitor.startGlobalMonitoring()
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            // App moved to background
            backgroundMonitoring.applicationDidEnterBackground()
            globalMonitor.applicationDidEnterBackground()
            
        case .active:
            // App became active
            backgroundMonitoring.applicationWillEnterForeground()
            globalMonitor.applicationDidBecomeActive()
            
        case .inactive:
            // App became inactive (e.g., incoming call, control center)
            break
            
        @unknown default:
            break
        }
    }
}