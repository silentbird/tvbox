import SwiftUI

struct CollectView: View {
    @StateObject private var viewModel = CollectViewModel()
    @State private var showClearAlert = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 12)
    ]
    
    var body: some View {
        Group {
            if viewModel.collectItems.isEmpty {
                ContentUnavailableView(
                    "暂无收藏",
                    systemImage: "heart.slash",
                    description: Text("您收藏的影视将会显示在这里")
                )
            } else {
                collectGrid
            }
        }
        .navigationTitle("我的收藏")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !viewModel.collectItems.isEmpty {
                    Button("清空") {
                        showClearAlert = true
                    }
                }
            }
        }
        .alert("清空收藏", isPresented: $showClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                viewModel.clearCollects()
            }
        } message: {
            Text("确定要清空所有收藏吗？")
        }
        .onAppear {
            viewModel.loadCollects()
        }
    }
    
    private var collectGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.collectItems) { item in
                    CollectItemCard(item: item) {
                        viewModel.removeCollect(item)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Collect Item Card
struct CollectItemCard: View {
    let item: StorageManager.VodCollectItem
    let onRemove: () -> Void
    
    @State private var showRemoveAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 封面
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: item.vodPic ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    LinearGradient(
                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(height: 180)
                .clipped()
                
                // 站点标签
                Text(item.siteName)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                    .padding(6)
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(item.vodName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let remarks = item.vodRemarks, !remarks.isEmpty {
                    Text(remarks)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .contextMenu {
            Button(role: .destructive) {
                showRemoveAlert = true
            } label: {
                Label("取消收藏", systemImage: "heart.slash")
            }
        }
        .alert("取消收藏", isPresented: $showRemoveAlert) {
            Button("取消", role: .cancel) {}
            Button("确定", role: .destructive) {
                onRemove()
            }
        } message: {
            Text("确定要取消收藏「\(item.vodName)」吗？")
        }
    }
}

// MARK: - Collect ViewModel
class CollectViewModel: ObservableObject {
    @Published var collectItems: [StorageManager.VodCollectItem] = []
    
    private let storageManager = StorageManager.shared
    
    func loadCollects() {
        collectItems = storageManager.getCollects()
    }
    
    func removeCollect(_ item: StorageManager.VodCollectItem) {
        var collects = storageManager.getCollects()
        collects.removeAll { $0.id == item.id }
        
        // 直接更新 UserDefaults
        if let data = try? JSONEncoder().encode(collects) {
            UserDefaults.standard.set(data, forKey: "vod_collect")
        }
        
        loadCollects()
    }
    
    func clearCollects() {
        storageManager.clearCollects()
        collectItems.removeAll()
    }
}

#Preview {
    NavigationView {
        CollectView()
    }
}

