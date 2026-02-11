//
//  ContentView.swift
//  DadaKnows
//
//  Created by xuhuipeng on 2025/9/5.
//
//  备用内容视图 - 当前应用使用 MainTabView 作为主界面
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var appState = AppState.shared
    
    var body: some View {
        ZStack {
            if appState.isLoading {
                SplashView {
                    appState.isLoading = false
                }
            } else if !appState.isAuthenticated && !appState.isGuest {
                AuthView {
                    appState.signIn()
                }
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut, value: appState.isLoading)
        .animation(.easeInOut, value: appState.isAuthenticated)
    }
}

#Preview {
    ContentView()
        .environmentObject(AIManager.shared)
        .environmentObject(SubscriptionManager.shared)
        .environmentObject(OfflineManager.shared)
        .environment(\.managedObjectContext, DataManager.shared.persistentContainer.viewContext)
}
