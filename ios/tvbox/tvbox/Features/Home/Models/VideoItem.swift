import Foundation

struct VideoItem: Identifiable, Codable {
    let id: String
    let title: String
    let thumbnail: String
    let url: String
    let category: Category.CategoryType
    let description: String?
    let year: Int?
    let area: String?
    let director: String?
    let actors: [String]?
    let rating: Double?
    let episodes: [Episode]?
    
    struct Episode: Identifiable, Codable {
        let id: String
        let title: String
        let url: String
        let index: Int
    }
} 