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
                }
            }
            .padding()
        }
        .navigationTitle(category.name)
        .onAppear {
            viewModel.loadMovies(categoryId: category.tid)
        }
    }
}

class CategoryDetailViewModel: ObservableObject {
    @Published var movies: [MovieItem] = []
    @Published var isLoading = false

    func loadMovies(categoryId: String) {
        // TODO: 从 Spider 加载分类数据
    }
}
