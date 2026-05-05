import SwiftUI

struct FloatingTabBar: View {
    @Binding var selectedTab: Int

    private let tabs: [FloatingTabItem] = [
        FloatingTabItem(title: "首页", systemImage: "house.fill"),
        FloatingTabItem(title: "直播", systemImage: "play.tv.fill"),
        FloatingTabItem(title: "搜索", systemImage: "magnifyingglass"),
        FloatingTabItem(title: "我的", systemImage: "person.fill")
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tabs.indices, id: \.self) { index in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        selectedTab = index
                    }
                } label: {
                    FloatingTabButton(
                        item: tabs[index],
                        isSelected: selectedTab == index
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .frame(maxWidth: 430)
        .background {
            floatingGlassBackground
        }
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.20), radius: 22, x: 0, y: 12)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var floatingGlassBackground: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Capsule()
                .fill(Color.white.opacity(0.10))
                .glassEffect(.regular.tint(Color.white.opacity(0.12)).interactive(), in: Capsule())
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .background {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                }
        }
    }
}

private struct FloatingTabButton: View {
    let item: FloatingTabItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: item.systemImage)
                .font(.system(size: 15, weight: .semibold))

            Text(item.title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .padding(.horizontal, 8)
        .background {
            if isSelected {
                Capsule()
                    .fill(Color.white.opacity(0.20))
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.26), lineWidth: 1)
                    }
            }
        }
        .contentShape(Capsule())
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct FloatingTabItem {
    let title: String
    let systemImage: String
}
