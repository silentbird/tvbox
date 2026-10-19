import SwiftUI

struct CategoryDetailView: View {
    let category: MovieCategory
    @StateObject private var viewModel = CategoryDetailViewModel()

    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.movies) { movie in
                    NavigationLink(destination: DetailView(movie: movie)) {
                        MovieCard(movie: movie)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        viewModel.loadMoreIfNeeded(current: movie)
                    }
                }
            }
            .padding()

            if viewModel.isLoading {
                ProgressView()
                    .padding()
            } else if let errorMessage = viewModel.errorMessage, viewModel.movies.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .navigationTitle(category.name)
        .onAppear {
            viewModel.loadMovies(categoryId: category.tid)
        }
    }
}

@MainActor
class CategoryDetailViewModel: ObservableObject {
    @Published var movies: [MovieItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var categoryId = ""
    private var page = 0
    private var hasMore = true

    func loadMovies(categoryId: String) {
        // 从详情页返回时 onAppear 会再次触发，已加载过就不重新请求
        guard movies.isEmpty, !isLoading else { return }
        self.categoryId = categoryId
        loadNextPage()
    }

    func loadMoreIfNeeded(current movie: MovieItem) {
        guard movie.id == movies.last?.id else { return }
        loadNextPage()
    }

    private func loadNextPage() {
        guard hasMore, !isLoading else { return }
        isLoading = true

        Task {
            do {
                let content = try await SpiderManager.shared.categoryContent(tid: categoryId, page: page + 1)
                movies.append(contentsOf: content.videos)
                page = content.page
                hasMore = content.hasMore && !content.videos.isEmpty
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
