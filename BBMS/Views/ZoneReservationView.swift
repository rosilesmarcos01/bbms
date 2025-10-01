import SwiftUI

struct ZoneReservationView: View {
    @StateObject private var zoneService = ZoneService()
    @State private var selectedZoneType: Zone.ZoneType? = nil
    @State private var showingReservationForm = false
    @State private var selectedZone: Zone? = nil
    
    var filteredZones: [Zone] {
        if let selectedType = selectedZoneType {
            return zoneService.zones.filter { $0.type == selectedType }
        }
        return zoneService.zones
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Modern Header
                ModernReservationHeader()
                
                VStack(spacing: 0) {
                    // Filter Options
                    ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(
                            title: "All Zones",
                            isSelected: selectedZoneType == nil,
                            action: { selectedZoneType = nil }
                        )
                        
                        ForEach(Zone.ZoneType.allCases, id: \.self) { type in
                            FilterChip(
                                title: type.rawValue,
                                isSelected: selectedZoneType == type,
                                action: { selectedZoneType = type }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                
                // Zone List
                List {
                    ForEach(filteredZones) { zone in
                        ZoneRowView(zone: zone) {
                            selectedZone = zone
                            showingReservationForm = true
                        }
                        .listRowBackground(Color("BBMSWhite"))
                    }
                }
                .background(.gray.opacity(0.1))
            }
            }
            .background(.gray.opacity(0.1))
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New Reservation") {
                        showingReservationForm = true
                    }
                    .foregroundColor(Color("BBMSGold"))
                }
            }
            .sheet(isPresented: $showingReservationForm) {
                ReservationFormView(
                    zone: selectedZone,
                    zoneService: zoneService,
                    isPresented: $showingReservationForm
                )
            }
        }
    }
}

struct ZoneRowView: View {
    let zone: Zone
    let onReserve: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Zone Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(zone.isAvailable ? Color("BBMSGold").opacity(0.2) : Color.red.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: zone.typeIcon)
                        .foregroundColor(zone.isAvailable ? Color("BBMSGold") : .red)
                        .font(.title3)
                }
                
                // Zone Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(zone.name)
                        .font(.headline)
                        .foregroundColor(Color("BBMSBlack"))
                    
                    Text(zone.type.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    HStack {
                        Text("Capacity: \(zone.capacity)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text(zone.isAvailable ? "Available" : "Occupied")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(zone.isAvailable ? Color("BBMSGold").opacity(0.2) : Color.red.opacity(0.2))
                            .foregroundColor(zone.isAvailable ? Color("BBMSGold") : .red)
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                if zone.isAvailable {
                    Button("Reserve") {
                        onReserve()
                    }
                    .foregroundColor(Color("BBMSGold"))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            // Amenities
            if !zone.amenities.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(zone.amenities, id: \.self) { amenity in
                            Text(amenity)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Current Reservations
            if !zone.reservations.filter({ $0.status != .cancelled }).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reservations")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color("BBMSBlack"))
                    
                    ForEach(zone.reservations.filter({ $0.status != .cancelled }).prefix(2)) { reservation in
                        ReservationRowView(reservation: reservation)
                    }
                    
                    if zone.reservations.filter({ $0.status != .cancelled }).count > 2 {
                        Text("+ \(zone.reservations.filter({ $0.status != .cancelled }).count - 2) more")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color("BBMSWhite"))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct ReservationRowView: View {
    let reservation: Reservation
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(reservation.userName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color("BBMSBlack"))
                
                Text(reservation.purpose)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTimeRange(start: reservation.startTime, end: reservation.endTime))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color("BBMSBlack"))
                
                Text(reservation.status.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(reservation.status.color).opacity(0.2))
                    .foregroundColor(Color(reservation.status.color))
                    .cornerRadius(6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

struct ReservationFormView: View {
    let zone: Zone?
    @ObservedObject var zoneService: ZoneService
    @Binding var isPresented: Bool
    
    @State private var selectedZone: Zone?
    @State private var userName = ""
    @State private var purpose = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600) // 1 hour later
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Zone Selection") {
                    if let zone = zone {
                        HStack {
                            Image(systemName: zone.typeIcon)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(zone.name)
                                    .fontWeight(.medium)
                                Text(zone.type.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("Selected")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    } else {
                        Picker("Select Zone", selection: $selectedZone) {
                            Text("Choose a zone").tag(nil as Zone?)
                            ForEach(zoneService.getAvailableZones()) { zone in
                                HStack {
                                    Image(systemName: zone.typeIcon)
                                    Text(zone.name)
                                }.tag(zone as Zone?)
                            }
                        }
                    }
                }
                
                Section("Reservation Details") {
                    TextField("Your Name", text: $userName)
                    TextField("Purpose", text: $purpose)
                    
                    DatePicker("Start Time", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End Time", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section {
                    Button("Create Reservation") {
                        createReservation()
                    }
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("New Reservation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .alert("Reservation Status", isPresented: $showingAlert) {
                Button("OK") {
                    if alertMessage.contains("successfully") {
                        isPresented = false
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                if let zone = zone {
                    selectedZone = zone
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !userName.isEmpty &&
        !purpose.isEmpty &&
        (selectedZone != nil || zone != nil) &&
        endDate > startDate
    }
    
    private func createReservation() {
        guard let targetZone = zone ?? selectedZone else {
            alertMessage = "Please select a zone"
            showingAlert = true
            return
        }
        
        let reservation = Reservation(
            userId: "current_user",
            userName: userName,
            startTime: startDate,
            endTime: endDate,
            purpose: purpose,
            status: .confirmed
        )
        
        zoneService.makeReservation(for: targetZone.id, reservation: reservation)
        
        alertMessage = "Reservation created successfully!"
        showingAlert = true
    }
}

struct ModernReservationHeader: View {
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
                    
                    Image(systemName: "calendar.badge.clock")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Zone Reservations")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color("BBMSBlack"))
                    
                    Text("Booking & Scheduling")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Add Button
                Button(action: {}) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color("BBMSGold"))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "plus")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
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

#Preview {
    ZoneReservationView()
}
