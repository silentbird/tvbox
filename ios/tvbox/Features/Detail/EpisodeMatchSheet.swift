import SwiftUI

/// 自动对应的分集不对时，手动选这一集对应 TMDB 的哪一集
struct EpisodeMatchSheet: View {
    let episodeName: String
    let metadata: VodMetadata
    /// 当前对应的分集
    let current: EpisodeRef?
    /// 当前是不是手动对应的
    let isManual: Bool
    /// 选中的分集，nil 表示恢复自动匹配
    let onSelect: (EpisodeRef?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(episodeName)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    if isManual {
                        Button("恢复自动匹配") { select(nil) }
                    }
                    Button("不对应任何分集", role: .destructive) { select(EpisodeRef.none) }
                }

                if !metadata.episodes.isEmpty {
                    Section("正片") {
                        ForEach(metadata.episodes, id: \.number) { episode in
                            row(.episode(episode.number), episode)
                        }
                    }
                }

                if !metadata.specials.isEmpty {
                    Section("特别篇") {
                        ForEach(metadata.specials, id: \.number) { episode in
                            row(.special(episode.number), episode)
                        }
                    }
                }
            }
            .navigationTitle("对应 TMDB 分集")
            .tvboxInlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .tvboxNavigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .tvboxConfigSheetSize()
    }

    private func row(_ ref: EpisodeRef, _ episode: VodMetadata.Episode) -> some View {
        Button(action: { select(ref) }) {
            HStack(spacing: 12) {
                CachedAsyncImage(urlString: TMDBSettings.imageURL(episode.stillPath, size: "w185"))
                    .id(episode.stillPath)
                    .frame(width: 80, height: 45)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 3) {
                    Text(ref.label + (episode.name.map { " · \($0)" } ?? ""))
                        .font(.subheadline)
                        .lineLimit(1)
                    if let airDate = episode.airDate {
                        Text(airDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if ref == current {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func select(_ ref: EpisodeRef?) {
        onSelect(ref)
        dismiss()
    }
}

private extension EpisodeRef {
    var label: String {
        switch self {
        case .episode(let number): return String(format: "E%02d", number)
        case .special(let number): return "SP\(number)"
        case .none: return ""
        }
    }
}
