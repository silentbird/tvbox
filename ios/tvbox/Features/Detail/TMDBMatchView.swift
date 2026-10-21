import SwiftUI

/// 自动匹配错了时，从 TMDB 搜索结果里手动选
struct TMDBMatchView: View {
    let vodName: String
    /// 选中的作品，nil 表示不使用 TMDB 资料
    let onSelect: (TMDBSearchItem?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [TMDBSearchItem] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("片名", text: $query)
                            .onSubmit(search)
                        Button("搜索", action: search)
                            .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section {
                    if isSearching {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.secondary)
                    } else if results.isEmpty {
                        Text("没有找到")
                            .foregroundColor(.secondary)
                    }
                    ForEach(results) { item in
                        Button {
                            onSelect(item)
                            dismiss()
                        } label: {
                            resultRow(item)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    Button("不使用 TMDB 资料", role: .destructive) {
                        onSelect(nil)
                        dismiss()
                    }
                }
            }
            .navigationTitle("重新匹配")
            .tvboxInlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .tvboxNavigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                query = TMDBService.parseTitle(vodName).query
                search()
            }
        }
        .tvboxConfigSheetSize()
    }

    private func resultRow(_ item: TMDBSearchItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            CachedAsyncImage(urlString: TMDBSettings.imageURL(item.posterPath, size: "w154"))
                .id(item.posterPath)
                .frame(width: 46, height: 69)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                Text([item.mediaType == .tv ? "剧集" : "电影", item.year, item.originalTitle == item.title ? nil : item.originalTitle]
                    .compactMap { $0 }
                    .joined(separator: " · "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if let overview = item.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private func search() {
        let keyword = query.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        Task {
            do {
                results = try await TMDBService.shared.search(query: keyword)
            } catch {
                results = []
                errorMessage = AppErrorMessage.userMessage(for: error)
            }
            isSearching = false
        }
    }
}
