import SwiftUI

/// TMDB 详情页的线路面板：按站点分组列出找到的线路，年份、集数对不上的放在「可能相关」。
/// 查找还没结束时新找到的来源会继续加进来
struct SourcePickerSheet: View {
    @ObservedObject var viewModel: DetailViewModel
    let selectedFlagIndex: Int
    let onPick: (VodSource, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showKeywordAlert = false
    @State private var keywordInput = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.sources.filter { $0.match.confidence == .sure }) { source in
                    sourceSection(source, warning: nil)
                }
                ForEach(viewModel.sources.filter { $0.match.confidence == .possible }) { source in
                    sourceSection(source, warning: source.match.reason ?? "可能相关")
                }

                Section {
                    if viewModel.isFindingSources {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(viewModel.isResolvingFromHits
                                 ? "正在获取线路 \(viewModel.findProgressText ?? "")"
                                 : "还有 \(viewModel.totalSiteCount - viewModel.finishedSiteCount) 个站点在检索…")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    } else {
                        Button("重新检索") { viewModel.findSources() }
                    }
                    Button("换个片名搜索…") {
                        keywordInput = viewModel.findKeyword
                        showKeywordAlert = true
                    }
                } footer: {
                    if !viewModel.isFindingSources, let searched = viewModel.lastSearchText {
                        Text("上次检索 \(searched) · \(viewModel.totalSiteCount) 个站点。检索结果会保存，重新检索才会覆盖。")
                    }
                }
            }
            .navigationTitle("选择线路")
            .tvboxInlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .tvboxNavigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("换个片名搜索", isPresented: $showKeywordAlert) {
                TextField("片名", text: $keywordInput)
                Button("搜索") { viewModel.findSources(keyword: keywordInput) }
                Button("取消", role: .cancel) {}
            } message: {
                Text("用别名、原名等在各站点重新查找")
            }
        }
        .presentationDetents([.medium, .large])
        .tvboxConfigSheetSize()
    }

    private func sourceSection(_ source: VodSource, warning: String?) -> some View {
        Section {
            ForEach(Array(source.vodInfo.playFlags.enumerated()), id: \.offset) { index, flag in
                let isSelected = source.id == viewModel.selectedSource?.id && index == selectedFlagIndex
                let count = source.vodInfo.playUrls.indices.contains(index) ? source.vodInfo.playUrls[index].count : 0
                Button {
                    onPick(source, index)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .accentColor : .secondary)
                        Text(flag)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(count) 集")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            HStack {
                Text(source.site.name)
                Spacer()
                if let warning {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                } else if let remarks = source.vodInfo.vodRemarks, !remarks.isEmpty {
                    Text(remarks)
                }
            }
        }
    }
}
