import SwiftUI

extension View {
    @ViewBuilder
    func tvboxInlineNavigationBarTitle() -> some View {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func tvboxHiddenNavigationBar() -> some View {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            self.toolbar(.hidden, for: .navigationBar)
        } else {
            self.navigationBarHidden(true)
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func tvboxStackNavigationViewStyle() -> some View {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        self.navigationViewStyle(.stack)
        #else
        self
        #endif
    }

    @ViewBuilder
    func tvboxInsetGroupedListStyle() -> some View {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        self.listStyle(.insetGrouped)
        #else
        self.listStyle(.automatic)
        #endif
    }

    /// macOS 表单里的 Button 默认画成带底色的按钮，整行点击的设置项要和其它行一样平
    @ViewBuilder
    func tvboxFormRowButtonStyle() -> some View {
        #if os(macOS)
        self
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        #else
        self
        #endif
    }

    @ViewBuilder
    func tvboxUrlTextInputStyle() -> some View {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        self
            .autocapitalization(.none)
            .autocorrectionDisabled()
        #else
        self.autocorrectionDisabled()
        #endif
    }

    /// 详情页大图顶到导航栏下面：导航栏透明，返回按钮用浅色。macOS 的窗口工具栏不透明，保持原样
    @ViewBuilder
    func tvboxContentUnderNavigationBar() -> some View {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        self
            .ignoresSafeArea(edges: .top)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func tvboxStatusBar(hidden: Bool) -> some View {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        self.statusBar(hidden: hidden)
        #else
        self
        #endif
    }

    /// 用 item 而不是 isPresented：弹出内容直接拿到点击时的参数，不会读到还没更新的 @State 而显示空白
    /// 弹出的页面用 `@Environment(\.tvboxDismissCover)` 关闭自己
    @ViewBuilder
    func tvboxFullScreenCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        self.fullScreenCover(item: item) { value in
            content(value).environment(\.tvboxDismissCover) { item.wrappedValue = nil }
        }
        #elseif os(macOS)
        self.modifier(WindowCoverPresenter(item: item, coverContent: content))
        #else
        self.sheet(item: item) { value in
            content(value).environment(\.tvboxDismissCover) { item.wrappedValue = nil }
        }
        #endif
    }

    /// 给 tvboxFullScreenCover 提供窗口级覆盖层，挂在窗口根视图上
    @ViewBuilder
    func tvboxWindowCoverHost() -> some View {
        #if os(macOS)
        self.modifier(WindowCoverHost())
        #else
        self
        #endif
    }

    @ViewBuilder
    func tvboxConfigSheetSize() -> some View {
        #if os(macOS)
        self.frame(width: 460, height: 520)
        #else
        self
        #endif
    }
}

extension ToolbarItemPlacement {
    static var tvboxNavigationBarLeading: ToolbarItemPlacement {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        return .navigationBarLeading
        #else
        return .automatic
        #endif
    }

    static var tvboxNavigationBarTrailing: ToolbarItemPlacement {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        return .navigationBarTrailing
        #else
        return .automatic
        #endif
    }
}

extension EnvironmentValues {
    /// 关闭 tvboxFullScreenCover 弹出的页面。macOS 的窗口覆盖层不是系统弹出，系统的 dismiss 关不掉它
    @Entry var tvboxDismissCover: () -> Void = {}
}

#if os(macOS)
/// macOS 没有 fullScreenCover，sheet 只是窗口中间的一块面板。
/// Android 全屏播放占满整个界面，这里由窗口根视图的覆盖层盖住整个窗口（含侧边栏）
@MainActor
final class TVBoxWindowCover: ObservableObject {
    @Published var content: AnyView?
}

extension EnvironmentValues {
    @Entry var tvboxWindowCover: TVBoxWindowCover? = nil
}

private struct WindowCoverHost: ViewModifier {
    @StateObject private var windowCover = TVBoxWindowCover()

    func body(content: Content) -> some View {
        content
            .environment(\.tvboxWindowCover, windowCover)
            .overlay {
                if let cover = windowCover.content {
                    cover.ignoresSafeArea()
                }
            }
            // 标题栏的工具条（返回、侧边栏按钮）会浮在覆盖层上面，盖住时一起隐藏
            .toolbar(windowCover.content == nil ? .automatic : .hidden, for: .windowToolbar)
    }
}

private struct WindowCoverPresenter<Item: Identifiable, CoverContent: View>: ViewModifier {
    @Binding var item: Item?
    let coverContent: (Item) -> CoverContent
    @Environment(\.tvboxWindowCover) private var windowCover

    func body(content: Content) -> some View {
        content.onChange(of: item?.id) { _, _ in
            windowCover?.content = item.map { value in
                AnyView(coverContent(value).environment(\.tvboxDismissCover) { item = nil })
            }
        }
    }
}
#endif

extension View {
    /// 浮在内容上的控件背景：iOS 26 / macOS 26 用玻璃，之前的系统用毛玻璃材质
    @ViewBuilder
    func tvboxGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}
