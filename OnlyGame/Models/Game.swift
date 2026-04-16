import SwiftUI

struct Game: Identifiable, Hashable {
    let id: UUID
    let title: String
    let genre: String
    let price: String
    let color: Color
    let subtitle: String
    let imageName: String
    let coverImage: String?
    let description: String?
    let coverImageUrl: String?

    init(
        id: UUID = UUID(),
        title: String,
        genre: String,
        price: String,
        color: Color,
        subtitle: String,
        imageName: String,
        coverImage: String? = nil,
        description: String? = nil,
        coverImageUrl: String? = nil
    ) {
        self.id           = id
        self.title        = title
        self.genre        = genre
        self.price        = price
        self.color        = color
        self.subtitle     = subtitle
        self.imageName    = imageName
        self.coverImage   = coverImage
        self.description  = description
        self.coverImageUrl = coverImageUrl
    }
}

// MARK: - Supabase DTO

struct SupabaseGameRow: Decodable {
    let id: UUID
    let title: String
    let genre: String
    let price: String
    let image: String?
    let description: String?
    let coverImageUrl: String?   // decoded via .convertFromSnakeCase
}
