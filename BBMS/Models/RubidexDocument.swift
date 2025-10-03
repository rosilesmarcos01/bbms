import Foundation

struct RubidexDocument: Identifiable, Codable, Equatable {
    let id: String
    let owner: String
    let collection_id: String
    let path_reference: String
    let doc_type: String
    let clearance: Int
    let fields: DocumentFields
    let creation_date: String
    let update_date: String
    
    // Equatable conformance
    static func == (lhs: RubidexDocument, rhs: RubidexDocument) -> Bool {
        return lhs.id == rhs.id &&
               lhs.creation_date == rhs.creation_date &&
               lhs.update_date == rhs.update_date &&
               lhs.fields == rhs.fields
    }
    
    var creationDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        // Try the primary format first
        if let date = formatter.date(from: creation_date) {
            return date
        }
        
        // Try alternative format without 'Z'
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: creation_date) {
            return date
        }
        
        return Date()
    }
    
    var updateDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        // Try the primary format first
        if let date = formatter.date(from: update_date) {
            return date
        }
        
        // Try alternative format without 'Z'
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: update_date) {
            return date
        }
        
        return Date()
    }
    
    var formattedCreationDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: creationDate)
    }
    
    var formattedUpdateDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: updateDate)
    }
}

struct DocumentFields: Codable, Equatable {
    let coreid: String
    let data: String  // Changed to String since API returns "test-event"
    let name: String
    let published_at: String
    let ttl: Int?  // Made optional since some documents don't have this field
    
    // Equatable conformance
    static func == (lhs: DocumentFields, rhs: DocumentFields) -> Bool {
        return lhs.coreid == rhs.coreid &&
               lhs.data == rhs.data &&
               lhs.name == rhs.name &&
               lhs.published_at == rhs.published_at &&
               lhs.ttl == rhs.ttl
    }
    
    var publishedDate: Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: published_at) ?? Date()
    }
    
    var formattedPublishedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: publishedDate)
    }
}

struct RubidexAPIResponse: Codable {
    let result: [RubidexDocument]
    let error: String?
    
    // Get the latest document by creation date
    var latestDocument: RubidexDocument? {
        return result.max { first, second in
            first.creationDate < second.creationDate
        }
    }
    
    // Get documents sorted by date (newest first)
    var sortedDocuments: [RubidexDocument] {
        return result.sorted { first, second in
            first.creationDate > second.creationDate
        }
    }
}