import Foundation
import Combine

class ZoneService: ObservableObject {
    @Published var zones: [Zone] = []
    
    init() {
        loadSampleData()
    }
    
    private func loadSampleData() {
        zones = [
            Zone(
                name: "Main Meeting room",
                type: .office,
                capacity: 2,
                isAvailable: true,
                amenities: ["Wi-Fi", "Desk", "Chair", "Phone"],
                reservations: []
            ),
            Zone(
                name: "Small Meeting room",
                type: .meetingRoom,
                capacity: 8,
                isAvailable: false,
                amenities: ["Projector", "Whiteboard", "Wi-Fi", "Conference Phone"],
                reservations: [
                    Reservation(
                        userId: "user1",
                        userName: "Dr. Oscar Chaparro",
                        startTime: Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date(),
                        endTime: Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date(),
                        purpose: "Team Standup",
                        status: .confirmed
                    )
                ]
            ),
            Zone(
                name: "Conference Room",
                type: .conferenceRoom,
                capacity: 20,
                isAvailable: true,
                amenities: ["Large Screen", "Audio System", "Wi-Fi", "Catering Setup"],
                reservations: [
                    Reservation(
                        userId: "user2",
                        userName: "Clay Perreault",
                        startTime: Calendar.current.date(byAdding: .hour, value: 3, to: Date()) ?? Date(),
                        endTime: Calendar.current.date(byAdding: .hour, value: 5, to: Date()) ?? Date(),
                        purpose: "Board Meeting",
                        status: .confirmed
                    )
                ]
            ),
            Zone(
                name: "Main Lobby",
                type: .lobby,
                capacity: 50,
                isAvailable: true,
                amenities: ["Reception Desk", "Seating Area", "Wi-Fi"],
                reservations: []
            ),
            Zone(
                name: "Break Room",
                type: .breakRoom,
                capacity: 15,
                isAvailable: true,
                amenities: ["Kitchen", "Microwave", "Coffee Machine", "Tables"],
                reservations: []
            ),
            Zone(
                name: "Coworking Space",
                type: .coworkingSpace,
                capacity: 30,
                isAvailable: true,
                amenities: ["Hot Desks", "Wi-Fi", "Power Outlets", "Quiet Zone"],
                reservations: [
                    Reservation(
                        userId: "user3",
                        userName: "Marcos Rosiles",
                        startTime: Date(),
                        endTime: Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date(),
                        purpose: "Focus Work",
                        status: .confirmed
                    )
                ]
            )
        ]
    }
    
    func getAvailableZones() -> [Zone] {
        return zones.filter { $0.isAvailable }
    }
    
    func getZonesByType(_ type: Zone.ZoneType) -> [Zone] {
        return zones.filter { $0.type == type }
    }
    
    func makeReservation(for zoneId: UUID, reservation: Reservation) {
        if let index = zones.firstIndex(where: { $0.id == zoneId }) {
            zones[index].reservations.append(reservation)
            checkZoneAvailability(for: index)
        }
    }
    
    func cancelReservation(zoneId: UUID, reservationId: UUID) {
        if let zoneIndex = zones.firstIndex(where: { $0.id == zoneId }),
           let reservationIndex = zones[zoneIndex].reservations.firstIndex(where: { $0.id == reservationId }) {
            zones[zoneIndex].reservations[reservationIndex] = Reservation(
                userId: zones[zoneIndex].reservations[reservationIndex].userId,
                userName: zones[zoneIndex].reservations[reservationIndex].userName,
                startTime: zones[zoneIndex].reservations[reservationIndex].startTime,
                endTime: zones[zoneIndex].reservations[reservationIndex].endTime,
                purpose: zones[zoneIndex].reservations[reservationIndex].purpose,
                status: .cancelled
            )
            checkZoneAvailability(for: zoneIndex)
        }
    }
    
    private func checkZoneAvailability(for index: Int) {
        let now = Date()
        let activeReservations = zones[index].reservations.filter {
            $0.status == .confirmed && $0.startTime <= now && $0.endTime >= now
        }
        zones[index].isAvailable = activeReservations.isEmpty
    }
    
    func getTodaysReservations() -> [Reservation] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        return zones.flatMap { $0.reservations }.filter {
            $0.startTime >= today && $0.startTime < tomorrow && $0.status != .cancelled
        }.sorted { $0.startTime < $1.startTime }
    }
}
