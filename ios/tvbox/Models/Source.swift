import Foundation

struct Source: Codable, Identifiable {
    let id: String
    let name: String
    let type: Int
    let api: String
    let searchable: Int
    let quickSearch: Int
    let filterable: Int
    let playerUrl: String
    let ext: String
    let jar: String
    let playerType: Int
    let categories: [String]
    let clickSelector: String
    
    enum CodingKeys: String, CodingKey {
        case id = "key"
        case name
        case type
        case api
        case searchable
        case quickSearch
        case filterable
        case playerUrl = "playUrl"
        case ext
        case jar
        case playerType
        case categories
        case clickSelector = "click"
    }
} 