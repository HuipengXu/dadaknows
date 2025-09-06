//
//  MainTabView.swift
//  DadaKnows
//
//  主要的Tab导航界面
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                        .font(.system(size: 20))
                    Text("首页")
                        .font(.caption)
                }
                .tag(0)
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "person.fill" : "person")
                        .font(.system(size: 20))
                    Text("我")
                        .font(.caption)
                }
                .tag(1)
        }
        .accentColor(.vibrantOrange)
        .onAppear {
            // Customize tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.white.opacity(0.95))
            
            // Normal state
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.lightGray)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor(Color.lightGray)
            ]
            
            // Selected state
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.vibrantOrange)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(Color.vibrantOrange)
            ]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    MainTabView()
}
