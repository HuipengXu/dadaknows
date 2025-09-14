//
//  MainTabView.swift
//  DadaKnows
//
//  iOS原生风格的Tab导航界面
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var offlineManager = OfflineManager.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab - 提问界面
            HomeView()
                .tabItem {
                    Image(systemName: "house")
                    Text("首页")
                }
                .tag(0)
            
            // History Tab - 对话历史
            QAHistoryView()
                .tabItem {
                    Image(systemName: "clock")
                    Text("历史")
                }
                .tag(1)
            
            // Settings Tab - 设置
            ProfileView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("设置")
                }
                .tag(2)
        }
        .tint(.appPrimary) // 使用iOS原生的tint颜色
        .overlay(alignment: .top) {
            // 网络状态指示器
            if !offlineManager.isOnline {
                NetworkStatusBanner()
            }
        }
    }
}

#Preview {
    MainTabView()
}
