import SwiftUI

struct MovieCard: View {
    let movie: MovieItem
    /// 标题下方的补充说明，例如聚合搜索结果的来源站点
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 图片放在 overlay 里，横图按 fill 放大时不会把卡片撑宽
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay {
                    CachedAsyncImage(urlString: movie.vodPic) { Color.tvboxSurfaceSecondary }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .bottomTrailing) {
                    if let remarks = movie.vodRemarks, !remarks.isEmpty {
                        PosterBadge(text: remarks)
                            .padding(6)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(movie.vodName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .contentShape(Rectangle())
    }
}
