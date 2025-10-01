import SwiftUI

struct DeviceMonitoringView: View {
    @StateObject private var deviceService = DeviceService()
    @State private var selectedDeviceType: Device.DeviceType? = nil
    @State private var searchText = ""
    
    var filteredDevices: [Device] {
        var devices = deviceService.devices
        
        if let selectedType = selectedDeviceType {
            devices = devices.filter { $0.type == selectedType }
        }
        
        if !searchText.isEmpty {
            devices = devices.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.location.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return devices
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Modern Header
                ModernDeviceHeader()
                
                // Search Bar
                SearchBarView(searchText: $searchText)
                
                // Filter Options
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedDeviceType == nil,
                            action: { selectedDeviceType = nil }
                        )
                        
                        ForEach(Device.DeviceType.allCases, id: \.self) { type in
                            FilterChip(
                                title: type.rawValue,
                                isSelected: selectedDeviceType == type,
                                action: { selectedDeviceType = type }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color("BBMSWhite"))
                
                // Device List
                List {
                    ForEach(filteredDevices) { device in
                        NavigationLink(destination: DeviceDetailView(device: device)) {
                            DeviceRowView(device: device)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    }
                }
                .listStyle(.plain)
                .background(Color(.systemGray6).opacity(0.3))
                .searchable(text: $searchText, prompt: "Search devices...")
            }
            .background(.gray.opacity(0.1))
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        // Refresh devices
                    }
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : Color("BBMSBlack"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(
                            isSelected 
                            ? LinearGradient(
                                gradient: Gradient(colors: [
                                    Color("BBMSGold"),
                                    Color("BBMSGold").opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(.systemGray6),
                                    Color(.systemGray6)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.clear : Color(.systemGray5), 
                            lineWidth: 0.5
                        )
                )
                .shadow(
                    color: isSelected ? Color("BBMSGold").opacity(0.3) : .clear,
                    radius: isSelected ? 8 : 0,
                    x: 0,
                    y: isSelected ? 4 : 0
                )
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct DeviceRowView: View {
    let device: Device
    
    var body: some View {
        HStack(spacing: 16) {
            // Modern Device Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(device.status.color).opacity(0.2),
                                Color(device.status.color).opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                VStack(spacing: 2) {
                    Image(systemName: device.deviceIcon)
                        .foregroundColor(getStatusColor(for: device.status))
                        .font(.title2)
                    
                    // Status indicator dot
                    Circle()
                        .fill(getStatusColor(for: device.status))
                        .frame(width: 6, height: 6)
                }
            }
            
            // Device Info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(device.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("BBMSBlack"))
                    
                    Spacer()
                    
                    // Status badge
                    Text(device.status.rawValue)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(device.status.color).opacity(0.15))
                        .foregroundColor(Color(device.status.color))
                        .cornerRadius(8)
                }
                
                HStack {
                    Image(systemName: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(device.location)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                HStack {
                    Text("\(device.value, specifier: "%.1f") \(device.unit)")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(Color("BBMSBlack"))
                    
                    Spacer()
                    
                    Text("Updated \(timeAgoString(from: device.lastUpdated))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray6), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }
    
    // Helper function to get proper SwiftUI colors for device status.
    private func getStatusColor(for status: Device.DeviceStatus) -> Color {
        switch status {
        case .online:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        case .offline:
            return .gray
        }
    }
}
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }


struct ModernDeviceHeader: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Modern Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color("BBMSGold"),
                                    Color("BBMSGold").opacity(0.8)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "network.badge.shield.half.filled")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Device Monitoring")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color("BBMSBlack"))
                    
                    Text("IoT Control Center")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Filter Button
                Button(action: {}) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.title3)
                            .foregroundColor(Color("BBMSBlack"))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
            
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 0.5)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color(.systemGray6).opacity(0.1)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct SearchBarView: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.title3)
            
            TextField("Search devices or locations...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}

#Preview {
    DeviceMonitoringView()
}
