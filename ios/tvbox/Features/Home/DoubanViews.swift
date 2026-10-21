import SwiftUI

struct DoubanCategoryRow: View {
    let category: DoubanCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(category.name)
                    .font(.system(size: 18, weight: .bold))

                Spacer()

                if category.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 18)

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
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(category.movies) { movie in
                            NavigationLink(destination: DetailView(movie: movie)) {
                                MovieCard(movie: movie)
                                    .frame(width: 108)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }
}
