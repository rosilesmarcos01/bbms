import Foundation

struct RubidexDocument: Identifiable, Codable, Equatable {
    let id: String
    let owner: String?
    let collection_id: String?
    let path_reference: String?
    let doc_type: String?
    let clearance: Int?
    let fields: DocumentFields
    let creation_date: String
    let update_date: String
    
    // Custom decoder to handle inconsistent data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        id = try container.decode(String.self, forKey: .id)
        fields = try container.decode(DocumentFields.self, forKey: .fields)
        
        // Date fields - required but with fallbacks
        creation_date = try container.decodeIfPresent(String.self, forKey: .creation_date) ?? ""
        update_date = try container.decodeIfPresent(String.self, forKey: .update_date) ?? ""
        
        // Optional fields
        owner = try container.decodeIfPresent(String.self, forKey: .owner)
        collection_id = try container.decodeIfPresent(String.self, forKey: .collection_id)
        path_reference = try container.decodeIfPresent(String.self, forKey: .path_reference)
        doc_type = try container.decodeIfPresent(String.self, forKey: .doc_type)
        clearance = try container.decodeIfPresent(Int.self, forKey: .clearance)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fields, forKey: .fields)
        try container.encode(creation_date, forKey: .creation_date)
        try container.encode(update_date, forKey: .update_date)
        try container.encodeIfPresent(owner, forKey: .owner)
        try container.encodeIfPresent(collection_id, forKey: .collection_id)
        try container.encodeIfPresent(path_reference, forKey: .path_reference)
        try container.encodeIfPresent(doc_type, forKey: .doc_type)
        try container.encodeIfPresent(clearance, forKey: .clearance)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, owner, collection_id, path_reference, doc_type, clearance, fields, creation_date, update_date
    }
    
    // Equatable conformance
    static func == (lhs: RubidexDocument, rhs: RubidexDocument) -> Bool {
        return lhs.id == rhs.id &&
               lhs.creation_date == rhs.creation_date &&
               lhs.update_date == rhs.update_date &&
               lhs.fields == rhs.fields
    }
    
    var creationDate: Date {
        guard !creation_date.isEmpty else { return Date() }
        
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
        guard !update_date.isEmpty else { return Date() }
        
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
    let coreid: String?
    let data: String
    let name: String?
    let published_at: String?
    let ttl: Int?
    
    // Handle missing and inconsistent fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle data field (required, but fallback to empty string)
        data = try container.decodeIfPresent(String.self, forKey: .data) ?? ""
        
        // All other fields are optional with fallbacks
        coreid = try container.decodeIfPresent(String.self, forKey: .coreid)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        published_at = try container.decodeIfPresent(String.self, forKey: .published_at)
        
        // ttl can be Int or String, handle both
        if let ttlInt = try container.decodeIfPresent(Int.self, forKey: .ttl) {
            ttl = ttlInt
        } else if let ttlString = try container.decodeIfPresent(String.self, forKey: .ttl),
                  let ttlFromString = Int(ttlString) {
            ttl = ttlFromString
        } else {
            ttl = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        try container.encodeIfPresent(coreid, forKey: .coreid)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(published_at, forKey: .published_at)
        try container.encodeIfPresent(ttl, forKey: .ttl)
    }
    
    private enum CodingKeys: String, CodingKey {
        case coreid, data, name, published_at, ttl
    }
    
    // Equatable conformance
    static func == (lhs: DocumentFields, rhs: DocumentFields) -> Bool {
        return lhs.coreid == rhs.coreid &&
               lhs.data == rhs.data &&
               lhs.name == rhs.name &&
               lhs.published_at == rhs.published_at &&
               lhs.ttl == rhs.ttl
    }
    
    var publishedDate: Date {
        guard let published_at = published_at, !published_at.isEmpty else {
            // If no published_at field, use current date as fallback
            return Date()
        }
        
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: published_at) ?? Date()
    }
    
    var formattedPublishedDate: String {
        guard let published_at = published_at, !published_at.isEmpty else {
            return "Not Available"
        }
        
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