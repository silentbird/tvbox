//
//  tvboxApp.swift
//  tvbox
//
//  Created by fly on 2025/4/3.
//

import SwiftUI

#if os(iOS) && !targetEnvironment(macCatalyst)
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    /// 只在 iPhone 播放视频时锁定横屏，其它页面保持原来的方向设置
    static var playerOrientationMask: UIInterfaceOrientationMask?

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return .all }
        return Self.playerOrientationMask ?? .allButUpsideDown
    }
}
#endif

@main
struct tvboxApp: App {
    #if os(iOS) && !targetEnvironment(macCatalyst)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}

#if !targetEnvironment(macCatalyst)
#Preview {
    MainView()
}
#endif
