import Foundation

struct Category: Identifiable, Codable {
    let id: String
    let name: String
    let type: CategoryType
    let filterable: Bool
    
    enum CategoryType: String, Codable {
        case movie = "movie"
        case tv = "tv"
        case variety = "variety"
        case anime = "anime"
        case documentary = "documentary"
        case other = "other"
    }
} 