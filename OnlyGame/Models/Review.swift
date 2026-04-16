import Foundation

struct Review: Identifiable {
    let id: Int
    let userId: UUID
    let username: String
    let rating: Int        // 1–5
    let comment: String?
    let createdAt: Date
}
