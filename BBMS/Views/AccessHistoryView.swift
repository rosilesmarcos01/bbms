import SwiftUI

struct AccessHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared
    @State private var accessHistory: [AccessLogEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFilter: AccessFilter = .all
    
    enum AccessFilter: String, CaseIterable {
        case all = "All"
        case biometric = "Biometric"
        case password = "Password"
        case buildingAccess = "Building Access"
        
        var icon: String {
            switch self {
            case .all:
                return "list.bullet"
            case .biometric:
                return "faceid"
            case .password:
                return "key"
            case .buildingAccess:
                return "building.2"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Picker
                filterPicker
                
                // Access History List
                if isLoading {
                    loadingView
                } else if accessHistory.isEmpty {
                    emptyStateView
                } else {
                    accessHistoryList
                }
            }
            .navigationTitle("Access History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadAccessHistory()
            }
        }
    }
    
    // MARK: - Filter Picker
    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AccessFilter.allCases, id: \.self) { filter in
                    AccessFilterChip(
                        title: filter.rawValue,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter,
                        action: {
                            selectedFilter = filter
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading access history...")
                .progressViewStyle(CircularProgressViewStyle())
            Spacer()
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Access History")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Your access history will appear here once you start using the system.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Access History List
    private var accessHistoryList: some View {
        List {
            ForEach(filteredAccessHistory, id: \.id) { entry in
                AccessHistoryRow(entry: entry)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 4)
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await loadAccessHistory()
        }
    }
    
    // MARK: - Filtered Access History
    private var filteredAccessHistory: [AccessLogEntry] {
        switch selectedFilter {
        case .all:
            return accessHistory
        case .biometric:
            return accessHistory.filter { $0.loginType.contains("biometric") }
        case .password:
            return accessHistory.filter { $0.loginType.contains("password") }
        case .buildingAccess:
            return accessHistory.filter { $0.loginType.contains("building_access") }
        }
    }
    
    // MARK: - Helper Methods
    private func loadAccessHistory() async {
        isLoading = true
        errorMessage = nil
        
        // Simulate API call - replace with actual auth service call
        do {
            // For now, we'll create mock data since the API endpoint needs to be implemented
            try await createMockAccessHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func createMockAccessHistory() async throws {
        // Mock data for demonstration
        let mockEntries = [
            AccessLogEntry(
                id: UUID().uuidString,
                loginType: "biometric_login",
                timestamp: Date().addingTimeInterval(-3600),
                ipAddress: "192.168.1.100",
                metadata: ["confidence": "0.95", "verificationId": "ver_123"]
            ),
            AccessLogEntry(
                id: UUID().uuidString,
                loginType: "password_login",
                timestamp: Date().addingTimeInterval(-7200),
                ipAddress: "192.168.1.100",
                metadata: [:]
            ),
            AccessLogEntry(
                id: UUID().uuidString,
                loginType: "building_access_entry",
                timestamp: Date().addingTimeInterval(-10800),
                ipAddress: "192.168.1.50",
                metadata: ["zoneId": "lobby", "method": "biometric"]
            ),
            AccessLogEntry(
                id: UUID().uuidString,
                loginType: "building_access_exit",
                timestamp: Date().addingTimeInterval(-14400),
                ipAddress: "192.168.1.50",
                metadata: ["zoneId": "office-general", "method": "card"]
            ),
            AccessLogEntry(
                id: UUID().uuidString,
                loginType: "biometric_login",
                timestamp: Date().addingTimeInterval(-86400),
                ipAddress: "192.168.1.100",
                metadata: ["confidence": "0.92", "verificationId": "ver_456"]
            )
        ]
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        accessHistory = mockEntries.sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Access Log Entry Model
struct AccessLogEntry {
    let id: String
    let loginType: String
    let timestamp: Date
    let ipAddress: String
    let metadata: [String: String]
}

// MARK: - Filter Chip
struct AccessFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color("BBMSBlue") : Color(.systemGray6))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Access History Row
struct AccessHistoryRow: View {
    let entry: AccessLogEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(accessTypeColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: accessTypeIcon)
                    .font(.system(size: 16))
                    .foregroundColor(accessTypeColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(accessTypeTitle)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(formatTimestamp(entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !entry.metadata.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(entry.metadata.prefix(2)), id: \.key) { key, value in
                            if key != "verificationId" {
                                MetadataPill(key: key, value: value)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Success indicator
            VStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - Access Type Properties
    private var accessTypeIcon: String {
        switch entry.loginType {
        case let type where type.contains("biometric"):
            return "faceid"
        case let type where type.contains("password"):
            return "key"
        case let type where type.contains("building_access"):
            return "building.2"
        default:
            return "person.circle"
        }
    }
    
    private var accessTypeColor: Color {
        switch entry.loginType {
        case let type where type.contains("biometric"):
            return Color("BBMSBlue")
        case let type where type.contains("password"):
            return .orange
        case let type where type.contains("building_access"):
            return .purple
        default:
            return .gray
        }
    }
    
    private var accessTypeTitle: String {
        switch entry.loginType {
        case "biometric_login":
            return "Biometric Login"
        case "password_login":
            return "Password Login"
        case "building_access_entry":
            return "Building Entry"
        case "building_access_exit":
            return "Building Exit"
        case let type where type.contains("biometric"):
            return "Biometric Action"
        default:
            return "Access Event"
        }
    }
    
    // MARK: - Helper Methods
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Metadata Pill
struct MetadataPill: View {
    let key: String
    let value: String
    
    var body: some View {
        Text(displayText)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
            )
            .foregroundColor(.secondary)
    }
    
    private var displayText: String {
        switch key {
        case "confidence":
            return "Confidence: \(Int((Double(value) ?? 0) * 100))%"
        case "zoneId":
            return "Zone: \(value.capitalized)"
        case "method":
            return "Method: \(value.capitalized)"
        default:
            return "\(key.capitalized): \(value)"
        }
    }
}

#Preview {
    AccessHistoryView()
}