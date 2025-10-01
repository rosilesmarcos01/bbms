import SwiftUI

struct DashboardView: View {
    @StateObject private var deviceService = DeviceService()
    @StateObject private var zoneService = ZoneService()
    @State private var scrollOffset: CGFloat = 0
    @State private var showingNotifications = false
    @State private var refreshData = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Dynamic background with parallax effect
                    DynamicBackground(scrollOffset: scrollOffset)
                    
                    VStack(spacing: 0) {
                        // Ultra-modern floating header
                        UltraModernHeader(
                            showingNotifications: $showingNotifications,
                            scrollOffset: scrollOffset
                        )
                        .zIndex(100)
                        
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                // Hero metrics section with animations
                                HeroMetricsSection(
                                    deviceService: deviceService,
                                    zoneService: zoneService
                                )
                                .padding(.top, 10)
                                
                                // Advanced system status with real-time updates
                                AdvancedStatusCard(deviceService: deviceService)
                                
                                // Interactive alerts with priority sorting
                                InteractiveAlertsCard(deviceService: deviceService)
                                
                                // Smart reservations with timeline
                                SmartReservationsCard(zoneService: zoneService)
                                
                                // AI insights and analytics
                                AnalyticsInsightsCard(
                                    deviceService: deviceService,
                                    zoneService: zoneService
                                )
                                
                                // Performance metrics grid
                                PerformanceMetricsGrid(
                                    deviceService: deviceService,
                                    zoneService: zoneService
                                )
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 120)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear
                                        .preference(
                                            key: ScrollOffsetPreferenceKey.self,
                                            value: proxy.frame(in: .named("scroll")).minY
                                        )
                                }
                            )
                        }
                        .coordinateSpace(name: "scroll")
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scrollOffset = value
                            }
                        }
                        .refreshable {
                            await refreshAllData()
                        }
                    }
                }
                .navigationBarHidden(true)
                .ignoresSafeArea(.all, edges: .top)
            }
        }
        .task {
            await loadInitialData()
        }
    }
    
    private func refreshAllData() async {
        // Simulate data refresh with haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        withAnimation(.spring()) {
            refreshData.toggle()
        }
    }
    
    private func loadInitialData() async {
        // Initial data loading with staggered animations
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
}
// MARK: - Dynamic Background
struct DynamicBackground: View {
    let scrollOffset: CGFloat
    
    var body: some View {
        ZStack {
            // Base gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color(.systemGray6).opacity(0.3),
                    Color(.systemBackground)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated floating orbs
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color("BBMSGold").opacity(0.1),
                                Color("BBMSGold").opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: CGFloat(100 + index * 50))
                    .offset(
                        x: CGFloat(index * 150) - 100,
                        y: scrollOffset * 0.1 + CGFloat(index * 100)
                    )
                    .blur(radius: 1)
            }
        }
        .ignoresSafeArea(.all)
    }
}

// MARK: - Ultra Modern Header
struct UltraModernHeader: View {
    @Binding var showingNotifications: Bool
    let scrollOffset: CGFloat
    
    private var headerOpacity: Double {
        min(1.0, max(0.85, 1.0 + scrollOffset / 100))
    }
    
    private var headerBlur: CGFloat {
        max(0, min(20, -scrollOffset / 10))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Animated logo with pulse effect
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color("BBMSGold"),
                                    Color("BBMSGold").opacity(0.8),
                                    Color("BBMSGold").opacity(0.6)
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 56, height: 56)
                        .scaleEffect(scrollOffset < -50 ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: scrollOffset)
                    
                    Image(systemName: "building.2.crop.circle")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Smart Building")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color("BBMSBlack"),
                                        Color("BBMSBlack").opacity(0.8)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // Live status indicator
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                                .scaleEffect(1.0)
                                .animation(
                                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                    value: Date().timeIntervalSince1970
                                )
                            
                            Text("LIVE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    
                    Text("Control Center")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                // Modern notification button with badge
                Button(action: { showingNotifications.toggle() }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .frame(width: 48, height: 48)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "bell.badge")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color("BBMSBlack"),
                                        Color("BBMSBlack").opacity(0.8)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                .scaleEffect(showingNotifications ? 0.95 : 1.0)
                .animation(.spring(response: 0.3), value: showingNotifications)
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 20)
        }
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 0)
        )
        .opacity(headerOpacity)
        .blur(radius: headerBlur)
        .animation(.easeInOut(duration: 0.2), value: scrollOffset)
    }
}
// MARK: - Hero Metrics Section
struct HeroMetricsSection: View {
    @ObservedObject var deviceService: DeviceService
    @ObservedObject var zoneService: ZoneService
    @State private var animateMetrics = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Main KPI Cards
            HStack(spacing: 12) {
                HeroMetricCard(
                    title: "System Health",
                    value: "\(calculateSystemHealth())%",
                    trend: "+2.3%",
                    trendColor: .green,
                    icon: "heart.fill",
                    iconColor: Color("BBMSGold"),
                    progress: Double(calculateSystemHealth()) / 100.0
                )
                
                HeroMetricCard(
                    title: "Active Zones",
                    value: "\(calculateActiveZones())",
                    trend: "+5",
                    trendColor: .green,
                    icon: "building.2.fill",
                    iconColor: .blue,
                    progress: calculateZoneUtilization()
                )
            }
            
