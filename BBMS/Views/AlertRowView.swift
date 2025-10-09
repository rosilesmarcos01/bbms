import SwiftUI

struct AlertRowView: View {
    let alert: Alert
    let alertService: AlertService
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            if !alert.isRead {
                alertService.markAsRead(alert)
            }
            showingDetail = true
        }) {
            HStack(spacing: 16) {
                // Status indicator and icon
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(alert.severity.color.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: alert.severity.icon)
                            .font(.title3)
                            .foregroundColor(alert.severity.color)
                    }
                    
                    if !alert.isRead {
                        Circle()
                            .fill(Color("BBMSGold"))
                            .frame(width: 8, height: 8)
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(alert.title)
                            .font(.headline)
                            .fontWeight(alert.isRead ? .medium : .semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if alert.isResolved {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Text(alert.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 12) {
                        // Category badge
                        HStack(spacing: 4) {
                            Image(systemName: alert.category.icon)
                                .font(.caption2)
                            
                            Text(alert.category.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color("BBMSGold").opacity(0.1))
                        .foregroundColor(Color("BBMSGold"))
                        .clipShape(Capsule())
                        
                        Spacer()
                        
                        // Timestamp
                        Text(alert.timeAgo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Chevron or Quick Action Button
                if !alert.isResolved {
                    Button(action: {
                        alertService.markAsResolved(alert)
                    }) {
                        Image(systemName: "checkmark.circle")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !alert.isResolved {
                Button {
                    alertService.markAsResolved(alert)
                } label: {
                    Label("Resolve", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            }
            
            if !alert.isRead {
                Button {
                    alertService.markAsRead(alert)
                } label: {
                    Label("Mark Read", systemImage: "envelope.open.fill")
                }
                .tint(.blue)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                showingDetail = true
            } label: {
                Label("Details", systemImage: "info.circle.fill")
            }
            .tint(Color("BBMSGold"))
        }
        .sheet(isPresented: $showingDetail) {
            AlertDetailView(alert: alert, alertService: alertService)
        }
    }
}

struct AlertDetailView: View {
    let alert: Alert
    let alertService: AlertService
    @Environment(\.dismiss) private var dismiss
    @State private var showingActions = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(alert.severity.color.opacity(0.1))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: alert.severity.icon)
                                    .font(.title)
                                    .foregroundColor(alert.severity.color)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                if alert.isResolved {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Resolved")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.green)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                                
                                Text(alert.timeAgo)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text(alert.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 16) {
                            // Severity badge
                            HStack(spacing: 6) {
                                Image(systemName: alert.severity.icon)
                                    .font(.caption)
                                
                                Text(alert.severity.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(alert.severity.color.opacity(0.1))
                            .foregroundColor(alert.severity.color)
                            .clipShape(Capsule())
                            
                            // Category badge
                            HStack(spacing: 6) {
                                Image(systemName: alert.category.icon)
                                    .font(.caption)
                                
                                Text(alert.category.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color("BBMSGold").opacity(0.1))
                            .foregroundColor(Color("BBMSGold"))
                            .clipShape(Capsule())
                        }
                    }
                    
                    Divider()
                    
                    // Message
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Details")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(alert.message)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                    
                    // Device/Zone info
                    if alert.deviceId != nil || alert.zoneId != nil {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Location & Device")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if let deviceId = alert.deviceId {
                                AlertInfoRow(title: "Device ID", value: deviceId, icon: "sensor.tag.radiowaves.forward")
                            }
                            
                            if let zoneId = alert.zoneId {
                                AlertInfoRow(title: "Zone", value: zoneId, icon: "location")
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Timestamp
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Timestamp")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(alert.timestamp.formatted(date: .complete, time: .shortened))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Alert Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color("BBMSGold"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingActions = true }) {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Color("BBMSGold"))
                    }
                }
            }
            .confirmationDialog("Alert Actions", isPresented: $showingActions) {
                if !alert.isResolved {
                    Button("Mark as Resolved") {
                        alertService.markAsResolved(alert)
                        dismiss()
                    }
                }
                
                Button("Delete Alert", role: .destructive) {
                    alertService.deleteAlert(alert)
                    dismiss()
                }
                
                Button("Cancel", role: .cancel) { }
            }
        }
    }
}

struct AlertInfoRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(Color("BBMSGold"))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    AlertRowView(alert: Alert.sampleAlerts[0], alertService: AlertService.shared)
}
