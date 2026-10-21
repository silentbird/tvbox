import Foundation
import SwiftUI

/// 泛型类型不能有静态存储属性，缓存放在外面
private enum CachedImageStore {
    nonisolated(unsafe) static let cache = NSCache<NSString, TVBoxPlatformImage>()
}

struct CachedAsyncImage<Placeholder: View>: View {
    let urlString: String?
    var contentMode: ContentMode = .fill
    var placeholder: () -> Placeholder
    @State private var image: TVBoxPlatformImage?
    @State private var isLoading = false

    init(urlString: String?, contentMode: ContentMode = .fill, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.urlString = urlString
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = image {
                #if canImport(UIKit)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                #elseif canImport(AppKit)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                #endif
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }

    private func loadImage() {
        guard let urlString = urlString, !urlString.isEmpty else { return }
        guard !isLoading else { return }

        if let cached = CachedImageStore.cache.object(forKey: urlString as NSString) {
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
                    CachedImageStore.cache.setObject(platformImage, forKey: urlString as NSString)
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

extension CachedAsyncImage where Placeholder == LinearGradient {
    init(urlString: String?, contentMode: ContentMode = .fill) {
        self.init(urlString: urlString, contentMode: contentMode) {
            LinearGradient(
                colors: [Color.tvboxSurfaceSecondary, Color.tvboxSurfaceSecondary.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
