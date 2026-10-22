import Foundation
import Testing
@testable import tvbox

struct PlaybackSettingsTests {
    @Test func autoPlayNextDefaultsToEnabledAndPersists() {
        let defaults = UserDefaults.standard
        let key = "auto_play_next"
        let previousValue = defaults.object(forKey: key)
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.removeObject(forKey: key)
        #expect(PlaybackSettings.autoPlayNext)

        PlaybackSettings.autoPlayNext = false
        #expect(!PlaybackSettings.autoPlayNext)
        #expect(defaults.object(forKey: key) as? Bool == false)

        PlaybackSettings.autoPlayNext = true
        #expect(PlaybackSettings.autoPlayNext)
        #expect(defaults.object(forKey: key) as? Bool == true)
    }
}
