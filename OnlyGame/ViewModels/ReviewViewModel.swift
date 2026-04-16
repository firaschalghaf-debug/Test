import Foundation
import Combine

@MainActor
final class ReviewViewModel: ObservableObject {

    @Published var reviews: [Review] = []
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var submitError = ""

    // Draft form state
    @Published var draftRating: Int = 0
    @Published var draftComment: String = ""

    private var currentUserId: UUID?

    // MARK: - Derived

    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        return Double(reviews.reduce(0) { $0 + $1.rating }) / Double(reviews.count)
    }

    func count(for star: Int) -> Int {
        reviews.filter { $0.rating == star }.count
    }

    var userReview: Review? {
        guard let uid = currentUserId else { return nil }
        return reviews.first { $0.userId == uid }
    }

    var hasUserReview: Bool { userReview != nil }

    // MARK: - Load

    func load(gameId: UUID, userId: UUID? = nil) async {
        currentUserId = userId
        isLoading = true
        do {
            reviews = try await SupabaseManager.shared.fetchReviews(gameId: gameId)
            // Pre-fill draft if user already reviewed
            if let existing = userReview {
                draftRating  = existing.rating
                draftComment = existing.comment ?? ""
            }
        } catch {}
        isLoading = false
    }

    // MARK: - Submit

    func submit(userId: UUID, gameId: UUID) async {
        guard draftRating > 0 else { return }
        isSubmitting = true
        submitError = ""
        do {
            let trimmed = draftComment.trimmingCharacters(in: .whitespacesAndNewlines)
            try await SupabaseManager.shared.submitReview(
                userId: userId,
                gameId: gameId,
                rating: draftRating,
                comment: trimmed.isEmpty ? nil : trimmed
            )
            await load(gameId: gameId, userId: userId)
        } catch {
            submitError = error.localizedDescription
        }
        isSubmitting = false
    }

    // MARK: - Delete

    func deleteMyReview(userId: UUID, gameId: UUID) async {
        do {
            try await SupabaseManager.shared.deleteReview(userId: userId, gameId: gameId)
            await load(gameId: gameId, userId: userId)
            draftRating  = 0
            draftComment = ""
        } catch {}
    }
}
