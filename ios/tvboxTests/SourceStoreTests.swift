import Foundation
import Testing
@testable import tvbox

struct SourceStoreTests {
    /// 保存的来源按站点格式写回去，读出来线路和剧集都不变
    @Test func vodInfoRoundTrip() throws {
        let json = """
        {"vod_id": 12, "vod_name": "庆余年", "vod_year": "2019", "vod_remarks": "全46集", "vod_score": "8.0",
         "vod_play_from": "量子资源$$$非凡资源",
         "vod_play_url": "第01集$https://a.com/1.m3u8#第02集$https://a.com/2.m3u8$$$第01集$https://b.com/1.m3u8"}
        """
        let original = try JSONDecoder().decode(VodInfo.self, from: Data(json.utf8))
        let restored = try JSONDecoder().decode(VodInfo.self, from: JSONEncoder().encode(original))

        #expect(restored.vodId == "12")
        #expect(restored.vodName == "庆余年")
        #expect(restored.vodRemarks == "全46集")
        #expect(restored.vodScore == 8.0)
        #expect(restored.playFlags == ["量子资源", "非凡资源"])
        #expect(restored.playUrls == original.playUrls)
        #expect(restored.playUrls[0][1] == VodInfo.VodPlayItem(name: "第02集", url: "https://a.com/2.m3u8"))
    }
}
