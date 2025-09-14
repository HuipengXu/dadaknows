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
                }
        }
    }
}
