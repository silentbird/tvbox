import SwiftUI

struct VideoItemCard: View {
    let video: VideoItem
    
    var body: some View {
        NavigationLink(destination: VideoDetailView(video: video)) {
            VStack(alignment: .leading, spacing: 0) {
                // 缩略图
                AsyncImage(url: URL(string: video.thumbnail)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray
                }
                .frame(height: 280)
                .clipped()
                
                // 视频信息
                VStack(alignment: .leading, spacing: 4) {
                    // 标签行
                    HStack(spacing: 8) {
                        Text("\(video.year)年")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        
                        Text(video.duration)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    
                    // 标题
                    Text(video.title)
                        .font(.headline)
                        .lineLimit(1)
                        .padding(.vertical, 4)
                    
                    // 评分
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text(String(format: "%.1f", video.rating))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
            }
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .shadow(radius: 4)
        }
    }
} 