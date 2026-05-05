import Foundation

enum AppLogger {
    static func debug(
        _ message: @autoclosure () -> Any,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        #if DEBUG
        Swift.print(message())
        #endif
    }
}
