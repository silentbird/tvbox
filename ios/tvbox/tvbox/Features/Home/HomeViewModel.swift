import Foundation
import Combine

class HomeViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var selectedCategory: Category.CategoryType = .movie
    @Published var categories: [Category] = []
    @Published var videos: [VideoItem] = []
    @Published var searchText: String = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadCategories()
        loadMockData()
    }
    
    private func loadCategories() {
        // TODO: 实现分类加载逻辑
    }
    
    private func loadMockData() {
        videos = [
            VideoItem(
                id: "1",
                title: "流浪地球3",
                thumbnail: "https://picsum.photos/400/600",
                url: "https://example.com/video1",
                category: .movie,
                description: "在不远的未来，太阳即将毁灭，人类在地球表面建造出巨大的推进器，寻找新的家园。然而宇宙之路危机四伏，为了拯救地球，流浪地球时代的年轻人再次挺身而出，展开争分夺秒的生死之战。",
                year: 2025,
                area: "中国",
                director: "郭帆",
                actors: ["吴京", "刘德华", "李雪健"],
                rating: 8.5,
                episodes: nil
            ),
            VideoItem(
                id: "2",
                title: "三体",
                thumbnail: "https://picsum.photos/400/601",
                url: "https://example.com/video2",
                category: .tv,
                description: "文化大革命如火如荼进行的同时，军方探寻外星文明的绝秘计划\"红岸工程\"取得了突破性进展。但在按下发射键的那一刻，历经劫难的叶文洁没有意识到，她彻底改变了人类的命运。地球文明向宇宙发出的第一声啼鸣，以太阳为中心，以光速向宇宙深处飞驰……",
                year: 2024,
                area: "中国",
                director: "杨磊",
                actors: ["张鲁一", "于和伟", "陈瑾"],
                rating: 8.8,
                episodes: [
                    VideoItem.Episode(id: "e1", title: "第1集", url: "https://example.com/ep1", index: 1),
                    VideoItem.Episode(id: "e2", title: "第2集", url: "https://example.com/ep2", index: 2),
                    VideoItem.Episode(id: "e3", title: "第3集", url: "https://example.com/ep3", index: 3)
                ]
            ),
            VideoItem(
                id: "3",
                title: "奔跑吧",
                thumbnail: "https://picsum.photos/400/602",
                url: "https://example.com/video3",
                category: .variety,
                description: "《奔跑吧》是浙江卫视推出的户外竞技真人秀节目，由浙江卫视节目中心制作。节目采用主题模式，在设置上融入具有地方特色的标志性建筑，能够更好地展现城市特色和人文魅力。",
                year: 2024,
                area: "中国",
                director: "姚军",
                actors: ["李晨", "杨颖", "郑恺", "沙溢"],
                rating: 7.5,
                episodes: [
                    VideoItem.Episode(id: "e1", title: "第1期", url: "https://example.com/ep1", index: 1),
                    VideoItem.Episode(id: "e2", title: "第2期", url: "https://example.com/ep2", index: 2)
                ]
            ),
            VideoItem(
                id: "4",
                title: "咒术回战",
                thumbnail: "https://picsum.photos/400/603",
                url: "https://example.com/video4",
                category: .anime,
                description: "少年虎杖悠仁的祖父在临终前嘱托他要\"帮助他人\"，并希望他加入某个组织。某天，为了从\"咒物\"危机中解救学姐，他吃下了特级咒物\"两面宿傩的手指\"，让\"宿傩\"这种诅咒跟自己合二为一。",
                year: 2024,
                area: "日本",
                director: "朴性厚",
                actors: ["榎木淳弥", "内田雄马", "濑户麻沙美"],
                rating: 9.0,
                episodes: [
                    VideoItem.Episode(id: "e1", title: "第1话", url: "https://example.com/ep1", index: 1),
                    VideoItem.Episode(id: "e2", title: "第2话", url: "https://example.com/ep2", index: 2)
                ]
            ),
            VideoItem(
                id: "5",
                title: "蓝色星球",
                thumbnail: "https://picsum.photos/400/604",
                url: "https://example.com/video5",
                category: .documentary,
                description: "《蓝色星球》是英国广播公司自然历史部制作的纪录片系列，展现了海洋世界的壮丽与神秘。从热带珊瑚礁到极地冰层，从浅海到深海，这部纪录片带领观众探索海洋生态系统的奥秘。",
                year: 2023,
                area: "英国",
                director: "大卫·阿滕伯勒",
                actors: ["大卫·阿滕伯勒"],
                rating: 9.5,
                episodes: [
                    VideoItem.Episode(id: "e1", title: "第1集", url: "https://example.com/ep1", index: 1),
                    VideoItem.Episode(id: "e2", title: "第2集", url: "https://example.com/ep2", index: 2)
                ]
            )
        ]
    }
    
    func loadVideos(for category: Category.CategoryType) {
        selectedCategory = category
        isLoading = true
        // TODO: 实现分类数据加载
        isLoading = false
    }
    
    func search() {
        // TODO: 实现搜索逻辑
    }
} 
