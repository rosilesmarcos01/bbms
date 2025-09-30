import SwiftUI

struct AlertsView: View {
    @StateObject private var alertService = AlertService()
    @State private var selectedSeverity: Alert.AlertSeverity? = nil
    @State private var selectedCategory: Alert.AlertCategory? = nil
    @State private var showingFilters = false
    @State private var searchText = ""
    
    var filteredAlerts: [Alert] {
        var alerts = alertService.getAlerts(for: selectedSeverity, category: selectedCategory)
        
        if !searchText.isEmpty {
            alerts = alerts.filter { alert in
                alert.title.localizedCaseInsensitiveContains(searchText) ||
                alert.message.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return alerts
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Modern Header
                ModernAlertsHeader(
                    unreadCount: alertService.unreadCount,
                    criticalCount: alertService.getCriticalAlerts().count,
                    onFilterTap: { showingFilters.toggle() },
                    onMarkAllRead: { alertService.markAllAsRead() }
                )
                
                // Search Bar
                SearchBar(searchText: $searchText)
                
                // Filter pills
                if selectedSeverity != nil || selectedCategory != nil {
                    activeFiltersView
                }
                
                // Alerts list
                if filteredAlerts.isEmpty {
                    emptyStateView
                } else {
                    alertsList
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingFilters) {
                FilterView(
                    selectedSeverity: $selectedSeverity,
                    selectedCategory: $selectedCategory
                )
            }
        }
    }
    
    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let severity = selectedSeverity {
                    FilterPill(
                        text: severity.displayName,
                        color: severity.color,
                        icon: severity.icon
                    ) {
                        selectedSeverity = nil
                    }
                }
                
                if let category = selectedCategory {
                    FilterPill(
                        text: category.displayName,
                        color: Color("BBMSGold"),
                        icon: category.icon
                    ) {
                        selectedCategory = nil
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var alertsList: some View {
        List {
            ForEach(filteredAlerts) { alert in
                AlertRowView(alert: alert, alertService: alertService)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            alertService.loadAlerts()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Alerts Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("All caught up! No alerts match your current filters.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if selectedSeverity != nil || selectedCategory != nil {
                Button("Clear Filters") {
                    selectedSeverity = nil
                    selectedCategory = nil
                }
                .foregroundColor(Color("BBMSGold"))
                .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FilterPill: View {
    let text: String
    let color: Color
    let icon: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
}

struct FilterView: View {
    @Binding var selectedSeverity: Alert.AlertSeverity?
    @Binding var selectedCategory: Alert.AlertCategory?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Severity") {
                    ForEach(Alert.AlertSeverity.allCases, id: \.self) { severity in
                        Button(action: {
                            selectedSeverity = selectedSeverity == severity ? nil : severity
                        }) {
                            HStack {
                                Image(systemName: severity.icon)
                                    .foregroundColor(severity.color)
                                
                                Text(severity.displayName)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedSeverity == severity {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color("BBMSGold"))
                                }
                            }
                        }
                    }
                }
                
                Section("Category") {
                    ForEach(Alert.AlertCategory.allCases, id: \.self) { category in
                        Button(action: {
                            selectedCategory = selectedCategory == category ? nil : category
                        }) {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(Color("BBMSGold"))
                                
                                Text(category.displayName)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedCategory == category {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color("BBMSGold"))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color("BBMSGold"))
                }
            }
        }
    }
}

struct ModernAlertsHeader: View {
    let unreadCount: Int
    let criticalCount: Int
    let onFilterTap: () -> Void
    let onMarkAllRead: () -> Void
    
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
                    
                    Image(systemName: "bell.badge")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alerts Center")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color("BBMSBlack"))
                    
                    HStack(spacing: 12) {
                        Text("\(unreadCount) unread")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if criticalCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                
                                Text("\(criticalCount) critical")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer()
                
                // Action Menu
                Menu {
                    Button(action: onFilterTap) {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    
                    Button(action: onMarkAllRead) {
                        Label("Mark All Read", systemImage: "envelope.open")
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "ellipsis")
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

struct SearchBar: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.title3)
            
            TextField("Search alerts...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
}

#Preview {
    AlertsView()
}