            // Secondary metrics with more detail
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                CompactMetricCard(
                    title: "Devices Online",
                    value: "\(deviceService.getDeviceStatusCounts()[.online] ?? 0)",
                    total: Double(deviceService.devices.count),
                    color: .green
                )
                
                CompactMetricCard(
                    title: "Critical Alerts",
                    value: "\(deviceService.getDeviceStatusCounts()[.critical] ?? 0)",
                    total: 10.0, // Max expected alerts
                    color: .red
                )
                
                CompactMetricCard(
                    title: "System Health",
                    value: "\(calculateSystemHealth())%",
                    total: 100.0,
                    color: calculateSystemHealth() > 80 ? .green : calculateSystemHealth() > 60 ? .orange : .red
                )
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                animateMetrics = true
            }
        }
    }
    
    private func calculateSystemHealth() -> Int {
        let statusCounts = deviceService.getDeviceStatusCounts()
        let totalDevices = statusCounts.values.reduce(0, +)
        guard totalDevices > 0 else { return 100 }
        
        let onlineDevices = statusCounts[.online] ?? 0
        let warningDevices = statusCounts[.warning] ?? 0
        let criticalDevices = statusCounts[.critical] ?? 0
        let offlineDevices = statusCounts[.offline] ?? 0
        
        // Weighted health calculation
        let healthScore = (onlineDevices * 100 + warningDevices * 70 + criticalDevices * 20 + offlineDevices * 0) / totalDevices
        return min(100, max(0, healthScore))
    }
    
    private func calculateActiveZones() -> Int {
        return zoneService.zones.filter { !$0.isAvailable }.count
    }
    
    private func calculateZoneUtilization() -> Double {
        let totalZones = zoneService.zones.count
        let activeZones = calculateActiveZones()
        return totalZones > 0 ? Double(activeZones) / Double(totalZones) : 0.0
    }
}

// MARK: - Hero Metric Card
struct HeroMetricCard: View {
    let title: String
    let value: String
    let trend: String
    let trendColor: Color
    let icon: String
    let iconColor: Color
    let progress: Double
    
