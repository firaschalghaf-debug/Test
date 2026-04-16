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
    let discountPercent: Double?
    let developerName: String?
    let publisherName: String?
    let tags: [String]
    let releaseDate: String?   // "YYYY-MM-DD" from DB

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
        coverImageUrl: String? = nil,
        discountPercent: Double? = nil,
        developerName: String? = nil,
        publisherName: String? = nil,
        tags: [String] = [],
        releaseDate: String? = nil
    ) {
        self.id              = id
        self.title           = title
        self.genre           = genre
        self.price           = price
        self.color           = color
        self.subtitle        = subtitle
        self.imageName       = imageName
        self.coverImage      = coverImage
        self.description     = description
        self.coverImageUrl   = coverImageUrl
        self.discountPercent = discountPercent
        self.developerName   = developerName
        self.publisherName   = publisherName
        self.tags            = tags
        self.releaseDate     = releaseDate
    }

    // MARK: - Price helpers

    var originalPriceValue: Double {
        Double(price.replacingOccurrences(of: "$", with: "")) ?? 0
    }

    var discountedPriceValue: Double? {
        guard let pct = discountPercent, pct > 0 else { return nil }
        return (originalPriceValue * (1 - pct / 100) * 100).rounded() / 100
    }

    var effectivePrice: Double {
        discountedPriceValue ?? originalPriceValue
    }

    var displayPrice: String {
        if let dp = discountedPriceValue {
            return String(format: "$%.2f", dp)
        }
        return price
    }

    var isOnSale: Bool { discountPercent != nil && (discountPercent ?? 0) > 0 }
}

// MARK: - Supabase DTO

struct SupabaseGameRow: Decodable {
    let id: UUID
    let title: String
    let genre: String
    let price: String
    let image: String?
    let description: String?
    let coverImageUrl: String?
    let releaseDate: String?

    struct DeveloperRow: Decodable { let developerName: String }
    struct PublisherRow: Decodable { let publisherName: String }
    let developers: DeveloperRow?
    let publishers: PublisherRow?
}
