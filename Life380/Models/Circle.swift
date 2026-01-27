import Foundation
import FirebaseFirestore

struct FamilyCircle: Identifiable, Codable {
    let id: String
    var name: String
    let createdBy: String
    var memberIds: [String]
    let inviteCode: String
    let createdAt: Date

    var dictionary: [String: Any] {
        [
            "id": id,
            "name": name,
            "createdBy": createdBy,
            "memberIds": memberIds,
            "inviteCode": inviteCode,
            "createdAt": createdAt
        ]
    }

    init(id: String, name: String, createdBy: String, memberIds: [String], inviteCode: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdBy = createdBy
        self.memberIds = memberIds
        self.inviteCode = inviteCode
        self.createdAt = createdAt
    }

    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let name = dictionary["name"] as? String,
              let createdBy = dictionary["createdBy"] as? String,
              let memberIds = dictionary["memberIds"] as? [String],
              let inviteCode = dictionary["inviteCode"] as? String else {
            return nil
        }

        self.id = id
        self.name = name
        self.createdBy = createdBy
        self.memberIds = memberIds
        self.inviteCode = inviteCode

        if let timestamp = dictionary["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else if let date = dictionary["createdAt"] as? Date {
            self.createdAt = date
        } else {
            self.createdAt = Date()
        }
    }
}