    @State private var animateProgress = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(iconColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(trend)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(trendColor)
                    
                    HStack(spacing: 2) {
                        Image(systemName: trendColor == .green ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                            .foregroundColor(trendColor)
                        
                        Text("vs last week")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(value)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color("BBMSBlack"),
                                Color("BBMSBlack").opacity(0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [iconColor, iconColor.opacity(0.7)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: animateProgress ? geometry.size.width * progress : 0, height: 6)
                            .animation(.easeInOut(duration: 1.0).delay(0.5), value: animateProgress)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            iconColor.opacity(0.3),
                            iconColor.opacity(0.1),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .onAppear {
            animateProgress = true
        }
    }
}

// MARK: - Compact Metric Card
struct CompactMetricCard: View {
    let title: String
    let value: String
    let total: Double
    let color: Color
    
    var progress: Double {
        if let intValue = Int(value.replacingOccurrences(of: "%", with: "")) {
            return Double(intValue) / total
        }
        return 0.0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Mini progress indicator
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 20, height: 20)
                .rotationEffect(.degrees(-90))
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.2), lineWidth: 3)
                        .frame(width: 20, height: 20)
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - Advanced Status Card
struct AdvancedStatusCard: View {
    @ObservedObject var deviceService: DeviceService
    @State private var selectedFilter: DeviceStatusFilter = .all
    @State private var animateChart = false
    @State private var showingDetails = false
    
    enum DeviceStatusFilter: String, CaseIterable {
        case all = "All"
        case critical = "Critical"
        case warning = "Warning"
        case online = "Online"
        
        var color: Color {
            switch self {
            case .all: return Color("BBMSBlack")
            case .critical: return .red
            case .warning: return .orange
            case .online: return .green
            }
        }
    }
    
    private var statusCounts: [Device.DeviceStatus: Int] {
        deviceService.getDeviceStatusCounts()
    }
    
    private var totalDevices: Int {
        statusCounts.values.reduce(0, +)
    }
    
    private var systemHealthScore: Int {
        guard totalDevices > 0 else { return 100 }
        let onlineDevices = statusCounts[.online] ?? 0
        
        let warningDevices = statusCounts[.warning] ?? 0
        let criticalDevices = statusCounts[.critical] ?? 0
        let offlineDevices = statusCounts[.offline] ?? 0
        
        // Calculate weighted health score
        let healthScore = (onlineDevices * 100 + warningDevices * 70 + criticalDevices * 20 + offlineDevices * 0) / totalDevices
        return min(100, max(0, healthScore))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header with live indicators
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Quick Overview")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color("BBMSBlack"))
                        
                        // Live indicator
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                                .scaleEffect(animateChart ? 1.2 : 0.8)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: animateChart)
                            
                            Text("Online")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    
                    HStack(spacing: 12) {
                        Text("Health Score: \(systemHealthScore)%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("\(totalDevices) Total Devices")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: { showingDetails.toggle() }) {
                    Image(systemName: showingDetails ? "chart.pie.fill" : "chart.pie")
                        .font(.title3)
                        .foregroundColor(Color("BBMSGold"))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            
            if showingDetails {
                // Enhanced Chart Section
                HStack(spacing: 24) {
                    // Circular Chart
                    SystemOverviewChart(
                        statusCounts: statusCounts,
                        totalDevices: totalDevices,
                        animateChart: animateChart
                    )
                    .frame(width: 140, height: 140)
                    
                    // Status Breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Device.DeviceStatus.allCases, id: \.self) { status in
                            StatusBreakdownRow(
                                status: status,
                                count: statusCounts[status] ?? 0,
                                total: totalDevices,
                                isSelected: selectedFilter.rawValue.lowercased() == status.rawValue.lowercased() || selectedFilter == .all
                            )
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    selectedFilter = DeviceStatusFilter(rawValue: status.rawValue.capitalized) ?? .all
                                }
                            }
                        }
                    }
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                // Compact Status Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    ForEach(Device.DeviceStatus.allCases, id: \.self) { status in
                        CompactStatusCard(
                            status: status,
                            count: statusCounts[status] ?? 0,
                            total: totalDevices,
                            animateChart: animateChart
                        )
                        .onTapGesture {
                            withAnimation(.spring()) {
                                selectedFilter = DeviceStatusFilter(rawValue: status.rawValue.capitalized) ?? .all
                            }
                        }
                    }
                }
            }
            
            // Filter-based content
            if selectedFilter != .all {
                DeviceListSection(
                    devices: getFilteredDevices(),
                    title: "\(selectedFilter.rawValue) Devices (\(getFilteredDevices().count))"
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                SystemInsightsSection(
                    statusCounts: statusCounts,
                    healthScore: systemHealthScore
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 25, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color("BBMSGold").opacity(0.3),
                            Color("BBMSGold").opacity(0.1),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                animateChart = true
            }
        }
    }
    
    private func getFilteredDevices() -> [Device] {
        switch selectedFilter {
        case .all:
            return deviceService.devices
        case .critical:
            return deviceService.devices.filter { $0.status == .critical }
        case .warning:
            return deviceService.devices.filter { $0.status == .warning }
        case .online:
            return deviceService.devices.filter { $0.status == .online }
        }
    }
}

// MARK: - System Overview Chart
struct SystemOverviewChart: View {
    let statusCounts: [Device.DeviceStatus: Int]
    let totalDevices: Int
    let animateChart: Bool
    
    @State private var animationProgress: CGFloat = 0
    
    private var chartData: [(Device.DeviceStatus, Double, Color)] {
        Device.DeviceStatus.allCases.map { status in
            let count = statusCounts[status] ?? 0
            let percentage = totalDevices > 0 ? Double(count) / Double(totalDevices) : 0
            return (status, percentage, Color(status.color))
        }
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 8)
            
            // Animated segments
            ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                let (status, percentage, color) = data
                let startAngle = getStartAngle(for: index)
                let endAngle = getEndAngle(for: index)
                
