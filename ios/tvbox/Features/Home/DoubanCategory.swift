import Foundation

struct DoubanCategory: Identifiable {
    let id: String
    let name: String
    let icon: String
    let apiUrl: String
    var movies: [MovieItem] = []
    var isLoading: Bool = false

    static var allCategories: [DoubanCategory] {
        let year = Calendar.current.component(.year, from: Date())
        return [
            DoubanCategory(
                id: "hot",
                name: "热门推荐",
                icon: "flame.fill",
                apiUrl: "https://movie.douban.com/j/new_search_subjects?sort=U&range=0,10&tags=&playable=1&start=0&year_range=\(year),\(year)"
            ),
            DoubanCategory(
                id: "movie",
                name: "热门电影",
                icon: "film.fill",
                apiUrl: "https://movie.douban.com/j/search_subjects?type=movie&tag=热门&page_limit=20&page_start=0"
            ),
            DoubanCategory(
                id: "tv",
                name: "热门剧集",
                icon: "tv.fill",
                apiUrl: "https://movie.douban.com/j/search_subjects?type=tv&tag=热门&page_limit=20&page_start=0"
            ),
            DoubanCategory(
                id: "top_movie",
                name: "高分电影",
                icon: "star.fill",
                apiUrl: "https://movie.douban.com/j/search_subjects?type=movie&tag=豆瓣高分&page_limit=20&page_start=0"
            ),
            DoubanCategory(
                id: "cn_tv",
                name: "国产剧",
                icon: "play.tv.fill",
                apiUrl: "https://movie.douban.com/j/search_subjects?type=tv&tag=国产剧&page_limit=20&page_start=0"
            ),
            DoubanCategory(
                id: "variety",
                name: "综艺节目",
                icon: "music.mic",
                apiUrl: "https://movie.douban.com/j/search_subjects?type=tv&tag=综艺&page_limit=20&page_start=0"
            ),
        ]
    }
}
