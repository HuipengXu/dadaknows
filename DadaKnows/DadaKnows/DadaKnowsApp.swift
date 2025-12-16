//
//  DadaKnowsApp.swift
//  DadaKnows
//
//  Created by xuhuipeng on 2025/9/5.
//

import SwiftUI
import GoogleSignIn
import Supabase

@main
struct DadaKnowsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Pre-warm singleton managers to avoid UI freezes on first interaction
        AppInitializer.initialize()
        
        // Set default language to English if not already set
        if UserDefaults.standard.object(forKey: "AppleLanguages") == nil {
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AIManager.shared)
                .environmentObject(AnalyticsManager.shared)
                .environmentObject(SubscriptionManager.shared)
                .environmentObject(OfflineManager.shared)
                .environment(\.managedObjectContext, DataManager.shared.persistentContainer.viewContext)
                .task {
                    await SubscriptionManager.shared.loadProducts()

                    // 启动数据一致性检查
                    UsageConsistencyChecker.shared.schedulePeriodicCheck()
                }
        }
    }
}
