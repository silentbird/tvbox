import SwiftUI

struct VideoListView: View {
    let category: SourceCategory
    @ObservedObject var viewModel: HomeViewModel
    
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.videos) { video in
                    VideoItemCard(video: video)
                }
            }
            .padding()
        }
        .navigationTitle(category.name)
        .onAppear {
            viewModel.loadVideos(for: category)
        }
    }
} 