//
//  OfflineManager.swift
//  DadaKnows
//
//  离线数据管理器 - 处理网络断开时的数据缓存和恢复
//

import Foundation
import Network
import Combine

@MainActor
class OfflineManager: ObservableObject {
    static let shared = OfflineManager()
    
    @Published var isOnline = true
    @Published var hasPendingSync = false
    @Published var lastSyncDate: Date?
    
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    
    // Lazy to avoid circular dependency issues during singleton initialization order.
    private lazy var userService = UserService.shared
    private lazy var chatService = ChatService.shared
    
    private init() {
        setupNetworkMonitoring()
        loadLastSyncDate()
        checkPendingSync()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOnline = self?.isOnline ?? false
                self?.isOnline = path.status == .satisfied
                
                // 如果从离线变为在线，触发同步
                if !wasOnline && path.status == .satisfied {
                    Task { [weak self] in
                        await self?.handleNetworkReconnection()
                    }
                }
                
                if Config.isDebug {
                    print("🌐 网络状态: \(path.status == .satisfied ? "在线" : "离线")")
                }
            }
        }
        
        monitor.start(queue: monitorQueue)
    }
    
    private func handleNetworkReconnection() async {
        guard AuthManager.shared.isAuthenticated else { return }
        
        if Config.isDebug {
            print("🔄 网络重连，开始同步数据...")
        }
        
        // 同步用户配置
        await userService.loadUserProfile()
        
        // 同步聊天记录
        await chatService.syncAllChatsToCloud()
        await chatService.syncChatsFromCloud()
        
        // 更新同步状态
        updateLastSyncDate()
        checkPendingSync()
        
        if Config.isDebug {
            print("✅ 数据同步完成")
        }
    }
    
    // MARK: - Sync Management
    
    func forceSyncAll() async {
        guard isOnline && AuthManager.shared.isAuthenticated else {
            if Config.isDebug {
                print("⚠️ 无法同步：网络离线或用户未登录")
            }
            return
        }
        
        if Config.isDebug {
            print("🔄 开始手动同步所有数据...")
        }
        
        // 同步用户配置
        await userService.loadUserProfile()
        
        // 同步聊天记录
        await chatService.syncAllChatsToCloud()
        await chatService.syncChatsFromCloud()
        
        // 更新同步状态
        updateLastSyncDate()
        checkPendingSync()
        
        if Config.isDebug {
            print("✅ 手动同步完成")
        }
    }
    
    func checkPendingSync() {
        // 检查是否有待同步的数据
        let pendingChats = UserDefaults.standard.data(forKey: "PendingSyncChats")
        hasPendingSync = pendingChats != nil && !pendingChats!.isEmpty
    }
    
    private func updateLastSyncDate() {
        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate, forKey: "LastSyncDate")
    }
    
    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "LastSyncDate") as? Date
    }
    
    // MARK: - Cache Management
    
    func getCachedAnswer(question: String, targetAge: Int, language: String) -> String? {
        let cacheKey = "\(question)_\(targetAge)_\(language)".lowercased()
        return UserDefaults.standard.string(forKey: "cached_answer_\(cacheKey)")
    }
    
    func cacheAnswer(question: String, answer: String, targetAge: Int, language: String) {
        let cacheKey = "\(question)_\(targetAge)_\(language)".lowercased()
        UserDefaults.standard.set(answer, forKey: "cached_answer_\(cacheKey)")
        
        if Config.isDebug {
            print("💾 缓存答案: \(question)")
        }
    }
    
    func addToOfflineQueue(question: String, targetAge: Int, language: String) {
        var offlineQueue = getOfflineQueue()
        let queueItem = OfflineQueueItem(
            question: question,
            targetAge: targetAge,
            language: language,
            timestamp: Date()
        )
        offlineQueue.append(queueItem)
        saveOfflineQueue(offlineQueue)
        
        if Config.isDebug {
            print("📥 添加到离线队列: \(question)")
        }
    }
    
    private func getOfflineQueue() -> [OfflineQueueItem] {
        guard let data = UserDefaults.standard.data(forKey: "OfflineQueue"),
              let queue = try? JSONDecoder().decode([OfflineQueueItem].self, from: data) else {
            return []
        }
        return queue
    }
    
    private func saveOfflineQueue(_ queue: [OfflineQueueItem]) {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: "OfflineQueue")
        }
    }
    
    func clearOfflineCache() {
        // 清除离线缓存数据
        UserDefaults.standard.removeObject(forKey: "PendingSyncChats")
        UserDefaults.standard.removeObject(forKey: "LastSyncDate")
        
        hasPendingSync = false
        lastSyncDate = nil
        
        if Config.isDebug {
            print("🗑️ 离线缓存已清除")
        }
    }
    
    func getCacheSize() -> String {
        // 计算缓存大小（简化实现）
        let pendingChats = UserDefaults.standard.data(forKey: "PendingSyncChats")
        let sizeInBytes = pendingChats?.count ?? 0
        
        if sizeInBytes < 1024 {
            return "\(sizeInBytes) B"
        } else if sizeInBytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(sizeInBytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(sizeInBytes) / (1024.0 * 1024.0))
        }
    }
    
    // MARK: - Connectivity Helpers
    
    var networkStatusText: String {
        if isOnline {
            return "已连接"
        } else {
            return "离线"
        }
    }
    
    var networkStatusColor: String {
        return isOnline ? "green" : "red"
    }
    
    var shouldShowOfflineIndicator: Bool {
        return !isOnline
    }
    
    // MARK: - Cleanup
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - Sync Status Extensions

extension OfflineManager {
    
    var syncStatusText: String {
        if !isOnline {
            return "离线模式"
        } else if hasPendingSync {
            return "等待同步"
        } else if let lastSync = lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Locale(identifier: "zh-CN")
            return "上次同步：\(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "从未同步"
        }
    }
    
    var canSync: Bool {
        return isOnline && AuthManager.shared.isAuthenticated
    }
    
    func shouldAutoSync() -> Bool {
        guard canSync else { return false }
        
        // 如果有待同步数据，立即同步
        if hasPendingSync { return true }
        
        // 如果超过1小时未同步，自动同步
        if let lastSync = lastSyncDate {
            return Date().timeIntervalSince(lastSync) > 3600 // 1小时
        }
        
        return true // 从未同步过
    }
}

// MARK: - Supporting Types

struct OfflineQueueItem: Codable {
    let question: String
    let targetAge: Int
    let language: String
    let timestamp: Date
}