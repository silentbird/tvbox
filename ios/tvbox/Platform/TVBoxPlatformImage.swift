import Foundation

#if canImport(UIKit)
import UIKit
typealias TVBoxPlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias TVBoxPlatformImage = NSImage
#endif
