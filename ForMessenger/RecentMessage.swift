import Foundation
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
struct RecentMessage: Codable, Identifiable {
    @DocumentID var id: String?
    let text, email: String
    let fromID, toID: String
    let profileImageURL: String
    let timestamp: Date
    var username: String {
        email.components(separatedBy: "@").first ?? email
    }
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
