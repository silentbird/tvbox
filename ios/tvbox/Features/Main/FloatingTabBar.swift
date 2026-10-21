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
        HStack(spacing: 0) {
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
        // 描边用跟随深浅色的细线，浅色背景上也看得出边界
        .overlay {
            Capsule()
                .strokeBorder(Color.tvboxHairline, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var floatingGlassBackground: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Capsule()
                .fill(Color.tvboxSurface.opacity(0.55))
                .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            Capsule()
                .fill(.regularMaterial)
        }
    }
}

private struct FloatingTabButton: View {
    let item: FloatingTabItem
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: item.systemImage)
                .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                .frame(height: 22)

            Text(item.title)
                .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                .lineLimit(1)
        }
        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background {
            if isSelected {
                Capsule()
                    .fill(Color.accentColor.opacity(0.14))
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
