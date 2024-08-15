import Foundation
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
struct ChatMessage: Codable, Identifiable {
    @DocumentID var id: String?
    let fromID, toID, text: String
    let timestamp: Date
}
