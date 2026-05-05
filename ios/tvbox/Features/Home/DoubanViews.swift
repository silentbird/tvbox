import SwiftUI

struct DoubanCategoryRow: View {
    let category: DoubanCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundColor(.orange)

                Text(category.name)
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                if category.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)

            if category.movies.isEmpty && !category.isLoading {
                HStack {
                    Spacer()
                    Text("暂无数据")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Spacer()
                }
                .frame(height: 100)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(category.movies) { movie in
                            NavigationLink(destination: DetailView(movie: movie)) {
                                DoubanMovieCard(movie: movie)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct DoubanMovieCard: View {
    let movie: MovieItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(urlString: movie.vodPic)
                    .frame(width: 120, height: 160)
                    .clipped()

                if let remarks = movie.vodRemarks, !remarks.isEmpty {
                    Text(remarks)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(4)
                        .padding(6)
                }
            }

            Text(movie.vodName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 120, height: 36, alignment: .topLeading)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
        }
        .background(Color.tvboxSystemBackground)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