                Circle()
                    .trim(
                        from: startAngle / 360,
                        to: animateChart ? endAngle / 360 : startAngle / 360
                    )
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(
                        .easeInOut(duration: 1.0).delay(Double(index) * 0.1),
                        value: animateChart
                    )
            }
            
            // Center content
            VStack(spacing: 4) {
                Text("\(totalDevices)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color("BBMSBlack"))
                
                Text("Devices")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
            }
            .scaleEffect(animateChart ? 1.0 : 0.8)
            .opacity(animateChart ? 1.0 : 0.0)
            .animation(.spring(response: 0.6).delay(0.5), value: animateChart)
        }
    }
    
    private func getStartAngle(for index: Int) -> Double {
        var angle: Double = 0
        for i in 0..<index {
            let count = statusCounts[Device.DeviceStatus.allCases[i]] ?? 0
            let percentage = totalDevices > 0 ? Double(count) / Double(totalDevices) : 0
            angle += percentage * 360
        }
        return angle
    }
    
    private func getEndAngle(for index: Int) -> Double {
        let count = statusCounts[Device.DeviceStatus.allCases[index]] ?? 0
        let percentage = totalDevices > 0 ? Double(count) / Double(totalDevices) : 0
        return getStartAngle(for: index) + (percentage * 360)
    }
}

// MARK: - Status Breakdown Row
struct StatusBreakdownRow: View {
    let status: Device.DeviceStatus
    let count: Int
    let total: Int
    let isSelected: Bool
    
    private var percentage: Double {
        total > 0 ? Double(count) / Double(total) : 0
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(status.color))
                    .frame(width: 10, height: 10)
                
                Text(status.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color("BBMSBlack"))
            }
            
            Spacer()
            
            // Count and percentage
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(count)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? Color(status.color) : Color("BBMSBlack"))
                
                Text("\(Int(percentage * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color(status.color).opacity(0.1) : Color.clear)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Compact Status Card
struct CompactStatusCard: View {
    let status: Device.DeviceStatus
    let count: Int
    let total: Int
    let animateChart: Bool
    
    @State private var animateScale = false
    
    private var percentage: Double {
        total > 0 ? Double(count) / Double(total) : 0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon with progress ring
            ZStack {
                Circle()
                    .stroke(Color(status.color).opacity(0.2), lineWidth: 3)
                    .frame(width: 32, height: 32)
                
                Circle()
                    .trim(from: 0, to: animateChart ? percentage : 0)
                    .stroke(Color(status.color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0).delay(0.2), value: animateChart)
                
                Image(systemName: getStatusIcon(for: status))
                    .font(.caption)
                    .foregroundColor(Color(status.color))
                    .scaleEffect(animateScale ? 1.1 : 1.0)
                    .animation(.spring(response: 0.5), value: animateScale)
            }
            
            // Count
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(Color("BBMSBlack"))
            
            // Status label
            Text(status.rawValue)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.3))
        )
        .onAppear {
            withAnimation(.spring().delay(0.1)) {
                animateScale = true
            }
        }
    }
}

// MARK: - System Insights Section
struct SystemInsightsSection: View {
    let statusCounts: [Device.DeviceStatus: Int]
    let healthScore: Int
    
    private var criticalDevices: Int { statusCounts[.critical] ?? 0 }
    private var warningDevices: Int { statusCounts[.warning] ?? 0 }
    private var onlineDevices: Int { statusCounts[.online] ?? 0 }
    private var totalDevices: Int { statusCounts.values.reduce(0, +) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("System Insights")
                .font(.headline)
                .foregroundColor(Color("BBMSBlack"))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                InsightCard(
                    title: "System Health",
                    value: "\(healthScore)%",
                    icon: "heart.fill",
                    color: healthScore > 80 ? .green : healthScore > 60 ? .orange : .red,
                    insight: getHealthInsight(score: healthScore)
                )
                
                InsightCard(
                    title: "Critical Issues",
                    value: "\(criticalDevices)",
                    icon: "exclamationmark.triangle.fill",
                    color: criticalDevices == 0 ? .green : .red,
                    insight: criticalDevices == 0 ? "All systems stable" : "Requires attention"
                )
                
                InsightCard(
                    title: "Efficiency Rate",
                    value: "\(Int(Double(onlineDevices) / Double(max(totalDevices, 1)) * 100))%",
                    icon: "speedometer",
                    color: Color("BBMSGold"),
                    insight: "Optimal performance"
                )
                
                InsightCard(
                    title: "Response Time",
                    value: "0.8s",
                    icon: "timer",
                    color: .blue,
                    insight: "Within normal range"
                )
            }
            
            // Quick actions
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Run Diagnostics",
                    icon: "stethoscope",
                    color: Color("BBMSGold")
                ) {
                    // Handle diagnostics
                }
                
                QuickActionButton(
                    title: "Refresh All",
                    icon: "arrow.clockwise",
                    color: .blue
                ) {
                    // Handle refresh
                }
            }
        }
    }
    
    private func getHealthInsight(score: Int) -> String {
        switch score {
        case 90...100: return "Excellent"
        case 80..<90: return "Good"
        case 60..<80: return "Fair"
        default: return "Poor"
        }
    }
}

