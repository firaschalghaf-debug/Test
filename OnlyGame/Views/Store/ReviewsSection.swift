import SwiftUI

struct ReviewsSection: View {
    let game: Game
    let isOwned: Bool

    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var reviewVM = ReviewViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader

            if reviewVM.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                if !reviewVM.reviews.isEmpty {
                    ratingOverview
                }

                if isOwned && authVM.isSignedIn {
                    writeReviewCard
                }

                if reviewVM.reviews.isEmpty && !(isOwned && authVM.isSignedIn) {
                    emptyState
                } else if !reviewVM.reviews.isEmpty {
                    reviewsList
                }
            }
        }
        .task {
            await reviewVM.load(gameId: game.id, userId: authVM.userId)
        }
        .onChange(of: authVM.userId) {
            Task { await reviewVM.load(gameId: game.id, userId: authVM.userId) }
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack {
            Text("Player Reviews")
                .font(.title2.bold())
                .foregroundStyle(.white)
            if !reviewVM.reviews.isEmpty {
                Text("\(reviewVM.reviews.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.50))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Rating overview

    private var ratingOverview: some View {
        HStack(alignment: .top, spacing: 32) {
            // Big average
            VStack(spacing: 6) {
                Text(String(format: "%.1f", reviewVM.averageRating))
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.white)
                StarRow(rating: reviewVM.averageRating, size: 18)
                Text("\(reviewVM.reviews.count) review\(reviewVM.reviews.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.50))
            }

            // Breakdown bars
            VStack(alignment: .leading, spacing: 6) {
                ForEach((1...5).reversed(), id: \.self) { star in
                    HStack(spacing: 8) {
                        Text("\(star)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.60))
                            .frame(width: 10, alignment: .trailing)
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.yellow)
                        GeometryReader { geo in
                            let total = max(reviewVM.reviews.count, 1)
                            let fraction = CGFloat(reviewVM.count(for: star)) / CGFloat(total)
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.10)).frame(height: 6)
                                Capsule().fill(Color.yellow.opacity(0.80))
                                    .frame(width: geo.size.width * fraction, height: 6)
                            }
                        }
                        .frame(width: 140, height: 6)
                        Text("\(reviewVM.count(for: star))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.40))
                            .frame(width: 20, alignment: .leading)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Write / edit review

    private var writeReviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(reviewVM.hasUserReview ? "Your Review" : "Write a Review")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                if reviewVM.hasUserReview {
                    Button(role: .destructive) {
                        if let uid = authVM.userId {
                            Task { await reviewVM.deleteMyReview(userId: uid, gameId: game.id) }
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red.opacity(0.80))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Star picker
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= reviewVM.draftRating ? "star.fill" : "star")
                        .font(.system(size: 26))
                        .foregroundStyle(star <= reviewVM.draftRating ? Color.yellow : Color.white.opacity(0.30))
                        .onTapGesture { reviewVM.draftRating = star }
                        .animation(.easeInOut(duration: 0.12), value: reviewVM.draftRating)
                }
                if reviewVM.draftRating > 0 {
                    Text(ratingLabel(reviewVM.draftRating))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.60))
                        .padding(.leading, 6)
                }
            }

            // Comment field
            ZStack(alignment: .topLeading) {
                if reviewVM.draftComment.isEmpty {
                    Text("Share your thoughts (optional)...")
                        .foregroundStyle(.white.opacity(0.30))
                        .font(.body)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $reviewVM.draftComment)
                    .font(.body)
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 72, maxHeight: 120)
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                if !reviewVM.submitError.isEmpty {
                    Text(reviewVM.submitError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Spacer()
                Button {
                    if let uid = authVM.userId {
                        Task { await reviewVM.submit(userId: uid, gameId: game.id) }
                    }
                } label: {
                    Group {
                        if reviewVM.isSubmitting {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(reviewVM.hasUserReview ? "Update Review" : "Submit Review")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .disabled(reviewVM.draftRating == 0 || reviewVM.isSubmitting)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cyan.opacity(0.20), lineWidth: 1))
    }

    // MARK: - Reviews list

    private var reviewsList: some View {
        VStack(spacing: 12) {
            ForEach(reviewVM.reviews) { review in
                ReviewRow(review: review, isCurrentUser: review.userId == authVM.userId)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.25))
                Text("No reviews yet. Be the first!")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.40))
            }
            .padding(.vertical, 30)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func ratingLabel(_ r: Int) -> String {
        switch r {
        case 1: return "Terrible"
        case 2: return "Poor"
        case 3: return "Okay"
        case 4: return "Good"
        case 5: return "Excellent"
        default: return ""
        }
    }
}

// MARK: - Individual review row

private struct ReviewRow: View {
    let review: Review
    let isCurrentUser: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(review.username)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isCurrentUser ? .cyan : .white)
                if isCurrentUser {
                    Text("You")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.cyan.opacity(0.12))
                        .clipShape(Capsule())
                }
                Spacer()
                Text(review.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
                Text("ago")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
            }

            StarRow(rating: Double(review.rating), size: 13)

            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(isCurrentUser ? Color.cyan.opacity(0.06) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isCurrentUser ? Color.cyan.opacity(0.18) : Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

// MARK: - Star row

struct StarRow: View {
    let rating: Double
    let size: CGFloat

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: iconName(for: star))
                    .font(.system(size: size))
                    .foregroundStyle(star <= Int(rating.rounded()) ? Color.yellow : Color.white.opacity(0.22))
            }
        }
    }

    private func iconName(for star: Int) -> String {
        let full  = Int(rating)
        let frac  = rating - Double(full)
        if star <= full { return "star.fill" }
        if star == full + 1 && frac >= 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}
