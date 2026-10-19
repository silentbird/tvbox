import SwiftUI

struct MovieCard: View {
    let movie: MovieItem
    /// 标题下方的补充说明，例如聚合搜索结果的来源站点
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                // 图片放在 overlay 里，横图按 fill 放大时不会把卡片撑宽
                Color.clear
                    .frame(height: 180)
                    .overlay {
                        CachedAsyncImage(urlString: movie.vodPic)
                    }
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

            VStack(alignment: .leading, spacing: 2) {
                Text(movie.vodName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .background(Color.tvboxSystemBackground)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
