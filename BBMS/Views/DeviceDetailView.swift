import SwiftUI
import Charts

struct DeviceDetailView: View {
    let device: Device
    @State private var historicalData: [DeviceDataPoint] = []
    @State private var selectedTimeRange: TimeRange = .day
    
    enum TimeRange: String, CaseIterable {
        case hour = "1H"
        case day = "24H"
        case week = "7D"
        case month = "30D"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    // BMS Logo
                    Image("AppLogo")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Color("BBMSBlack"))
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 240, height: 80)
                    
                    VStack(spacing: 8) {
                        Text(device.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color("BBMSBlack"))
                            .multilineTextAlignment(.center)
                        
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            
                            Text(device.location)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color("BBMSWhite"))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                // Current Status Card
                VStack(spacing: 16) {
                    HStack {
                        Text("Current Status")
                            .font(.headline)
                            .foregroundColor(Color("BBMSBlack"))
                        
                        Spacer()
                        
                        HStack {
                            Image(systemName: device.statusIcon)
                                .foregroundColor(Color(device.status.color))
                            
                            Text(device.status.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Color("BBMSBlack"))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(device.status.color).opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Divider()
                        .background(Color("BBMSGold"))
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Current Value")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text("\(device.value, specifier: "%.1f") \(device.unit)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color("BBMSBlack"))
                        }
                        
                        HStack {
                            Text("Last Updated")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text(formatDate(device.lastUpdated))
                                .font(.subheadline)
                                .foregroundColor(Color("BBMSBlack"))
                        }
                    }
                }
                .padding()
                .background(Color("BBMSWhite"))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                // Time Range Selector
                VStack(spacing: 16) {
                    HStack {
                        Text("Historical Data")
                            .font(.headline)
                            .foregroundColor(Color("BBMSBlack"))
                        
                        Spacer()
                    }
                    
                    // Chart
                    if !historicalData.isEmpty {
                        Chart(historicalData) { dataPoint in
                            LineMark(
                                x: .value("Time", dataPoint.timestamp),
                                y: .value("Value", dataPoint.value)
                            )
                            .foregroundStyle(Color("BBMSGold"))
                            
                            AreaMark(
                                x: .value("Time", dataPoint.timestamp),
                                y: .value("Value", dataPoint.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color("BBMSGold").opacity(0.3), Color("BBMSGold").opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                        .frame(height: 200)
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .hour, count: timeAxisStride())) { value in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel {
                                    if let date = value.as(Date.self) {
                                        Text(formatAxisLabel(date))
                                            .font(.caption)
                                            .foregroundStyle(Color("BBMSBlack"))
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel {
                                    Text("\(value.as(Double.self) ?? 0, specifier: "%.0f")")
                                        .font(.caption)
                                        .foregroundStyle(Color("BBMSBlack"))
                                }
                            }
                        }
                        .chartBackground { chartProxy in
                            Rectangle()
                                .fill(Color("BBMSWhite"))
                        }
                        .padding()
                        .background(Color("BBMSWhite"))
                        .border(Color("BBMSGold"), width: 1)
                        .cornerRadius(12)
                    } else {
                        Text("Loading historical data...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                    }
                    
                    // Time Range Buttons
                    HStack(spacing: 12) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Button(action: { selectedTimeRange = range }) {
                                Text(range.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedTimeRange == range ? Color("BBMSWhite") : Color("BBMSBlack"))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedTimeRange == range ? Color("BBMSGold") : Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
                .background(Color("BBMSWhite"))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Device Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(.gray.opacity(0.05))
        .onAppear {
            loadHistoricalData()
        }
        .onChange(of: selectedTimeRange) {
            loadHistoricalData()
        }
    }
    
    private func statusColor(for status: Device.DeviceStatus) -> Color {
        switch status {
        case .online: return .green
        case .offline: return .gray
        case .warning: return .orange
        case .critical: return .red
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatAxisLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch selectedTimeRange {
        case .hour:
            formatter.dateFormat = "HH:mm"
        case .day:
            formatter.dateFormat = "HH:mm"
        case .week:
            formatter.dateFormat = "MM/dd"
        case .month:
            formatter.dateFormat = "MM/dd"
        }
        return formatter.string(from: date)
    }
    
    private func timeAxisStride() -> Int {
        switch selectedTimeRange {
        case .hour: return 1
        case .day: return 4
        case .week: return 24
        case .month: return 168 // 7 days
        }
    }
    
    private func loadHistoricalData() {
        // Simulate loading historical data
        let calendar = Calendar.current
        let endDate = Date()
        var startDate: Date
        var interval: TimeInterval
        
        switch selectedTimeRange {
        case .hour:
            startDate = calendar.date(byAdding: .hour, value: -1, to: endDate) ?? endDate
            interval = 300 // 5 minutes
        case .day:
            startDate = calendar.date(byAdding: .day, value: -1, to: endDate) ?? endDate
            interval = 3600 // 1 hour
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
            interval = 21600 // 6 hours
        case .month:
            startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
            interval = 86400 // 1 day
        }
        
        var data: [DeviceDataPoint] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            let baseValue = device.value
            let variation = Double.random(in: -5...5)
            let value = max(0, baseValue + variation)
            
            data.append(DeviceDataPoint(
                id: UUID(),
                timestamp: currentDate,
                value: value
            ))
            
            currentDate = currentDate.addingTimeInterval(interval)
        }
        
        historicalData = data
    }
}

struct DeviceDataPoint: Identifiable {
    let id: UUID
    let timestamp: Date
    let value: Double
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        DeviceDetailView(device: Device(
            name: "Temperature Sensor",
            type: .temperature,
            location: "Main Lobby",
            status: .online,
            value: 22.5,
            unit: "°C",
            lastUpdated: Date()
        ))
    }
}