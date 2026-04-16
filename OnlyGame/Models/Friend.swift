import Foundation

struct Friend: Identifiable {
    let id: Int           // friendship_id
    let userId: UUID      // the other person's UUID
    let username: String
    let status: String    // "Pending" | "Accepted"
    let isSentByMe: Bool  // true = I sent the request (user_id1 == me)
}
