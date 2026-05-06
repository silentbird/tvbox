import Foundation

class HomeContentViewModel: ObservableObject {
    @Published var categories: [MovieCategory] = []
    @Published var recommendMovies: [MovieItem] = []
    @Published var doubanCategories: [DoubanCategory] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let spiderManager = SpiderManager.shared
    private let apiConfig = ApiConfig.shared

    private static var doubanCache: [String: [MovieItem]] = [:]
    private static var doubanCacheDate: String = ""

    func loadData() {
        AppLogger.debug("[HomeContentViewModel] loadData 被调用, currentSite: \(apiConfig.currentSite?.name ?? "nil")")

        categories = []
        recommendMovies = []
        doubanCategories = []
        error = nil

        guard apiConfig.currentSite != nil else {
            AppLogger.debug("[HomeContentViewModel] 没有当前站点，加载豆瓣分类")
            loadDoubanCategories()
            return
        }

        isLoading = true

        Task {
            do {
                let content = try await spiderManager.homeContent(filter: true)
                await MainActor.run {
                    self.categories = content.categories
                    self.recommendMovies = content.videos
                    self.isLoading = false
                    self.error = nil
                    AppLogger.debug("[HomeContentViewModel] 加载成功: \(content.categories.count) 分类, \(content.videos.count) 视频")

                    if content.videos.isEmpty && self.categories.isEmpty {
                        self.loadDoubanCategories()
                    }
                }
            } catch {
                AppLogger.debug("[HomeContentViewModel] 加载失败: \(error)")
                await MainActor.run {
                    self.categories = []
                    self.recommendMovies = []
                    self.error = error
                    self.isLoading = false
                    self.loadDoubanCategories()
                }
            }
        }
    }

    func refresh() async {
        AppLogger.debug("[HomeContentViewModel] refresh 被调用")
        await MainActor.run {
            self.categories = []
            self.recommendMovies = []
            self.doubanCategories = []
        }
        Self.doubanCache.removeAll()
        Self.doubanCacheDate = ""
        loadData()
    }

    private func loadDoubanCategories() {
        AppLogger.debug("[HomeContentViewModel] 开始加载豆瓣分类")

        doubanCategories = DoubanCategory.allCategories

        let today = todayString()
        if Self.doubanCacheDate == today && !Self.doubanCache.isEmpty {
            AppLogger.debug("[HomeContentViewModel] 使用豆瓣缓存")
            for i in 0..<doubanCategories.count {
                if let cached = Self.doubanCache[doubanCategories[i].id] {
                    doubanCategories[i].movies = cached
                }
            }
            return
        }

        for i in 0..<doubanCategories.count {
            loadDoubanCategory(index: i)
        }
    }

    private func loadDoubanCategory(index: Int) {
        guard index < doubanCategories.count else { return }

        let category = doubanCategories[index]

        let urlString = category.apiUrl
            .replacingOccurrences(of: "热门", with: "%E7%83%AD%E9%97%A8")
            .replacingOccurrences(of: "豆瓣高分", with: "%E8%B1%86%E7%93%A3%E9%AB%98%E5%88%86")
            .replacingOccurrences(of: "国产剧", with: "%E5%9B%BD%E4%BA%A7%E5%89%A7")
            .replacingOccurrences(of: "综艺", with: "%E7%BB%BC%E8%89%BA")

        guard let url = URL(string: urlString) else {
            AppLogger.debug("[HomeContentViewModel] 豆瓣分类[\(category.name)] URL无效: \(urlString)")
            return
        }

        DispatchQueue.main.async {
            self.doubanCategories[index].isLoading = true
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(UA.shared.random(), forHTTPHeaderField: "User-Agent")
        request.setValue("https://movie.douban.com/", forHTTPHeaderField: "Referer")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")

        Task {
            do {
                AppLogger.debug("[HomeContentViewModel] 请求豆瓣分类[\(category.name)]: \(url.absoluteString)")
                let (data, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    AppLogger.debug("[HomeContentViewModel] 豆瓣分类[\(category.name)] 响应状态: \(httpResponse.statusCode)")
                }

                let movies = parseDoubanResponse(data: data)

                await MainActor.run {
                    guard index < self.doubanCategories.count else { return }
                    self.doubanCategories[index].movies = movies
                    self.doubanCategories[index].isLoading = false

                    Self.doubanCache[category.id] = movies
                    Self.doubanCacheDate = self.todayString()

                    AppLogger.debug("[HomeContentViewModel] 豆瓣分类[\(category.name)]加载成功: \(movies.count) 条")
                }
            } catch {
                AppLogger.debug("[HomeContentViewModel] 豆瓣分类[\(category.name)]加载失败: \(error)")
                await MainActor.run {
                    guard index < self.doubanCategories.count else { return }
                    self.doubanCategories[index].isLoading = false
                }
            }
        }
    }

    private func parseDoubanResponse(data: Data) -> [MovieItem] {
        var movies: [MovieItem] = []

        if let jsonString = String(data: data, encoding: .utf8) {
            AppLogger.debug("[HomeContentViewModel] 豆瓣响应数据: \(jsonString.prefix(500))...")
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                AppLogger.debug("[HomeContentViewModel] 解析JSON失败")
                return movies
            }

            var dataArray: [[String: Any]] = []

            if let data = json["data"] as? [[String: Any]] {
                dataArray = data
            } else if let subjects = json["subjects"] as? [[String: Any]] {
                dataArray = subjects
            }

            for item in dataArray {
                let title = item["title"] as? String ?? ""
                guard !title.isEmpty else { continue }

                var rate = ""
                if let rateStr = item["rate"] as? String {
                    rate = rateStr
                } else if let ratingDict = item["rating"] as? [String: Any],
                          let average = ratingDict["average"] as? Double {
                    rate = String(format: "%.1f", average)
                }

                let cover = item["cover"] as? String ?? item["cover_url"] as? String ?? ""

                let movie = MovieItem(
                    vodId: "douban_\(title.hashValue)",
                    vodName: title,
                    vodPic: cover,
                    vodRemarks: rate.isEmpty || rate == "0" || rate == "0.0" ? nil : "⭐ \(rate)"
                )
                movies.append(movie)
            }
        } catch {
            AppLogger.debug("[HomeContentViewModel] 解析豆瓣数据异常: \(error)")
        }

        return movies
    }

    private func todayString() -> String {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let month = cal.component(.month, from: Date())
        let day = cal.component(.day, from: Date())
        return "\(year)\(month)\(day)"
    }
}
