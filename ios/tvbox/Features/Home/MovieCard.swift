import SwiftUI

struct MovieCard: View {
    let movie: MovieItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(urlString: movie.vodPic)
                    .frame(height: 180)
                    .clipped()

                if let remarks = movie.vodRemarks, !remarks.isEmpty {
                    Text(remarks)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.9))
                        .cornerRadius(4)
                        .padding(6)
                }
            }

            Text(movie.vodName)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
        }
        .background(Color.tvboxSystemBackground)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
