//
//  DadaKnowsApp.swift
//  DadaKnows
//
//  Created by xuhuipeng on 2025/9/5.
//

import SwiftUI

@main
struct DadaKnowsApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var dataManager = DataManager.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isLoading {
                    SplashView {
                        // Loading complete, proceed to next screen
                    }
                } else if appState.isAuthenticated {
                    MainTabView()
                        .environment(\.managedObjectContext, dataManager.context)
                } else {
                    AuthView {
                        appState.signIn()
                    }
                }
            }
            .preferredColorScheme(.light) // Force light mode for consistent design
        }
    }
}
