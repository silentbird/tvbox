//
//  MainView.swift
//  tvbox
//
//  Created by fly on 2025/4/3.
//

import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
            
            Text("直播")
                .tabItem {
                    Label("直播", systemImage: "play.tv.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
        }
    }
}

#Preview {
    MainView()
} 