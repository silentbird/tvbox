import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部布局
                HStack {
                    Text("TVBox")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.black)
                
                // 内容布局
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(viewModel.videos) { video in
                            VideoItemCard(video: video)
                        }
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .alert("错误", isPresented: .constant(viewModel.error != nil)) {
                Button("确定") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }
}

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
                        if let year = video.year {
                            Text("\(year)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                        
                        if let area = video.area {
                            Text(area)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    
                    // 标题
                    Text(video.title)
                        .font(.headline)
                        .lineLimit(1)
                        .padding(.vertical, 4)
                    
                    // 演员信息
                    if let actors = video.actors {
                        Text(actors.joined(separator: "、"))
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                .padding(8)
                .background(Color(.systemBackground))
            }
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

struct VideoDetailView: View {
    let video: VideoItem
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 大图
                AsyncImage(url: URL(string: video.thumbnail)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray
                }
                .frame(height: 300)
                .clipped()
                
                VStack(alignment: .leading, spacing: 12) {
                    // 标题
                    Text(video.title)
                        .font(.title)
                        .bold()
                    
                    // 基本信息
                    HStack {
                        if let year = video.year {
                            Text("\(year)年")
                        }
                        if let area = video.area {
                            Text(area)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    
                    // 导演
                    if let director = video.director {
                        Text("导演：\(director)")
                            .font(.subheadline)
                    }
                    
                    // 主演
                    if let actors = video.actors {
                        Text("主演：\(actors.joined(separator: "、"))")
                            .font(.subheadline)
                    }
                    
                    // 简介
                    if let description = video.description {
                        Text(description)
                            .font(.body)
                            .padding(.top, 8)
                    }
                    
                    // 剧集列表
                    if let episodes = video.episodes {
                        Text("剧集列表")
                            .font(.headline)
                            .padding(.top)
                        
                        ForEach(episodes) { episode in
                            Text("第\(episode.index)集：\(episode.title)")
                                .font(.subheadline)
                                .padding(.vertical, 4)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HomeView()
} 