// MARK: - Insight Card
struct InsightCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let insight: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(color)
                
                Spacer()
                
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(Color("BBMSBlack"))
                .fontWeight(.medium)
            
            Text(insight)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Modern Status Indicator
struct ModernStatusIndicator: View {
    let status: Device.DeviceStatus
    let count: Int
    let isHighlighted: Bool
    let animateChart: Bool
    
    @State private var animateCount = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Animated circular progress
            ZStack {
                Circle()
                    .stroke(Color(status.color).opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: animateChart ? min(Double(count) / 10.0, 1.0) : 0)
                    .stroke(
                        Color(status.color),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0).delay(0.2), value: animateChart)
                
                Image(systemName: getStatusIcon(for: status))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(status.color))
                    .scaleEffect(isHighlighted ? 1.2 : 1.0)
                    .animation(.spring(), value: isHighlighted)
            }
            
            VStack(spacing: 4) {
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(isHighlighted ? Color(status.color) : Color("BBMSBlack"))
                    .scaleEffect(animateCount ? 1.1 : 1.0)
                    .animation(.spring(response: 0.5), value: animateCount)
                
                Text(status.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isHighlighted ? Color(status.color).opacity(0.1) : Color(.systemGray6).opacity(0.3))
                .animation(.easeInOut(duration: 0.3), value: isHighlighted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isHighlighted ? Color(status.color).opacity(0.4) : Color.clear,
                    lineWidth: 2
                )
                .animation(.easeInOut(duration: 0.3), value: isHighlighted)
        )
        .onAppear {
            withAnimation(.spring().delay(0.1)) {
                animateCount = true
            }
        }
    }
}

// MARK: - Device List Section
struct DeviceListSection: View {
    let devices: [Device]
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(Color("BBMSBlack"))
            
            if devices.isEmpty {
                Text("No devices found")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical)
            } else {
                ForEach(devices.prefix(3)) { device in
                    ModernDeviceRow(device: device)
                }
                
                if devices.count > 3 {
                    Button("View All (\(devices.count))") {
                        // Navigation to full device list
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color("BBMSGold"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                }
            }
        }
    }
}

// MARK: - Modern Device Row
struct ModernDeviceRow: View {
    let device: Device
    
    var body: some View {
        HStack(spacing: 16) {
            // Device icon with status
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(device.status.color).opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: device.typeIcon)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(Color(device.status.color))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("BBMSBlack"))
                
                Text(device.location)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(device.status.rawValue.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(device.status.color).opacity(0.2))
                    .foregroundColor(Color(device.status.color))
                    .clipShape(Capsule())
                
                Text("2m ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Recent Activity Section
struct RecentActivitySection: View {
    @ObservedObject var deviceService: DeviceService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .foregroundColor(Color("BBMSBlack"))
            
            VStack(spacing: 8) {
                ActivityItem(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    title: "HVAC System Online",
                    subtitle: "Floor 3 - East Wing",
                    timestamp: "2m ago"
                )
                
                ActivityItem(
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    title: "Temperature Warning",
                    subtitle: "Conference Room A",
                    timestamp: "5m ago"
                )
                
                ActivityItem(
                    icon: "person.fill.checkmark",
                    color: .blue,
                    title: "Access Granted",
                    subtitle: "Main Lobby",
                    timestamp: "8m ago"
                )
            }
        }
    }
}

// MARK: - Activity Item
struct ActivityItem: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let timestamp: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color("BBMSBlack"))
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(timestamp)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Interactive Alerts Card
struct InteractiveAlertsCard: View {
    @ObservedObject var deviceService: DeviceService
    @State private var selectedPriority: AlertPriority = .all
    @State private var showingAllAlerts = false
    
    enum AlertPriority: String, CaseIterable {
        case all = "All"
        case critical = "Critical"
        case warning = "Warning"
        case info = "Info"
        
