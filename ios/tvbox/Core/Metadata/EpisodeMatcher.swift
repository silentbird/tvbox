import Foundation

/// 按规则把站点的集名对应到 TMDB 分集
enum EpisodeMatcher {
    /// 集名里完全没有数字时才按顺序对应 TMDB 分集。网盘乱序列表、综艺「20261010 第1期上」
    /// 这种带日期和上下集的，按顺序对都会错位
    static func numberByOrder(_ names: [String]) -> Bool {
        !names.contains { $0.rangeOfCharacter(from: .decimalDigits) != nil }
    }

    /// 对不上时返回 nil
    /// - Parameters:
    ///   - index: 在线路里的位置，numberByOrder 时按它对应
    ///   - numberByOrder: 见 ``numberByOrder(_:)``
    static func match(name: String, index: Int, numberByOrder: Bool, metadata: VodMetadata) -> EpisodeRef? {
        let parsedNumber = episodeNumber(name)
        let variety = varietyKey(name)
        // 综艺的上中下、加更、先导片和带日期的集名按日期和名字对应，其余按集数，识别不出集数的不套用
        if variety.isPart || variety.airDate != nil || parsedNumber == nil,
           let ref = metadata.ref(matching: variety.title, airDate: variety.airDate) {
            return ref
        }
        if let number = (variety.isPart ? nil : parsedNumber) ?? (numberByOrder ? index + 1 : nil),
           metadata.episode(number: number) != nil {
            return .episode(number)
        }
        return nil
    }

    /// 去掉括号里的文件大小、发布组和视频扩展名，网盘文件名常见「[5.4GB]01.mkv【xxx】」
    static func cleanName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "[\\[【(（][^\\]】)）]*[\\]】)）]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "(?i)\\.(mkv|mp4|avi|ts|flv|rmvb|mov|m4v|webm|iso)\\s*$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 综艺集名「20261010 第1期上」拆出播出日期 (yyyy-MM-dd) 和名字，
    /// isPart 表示上中下、加更、先导片这类分段，不能按集数对应
    static func varietyKey(_ name: String) -> (airDate: String?, title: String, isPart: Bool) {
        var title = cleanName(name)
        var airDate: String?
        if let regex = try? NSRegularExpression(pattern: "(20\\d{2})[.\\-]?(0[1-9]|1[0-2])[.\\-]?(0[1-9]|[12]\\d|3[01])(?!\\d)"),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
           let year = Range(match.range(at: 1), in: title),
           let month = Range(match.range(at: 2), in: title),
           let day = Range(match.range(at: 3), in: title),
           let full = Range(match.range, in: title) {
            airDate = "\(title[year])-\(title[month])-\(title[day])"
            title.removeSubrange(full)
            title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let isPart = title.range(of: "[上中下]$|加更|彩蛋|先导|花絮|纯享|特辑|特别篇", options: .regularExpression) != nil
        return (airDate, title, isPart)
    }

    /// 从「第01集」「EP01」「01」「[1.3GB]E09.mkv」「[5.4GB]01.mkv」「S01E09」这样的集名里取集数
    static func episodeNumber(_ name: String) -> Int? {
        let name = cleanName(name)
        let patterns = [
            "第?\\s*(\\d{1,4})\\s*[集话話]",
            "(?i)episode\\s*(\\d{1,4})",
            // E 前面不能是字母，免得把单词里的 e 当成集数；数字后面不能再跟数字
            "(?i)(?<![a-z])(?:s\\d{1,2}\\s*)?ep?\\s*(\\d{1,4})(?!\\d)",
            "^\\s*(\\d{1,4})\\s*$",
            // 「01.HD」「01 国语」这类开头是集数的，限 3 位免得把年份当集数
            "^(\\d{1,3})(?=[\\s._-])",
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
                  let range = Range(match.range(at: 1), in: name) else { continue }
            return Int(name[range])
        }
        return nil
    }
}
