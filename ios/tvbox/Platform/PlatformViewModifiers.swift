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

    @ViewBuilder
    func tvboxStatusBar(hidden: Bool) -> some View {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        self.statusBar(hidden: hidden)
        #else
        self
        #endif
    }

    @ViewBuilder
    func tvboxFullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        self.fullScreenCover(isPresented: isPresented, content: content)
        #else
        self.sheet(isPresented: isPresented, content: content)
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
