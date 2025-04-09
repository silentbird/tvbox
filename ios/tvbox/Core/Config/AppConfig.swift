import Foundation

class AppConfig {
    static let shared = AppConfig()
    
    private let defaults = UserDefaults.standard
    private let apiHostKey = "api_host"
    private let defaultAPIHost = "http://your-default-api-host"
    private let sourcesKey = "sources"
    private let currentSourceKey = "current_source"
    
    var apiHost: String {
        get {
            return defaults.string(forKey: apiHostKey) ?? defaultAPIHost
        }
        set {
            defaults.set(newValue, forKey: apiHostKey)
        }
    }
    
    private init() {}
    
    func getSources() -> [Source] {
        guard let data = defaults.data(forKey: sourcesKey) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([Source].self, from: data)
        } catch {
            print("Failed to decode sources: \(error)")
            return []
        }
    }
    
    func updateSources(_ sources: [Source]) {
        do {
            let data = try JSONEncoder().encode(sources)
            defaults.set(data, forKey: sourcesKey)
        } catch {
            print("Failed to encode sources: \(error)")
        }
    }
    
    func getCurrentSource() -> Source? {
        guard let data = defaults.data(forKey: currentSourceKey) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(Source.self, from: data)
        } catch {
            print("Failed to decode current source: \(error)")
            return nil
        }
    }
    
    func setCurrentSource(_ source: Source) {
        do {
            let data = try JSONEncoder().encode(source)
            defaults.set(data, forKey: currentSourceKey)
        } catch {
            print("Failed to encode current source: \(error)")
        }
    }
} 