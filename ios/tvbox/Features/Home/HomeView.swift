import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedCategory: SourceCategory?
    
    var body: some View {
        NavigationView {
            if let category = selectedCategory {
                VideoListView(category: category, viewModel: viewModel)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // 搜索框
                        SearchBar(text: $viewModel.searchText, onSearch: viewModel.search)
                            .padding(.horizontal)
                        
                        // 分类列表
                        ForEach(viewModel.categories) { category in
                            CategoryRow(category: category)
                                .onTapGesture {
                                    selectedCategory = category
                                    viewModel.loadVideos(for: category)
                                }
                        }
                        .padding()
                    }
                }
                .navigationTitle("首页")
            }
        }
        .navigationViewStyle(.stack)
        .toast(message: viewModel.toastMessage, isShowing: $viewModel.showToast)
        .onAppear {
            viewModel.loadCategories()
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var onSearch: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("搜索视频", text: $text, onCommit: onSearch)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct CategoryRow: View {
    let category: SourceCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.name)
                .font(.headline)
            
            if !category.categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(category.categories, id: \.self) { subCategory in
                            Text(subCategory)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
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
                        Text("\(video.year)年")
                        Text(video.duration)
                    }
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    
                    // 评分
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", video.rating))
                    }
                    .font(.subheadline)
                    
                    // 简介
                    Text(video.description)
                        .font(.body)
                        .padding(.top, 8)
                    
                    // 标签
                    if !video.tags.isEmpty {
                        Text("标签：\(video.tags.joined(separator: "、"))")
                            .font(.subheadline)
                            .padding(.top, 8)
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