import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var showClearAlert = false
    
    var body: some View {
        Group {
            if viewModel.historyItems.isEmpty {
                ContentUnavailableView(
                    "暂无观看记录",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("您观看的影视将会显示在这里")
                )
            } else {
                historyList
            }
        }
        .navigationTitle("观看历史")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !viewModel.historyItems.isEmpty {
                    Button("清空") {
                        showClearAlert = true
                    }
                }
            }
        }
        .alert("清空历史记录", isPresented: $showClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                viewModel.clearHistory()
            }
        } message: {
            Text("确定要清空所有观看记录吗？")
        }
        .onAppear {
            viewModel.loadHistory()
        }
    }
    
    private var historyList: some View {
        List {
            ForEach(groupedHistory, id: \.key) { dateString, items in
                Section(header: Text(dateString)) {
                    ForEach(items, id: \.vodId) { item in
                        HistoryRow(item: item)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.removeHistory(item)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var groupedHistory: [(key: String, value: [StorageManager.VodHistoryItem])] {
        let grouped = Dictionary(grouping: viewModel.historyItems) { item -> String in
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let itemDate = calendar.startOfDay(for: item.updateTime)
            
            if itemDate == today {
                return "今天"
            } else if itemDate == calendar.date(byAdding: .day, value: -1, to: today) {
                return "昨天"
            } else if itemDate >= calendar.date(byAdding: .day, value: -7, to: today)! {
                return "本周"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy年MM月"
                return formatter.string(from: item.updateTime)
            }
        }
        
        let order = ["今天", "昨天", "本周"]
        return grouped.sorted { first, second in
            let firstIndex = order.firstIndex(of: first.key) ?? Int.max
            let secondIndex = order.firstIndex(of: second.key) ?? Int.max
            if firstIndex != Int.max || secondIndex != Int.max {
                return firstIndex < secondIndex
            }
            return first.key > second.key
        }
    }
}

// MARK: - History Row
struct HistoryRow: View {
    let item: StorageManager.VodHistoryItem
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面
            AsyncImage(url: URL(string: item.vodPic ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 100, height: 60)
            .cornerRadius(6)
            .clipped()
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(item.vodName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                // 播放进度
                HStack(spacing: 4) {
                    Text("看到第\(item.episodeIndex + 1)集")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if item.duration > 0 {
                        Text("·")
                            .foregroundColor(.secondary)
                        
                        let progress = item.progress / item.duration
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                // 进度条
                if item.duration > 0 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 3)
                            
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * CGFloat(item.progress / item.duration), height: 3)
                        }
                        .cornerRadius(1.5)
                    }
                    .frame(height: 3)
                }
            }
            
            Spacer()
            
            // 时间
            Text(formatDate(item.updateTime))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - History ViewModel
class HistoryViewModel: ObservableObject {
    @Published var historyItems: [StorageManager.VodHistoryItem] = []
    
    private let storageManager = StorageManager.shared
    
    func loadHistory() {
        historyItems = storageManager.getVodHistory()
    }
    
    func removeHistory(_ item: StorageManager.VodHistoryItem) {
        storageManager.removeVodHistory(vodId: item.vodId, siteKey: item.siteKey)
        loadHistory()
    }
    
    func clearHistory() {
        storageManager.clearVodHistory()
        historyItems.removeAll()
    }
}

#Preview {
    NavigationView {
        HistoryView()
    }
}