        var color: Color {
            switch self {
            case .all: return Color("BBMSBlack")
            case .critical: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
    }
    
    var body: some View {
        let criticalDevices = deviceService.getCriticalDevices()
        
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart Alerts")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Color("BBMSBlack"))
                    
                    Text("AI-powered monitoring")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Priority filter
                Menu {
                    ForEach(AlertPriority.allCases, id: \.self) { priority in
                        Button(priority.rawValue) {
                            selectedPriority = priority
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedPriority.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(selectedPriority.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
            }
            
            if criticalDevices.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    
                    Text("All Systems Operational")
                        .font(.headline)
                        .foregroundColor(Color("BBMSBlack"))
                    
                    Text("No critical alerts detected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(criticalDevices.prefix(showingAllAlerts ? criticalDevices.count : 3)) { device in
                        SmartAlertRow(device: device)
                    }
                }
                
                if criticalDevices.count > 3 && !showingAllAlerts {
                    Button("Show All (\(criticalDevices.count))") {
                        withAnimation(.spring()) {
                            showingAllAlerts = true
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color("BBMSGold"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 25, x: 0, y: 12)
        )
    }
}

// MARK: - Smart Alert Row
struct SmartAlertRow: View {
    let device: Device
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Alert severity indicator
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color(device.status.color))
                        .frame(width: 12, height: 12)
                        .scaleEffect(1.0)
                        .animation(
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: Date().timeIntervalSince1970
                        )
                    
                    Rectangle()
                        .fill(Color(device.status.color).opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: isExpanded ? 40 : 0)
                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: device.typeIcon)
                            .font(.title3)
                            .foregroundColor(Color(device.status.color))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("BBMSBlack"))
                            
                            Text(device.location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(device.status.rawValue.uppercased())
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(device.status.color).opacity(0.2))
                                .foregroundColor(Color(device.status.color))
                                .clipShape(Capsule())
                            
                            Button(action: { isExpanded.toggle() }) {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if isExpanded {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recommended Actions:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("• Check sensor calibration")
                                Text("• Verify power connection")
                                Text("• Contact maintenance team")
                            }
                            .font(.caption)
                            .foregroundColor(Color("BBMSBlack"))
                            
                            HStack(spacing: 8) {
                                Button("Acknowledge") {
                                    // Handle acknowledgment
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color("BBMSGold").opacity(0.2))
                                .foregroundColor(Color("BBMSGold"))
                                .clipShape(Capsule())
                                
                                Button("Escalate") {
                                    // Handle escalation
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.2))
                                .foregroundColor(.red)
                                .clipShape(Capsule())
                            }
                            .padding(.top, 4)
                        }
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(device.status.color).opacity(0.05))
            )
            .onTapGesture {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            }
        }
    }
}
// MARK: - Smart Reservations Card
struct SmartReservationsCard: View {
    @ObservedObject var zoneService: ZoneService
    @State private var selectedTimeframe: TimeFrame = .today
    @State private var showingCalendar = false
    
    enum TimeFrame: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
    }
    
    var body: some View {
        let todaysReservations = zoneService.getTodaysReservations()
        
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart Bookings")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Color("BBMSBlack"))
                    
                    Text("Intelligent scheduling")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { showingCalendar.toggle() }) {
                    Image(systemName: "calendar")
                        .font(.title3)
                        .foregroundColor(Color("BBMSGold"))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            
            // Time-based navigation
            HStack(spacing: 0) {
                ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                    Button(action: { selectedTimeframe = timeframe }) {
                        Text(timeframe.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedTimeframe == timeframe ? .white : Color("BBMSBlack"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedTimeframe == timeframe ? 
                                Color("BBMSGold") : Color.clear
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(4)
            .background(Color(.systemGray6).opacity(0.5))
            .clipShape(Capsule())
            
            if todaysReservations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.largeTitle)
                        .foregroundColor(Color("BBMSGold"))
                    
                    Text("No Bookings Today")
                        .font(.headline)
                        .foregroundColor(Color("BBMSBlack"))
                    
                    Text("Perfect time to schedule meetings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Quick Book") {
                        // Handle quick booking
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color("BBMSGold"))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Timeline view
                VStack(spacing: 0) {
                    ForEach(Array(todaysReservations.enumerated()), id: \.element.id) { index, reservation in
                        TimelineReservationRow(
                            reservation: reservation,
                            isLast: index == todaysReservations.count - 1
                        )
                    }
                }
            }
            
            // Quick stats for reservations
            HStack(spacing: 20) {
                QuickStatBadge(
                    title: "Occupancy",
                    value: "78%",
                    color: .green
                )
                
                QuickStatBadge(
                    title: "Avg Duration",
                    value: "1.5h",
                    color: .blue
                )
                
                QuickStatBadge(
                    title: "Peak Time",
                    value: "2-4 PM",
                    color: Color("BBMSGold")
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 25, x: 0, y: 12)
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Timeline Reservation Row
struct TimelineReservationRow: View {
    let reservation: Reservation
    let isLast: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(Color(reservation.status.color))
                    .frame(width: 12, height: 12)
                
                if !isLast {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 2, height: 40)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reservation.userName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color("BBMSBlack"))
                        
                        Text(reservation.purpose)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatTime(reservation.startTime))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color("BBMSBlack"))
                        
                        Text(reservation.status.rawValue.uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(reservation.status.color).opacity(0.2))
                            .foregroundColor(Color(reservation.status.color))
                            .clipShape(Capsule())
                    }
                }
                
                // AI suggestions
                if reservation.status == .confirmed {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(Color("BBMSGold"))
                        
                        Text("Extend for 30 min?")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Yes") {
                            // Handle extension
                        }
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color("BBMSGold").opacity(0.2))
                        .foregroundColor(Color("BBMSGold"))
                        .clipShape(Capsule())
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Quick Stat Badge
struct QuickStatBadge: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Analytics Insights Card
struct AnalyticsInsightsCard: View {
    @ObservedObject var deviceService: DeviceService
    @ObservedObject var zoneService: ZoneService
    @State private var selectedMetric: AnalyticsMetric = .efficiency
    
