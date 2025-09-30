import Foundation

struct Zone: Identifiable, Codable, Hashable {
    var id = UUID()
    let name: String
    let type: ZoneType
    let capacity: Int
    var isAvailable: Bool
    let amenities: [String]
    var reservations: [Reservation]
    
    enum ZoneType: String, CaseIterable, Codable {
        case office = "Office"
        case meetingRoom = "Meeting Room"
        case conferenceRoom = "Conference Room"
        case lobby = "Lobby"
        case breakRoom = "Break Room"
        case coworkingSpace = "Coworking Space"
    }
    
    var typeIcon: String {
        switch type {
        case .office: return "building.2.fill"
        case .meetingRoom: return "person.3.fill"
        case .conferenceRoom: return "person.crop.rectangle.stack.fill"
        case .lobby: return "door.left.hand.open"
        case .breakRoom: return "cup.and.saucer.fill"
        case .coworkingSpace: return "laptopcomputer"
        }
    }
}

struct Reservation: Identifiable, Codable, Hashable {
    var id = UUID()
    let userId: String
    let userName: String
    let startTime: Date
    let endTime: Date
    let purpose: String
    let status: ReservationStatus
    
    enum ReservationStatus: String, CaseIterable, Codable {
        case confirmed = "Confirmed"
        case pending = "Pending"
        case cancelled = "Cancelled"
        case completed = "Completed"
        
        var color: String {
            switch self {
            case .confirmed: return "green"
            case .pending: return "orange"
            case .cancelled: return "red"
            case .completed: return "blue"
            }
        }
    }
}