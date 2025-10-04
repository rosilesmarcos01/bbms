import SwiftUI

struct AlertsSheetView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var alertService = AlertService.shared
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
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color("BBMSGold"))
                }
            }
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
                .foregroundColor(.secondary)
            
            Text("No Alerts")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("All systems are running normally. New alerts will appear here when they occur.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}