    enum AnalyticsMetric: String, CaseIterable {
        case efficiency = "Efficiency"
        case usage = "Usage"
        case energy = "Energy"
        case security = "Security"
        
        var icon: String {
            switch self {
            case .efficiency: return "speedometer"
            case .usage: return "chart.bar.fill"
            case .energy: return "bolt.fill"
            case .security: return "shield.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .efficiency: return .green
            case .usage: return .blue
            case .energy: return Color("BBMSGold")
            case .security: return .purple
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Insights")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Color("BBMSBlack"))
                    
                    Text("Predictive analytics")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(Color("BBMSGold"))
            }
            
            // Metric selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AnalyticsMetric.allCases, id: \.self) { metric in
                        MetricSelector(
                            metric: metric,
                            isSelected: selectedMetric == metric
                        ) {
                            selectedMetric = metric
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // Insights based on selected metric
            InsightView(for: selectedMetric)
            
            // Action recommendations
            VStack(alignment: .leading, spacing: 8) {
                Text("Recommendations")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("BBMSBlack"))
                
                RecommendationItem(
                    icon: "lightbulb.fill",
                    text: "Optimize HVAC schedule to save 15% energy",
                    priority: .high
                )
                
                RecommendationItem(
                    icon: "calendar.badge.clock",
                    text: "Schedule maintenance for elevator system",
                    priority: .medium
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 25, x: 0, y: 12)
        )
    }
}

// MARK: - Metric Selector
struct MetricSelector: View {
    let metric: AnalyticsInsightsCard.AnalyticsMetric
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: metric.icon)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .white : metric.color)
                
                Text(metric.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : Color("BBMSBlack"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isSelected ? metric.color : metric.color.opacity(0.1)
            )
            .clipShape(Capsule())
        }
    }
}

// MARK: - Insight View
struct InsightView: View {
    let metric: AnalyticsInsightsCard.AnalyticsMetric
    
    init(for metric: AnalyticsInsightsCard.AnalyticsMetric) {
        self.metric = metric
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(getInsightTitle())
                    .font(.headline)
                    .foregroundColor(Color("BBMSBlack"))
                
                Spacer()
                
                Text(getInsightValue())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(metric.color)
            }
            
            // Progress visualization
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(metric.color.opacity(0.2))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(metric.color)
                        .frame(width: geometry.size.width * getProgressValue(), height: 12)
                }
            }
            .frame(height: 12)
            
            Text(getInsightDescription())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private func getInsightTitle() -> String {
        switch metric {
        case .efficiency: return "System Efficiency"
        case .usage: return "Space Utilization"
        case .energy: return "Energy Consumption"
        case .security: return "Security Status"
        }
    }
    
    private func getInsightValue() -> String {
        switch metric {
        case .efficiency: return "94%"
        case .usage: return "78%"
        case .energy: return "12.5 kWh"
        case .security: return "100%"
        }
    }
    
    private func getProgressValue() -> Double {
        switch metric {
        case .efficiency: return 0.94
        case .usage: return 0.78
        case .energy: return 0.65
        case .security: return 1.0
        }
    }
    
    private func getInsightDescription() -> String {
        switch metric {
        case .efficiency: return "Systems running optimally with minimal waste"
        case .usage: return "Higher than average occupancy this week"
        case .energy: return "Consumption trending down 8% vs last month"
        case .security: return "All access points secure and monitored"
        }
    }
}

// MARK: - Recommendation Item
struct RecommendationItem: View {
    let icon: String
    let text: String
    let priority: Priority
    
    enum Priority {
        case high, medium, low
        
