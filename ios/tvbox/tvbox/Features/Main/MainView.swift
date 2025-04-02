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
            
            Text("搜索")
                .tabItem {
                    Label("搜索", systemImage: "magnifyingglass")
                }
            
            Text("设置")
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
        }
    }
}

#Preview {
    MainView()
}
