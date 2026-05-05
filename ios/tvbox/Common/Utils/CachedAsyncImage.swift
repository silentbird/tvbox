import Foundation
import SwiftUI

struct CachedAsyncImage: View {
    let urlString: String?
    @State private var image: TVBoxPlatformImage?
    @State private var isLoading = false

    private static var imageCache = NSCache<NSString, TVBoxPlatformImage>()

    var body: some View {
        Group {
            if let image = image {
                #if canImport(UIKit)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                #elseif canImport(AppKit)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                #endif
            } else {
                placeholderView
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }

    private var placeholderView: some View {
        LinearGradient(
            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func loadImage() {
        guard let urlString = urlString, !urlString.isEmpty else { return }
        guard !isLoading else { return }

        if let cached = Self.imageCache.object(forKey: urlString as NSString) {
            self.image = cached
            return
        }

        guard let url = URL(string: urlString) else { return }

        isLoading = true

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        if urlString.contains("douban") {
            request.setValue(UA.shared.random(), forHTTPHeaderField: "User-Agent")
            request.setValue("https://www.douban.com/", forHTTPHeaderField: "Referer")
        } else {
            request.setValue(UA.shared.random(), forHTTPHeaderField: "User-Agent")
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let platformImage = TVBoxPlatformImage(data: data) {
                    Self.imageCache.setObject(platformImage, forKey: urlString as NSString)
                    await MainActor.run {
                        self.image = platformImage
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            } catch {
                AppLogger.debug("[CachedAsyncImage] 加载失败: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}