        var color: Color {
            switch self {
            case .high: return .red
            case .medium: return .orange
            case .low: return .green
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(priority.color)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(Color("BBMSBlack"))
            
            Spacer()
            
            Circle()
                .fill(priority.color)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}
// MARK: - Performance Metrics Grid
struct PerformanceMetricsGrid: View {
    @ObservedObject var deviceService: DeviceService
    @ObservedObject var zoneService: ZoneService
    @State private var animateMetrics = false
    
    private var systemHealth: Int {
        let statusCounts = deviceService.getDeviceStatusCounts()
        let totalDevices = statusCounts.values.reduce(0, +)
        guard totalDevices > 0 else { return 100 }
        
        let onlineDevices = statusCounts[.online] ?? 0
        let warningDevices = statusCounts[.warning] ?? 0
        let criticalDevices = statusCounts[.critical] ?? 0
        let offlineDevices = statusCounts[.offline] ?? 0
        
        let healthScore = (onlineDevices * 100 + warningDevices * 70 + criticalDevices * 20 + offlineDevices * 0) / totalDevices
        return min(100, max(0, healthScore))
    }
    
    private var systemUptime: Double {
        let onlineDevices = deviceService.getDeviceStatusCounts()[.online] ?? 0
        let totalDevices = max(deviceService.devices.count, 1)
        return Double(onlineDevices) / Double(totalDevices) * 100
    }
    
    private var spaceUtilization: Double {
        let activeZones = zoneService.zones.filter { !$0.isAvailable }.count
        let totalZones = max(zoneService.zones.count, 1)
        return Double(activeZones) / Double(totalZones) * 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Overview")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Color("BBMSBlack"))
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                AdvancedMetricCard(
                    title: "System Uptime",
                    value: String(format: "%.1f%%", systemUptime),
                    subtitle: "Device availability",
                    trend: "+0.2%",
                    trendUp: true,
                    icon: "clock.arrow.circlepath",
                    color: systemUptime > 95 ? .green : systemUptime > 85 ? .orange : .red,
                    chartData: [92, 94, 96, 97, systemUptime]
                )
                
                AdvancedMetricCard(
                    title: "System Health",
                    value: "\(systemHealth)%",
                    subtitle: "Overall wellness",
                    trend: systemHealth > 85 ? "+5%" : "-2%",
                    trendUp: systemHealth > 85,
                    icon: "heart.fill",
                    color: systemHealth > 80 ? .green : systemHealth > 60 ? .orange : .red,
                    chartData: [78, 82, 85, 87, Double(systemHealth)]
                )
                
                AdvancedMetricCard(
                    title: "Space Utilization",
                    value: String(format: "%.0f%%", spaceUtilization),
                    subtitle: "Zone occupancy",
                    trend: "+5%",
                    trendUp: true,
                    icon: "building.2.fill",
                    color: .blue,
                    chartData: [70, 72, 75, 76, spaceUtilization]
                )
                
                AdvancedMetricCard(
                    title: "Response Time",
                    value: "0.8s",
                    subtitle: "Average latency",
                    trend: "-0.2s",
                    trendUp: true,
                    icon: "speedometer",
                    color: .purple,
                    chartData: [1.2, 1.1, 1.0, 0.9, 0.8]
                )
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4)) {
                animateMetrics = true
            }
        }
    }
}

// MARK: - Advanced Metric Card
struct AdvancedMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let trend: String
    let trendUp: Bool
    let icon: String
    let color: Color
    let chartData: [Double]
    
    @State private var animateChart = false
    @State private var showDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Spacer()
                
                Button(action: { showDetails.toggle() }) {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(Color("BBMSBlack"))
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Image(systemName: trendUp ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                        .foregroundColor(trendUp ? .green : .red)
                    
                    Text(trend)
                        .font(.caption)
                        .foregroundColor(trendUp ? .green : .red)
                        .fontWeight(.medium)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Mini sparkline chart
            GeometryReader { geometry in
                Path { path in
                    guard chartData.count > 1 else { return }
                    
                    let maxValue = chartData.max() ?? 1
                    let minValue = chartData.min() ?? 0
                    let range = maxValue - minValue
                    
                    let stepX = geometry.size.width / CGFloat(chartData.count - 1)
                    
                    for (index, value) in chartData.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedValue = range > 0 ? (value - minValue) / range : 0.5
                        let y = geometry.size.height - (CGFloat(normalizedValue) * geometry.size.height)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .trim(from: 0, to: animateChart ? 1 : 0)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [color, color.opacity(0.6)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
                .animation(.easeInOut(duration: 1.0).delay(0.2), value: animateChart)
            }
            .frame(height: 40)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            color.opacity(0.3),
                            color.opacity(0.1),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .scaleEffect(showDetails ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: showDetails)
        .onAppear {
            animateChart = true
        }
    }
}

// MARK: - Helper Structures
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Helper Functions
private func getStatusIcon(for status: Device.DeviceStatus) -> String {
    switch status {
    case .online: return "checkmark.circle.fill"
    case .offline: return "xmark.circle.fill"
    case .warning: return "exclamationmark.triangle.fill"
    case .critical: return "exclamationmark.octagon.fill"
    }
}

#Preview {
    DashboardView()
}
