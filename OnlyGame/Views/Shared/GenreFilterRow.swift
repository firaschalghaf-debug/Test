import SwiftUI

struct GenreFilterRow: View {
    let genres: [String]
    @Binding var selectedGenre: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(genres, id: \.self) { genre in
                    Button {
                        selectedGenre = genre
                    } label: {
                        Text(genre)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedGenre == genre ? .black : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedGenre == genre ? Color.cyan : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
