import Foundation

struct Order: Identifiable {
    let id: Int
    let orderDate: Date
    let totalAmount: Double
    let paymentMethod: String?
    let status: String
    let items: [OrderItem]
}

struct OrderItem: Identifiable {
    let id: Int
    let gameId: UUID
    let gameTitle: String
    let gameGenre: String
    let unitPrice: Double
    let discountApplied: Double
    let subtotal: Double
}
