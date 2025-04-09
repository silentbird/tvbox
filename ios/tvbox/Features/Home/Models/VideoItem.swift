import Foundation

struct VideoItem: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let thumbnail: String
    let url: String
    let category: TestCategory.CategoryType
    let duration: String
    let rating: Double
    let year: Int
    let tags: [String]
} 