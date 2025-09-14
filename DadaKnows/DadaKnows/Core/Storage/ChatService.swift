//
//  ChatService.swift
//  DadaKnows
//
//  聊天记录服务 - 处理聊天记录的本地和云端同步
//

import Foundation
import Supabase
import CoreData
import Combine

@MainActor
class ChatService: ObservableObject {
    static let shared = ChatService()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var syncStatus: SyncStatus = .idle
    
    private let supabase = SupabaseClient.shared
    // Use a lazy var to avoid evaluating DataManager.shared during ChatService initialization,
    // which would create a circular dependency between the two singletons.
    private lazy var dataManager = DataManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // 当前会话ID（来自 chat_sessions.id）
    @Published var currentSessionId: Int?
    
    // 离线队列 - 存储待同步的聊天记录
    private var pendingSyncChats: [PendingSyncChat] = []
    
    private init() {
        setupAuthListener()
        loadPendingSyncChats()
    }
    
    // MARK: - Auth State Listener
    
    private func setupAuthListener() {
        AuthManager.shared.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    Task {
                        await self?.syncPendingChats()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Chat Operations
    
    func createAndSyncChat(question: String, answer: String, targetAge: Int, language: String) async -> Chat {
        // 先创建本地聊天记录
        let localChat = dataManager.createChat(
            question: question,
            answer: answer,
            targetAge: targetAge,
            language: language
        )
        
        // 尝试同步到云端
        await syncChatToCloud(localChat)
        
        return localChat
    }
    
    // MARK: - Session Management
    func startNewSessionIfNeeded(title: String?) async {
        // 如果已存在会话，不重复创建
        if currentSessionId != nil { return }
        guard AuthManager.shared.isAuthenticated else { return }
        do {
            let sessionId = try await supabase.createChatSession(title: title)
            currentSessionId = sessionId
        } catch {
            // 忽略错误：未登录或网络错误时允许无会话继续，本地数据仍能保存
            print("创建会话失败: \(error)")
        }
    }
    
    func endCurrentSession() {
        currentSessionId = nil
    }
    
    func syncChatToCloud(_ chat: Chat) async {
        guard AuthManager.shared.isAuthenticated,
              let currentUser = AuthManager.shared.currentUser,
              let chatId = chat.id,
              let question = chat.question,
              let answer = chat.answer,
              let language = chat.language,
              let _ = chat.createdAt else {
            
            // 如果用户未登录或数据不完整，添加到待同步队列
            addToPendingSyncQueue(chat)
            return
        }
        
        do {
            // 确保用户配置存在于云端（解决RLS策略问题）
            try await ensureUserProfileExists()
            
            // 如果没有当前会话ID，为旧聊天记录创建一个临时会话
            var sessionIdToUse = currentSessionId
            if sessionIdToUse == nil {
                do {
                    sessionIdToUse = try await supabase.createChatSession(title: String(question.prefix(80)))
                } catch {
                    print("为旧聊天记录创建会话失败: \(error)")
                    // 如果创建会话失败，跳过同步这条记录
                    return
                }
            }
            
            let chatRequest = ChatRequest(
                uuid: chatId.uuidString,
                userId: currentUser.id.uuidString,
                parentChatId: nil, // 暂时不支持父聊天
                sessionId: sessionIdToUse,
                questionText: question,
                answerText: answer,
                targetAge: Int(chat.targetAge),
                language: language,
                userFeedback: chat.userFeedback ?? "none"
            )
            
            try await supabase.supabase
                .from("chats")
                .upsert(chatRequest, onConflict: "uuid")
                .execute()
            
            // 标记为已同步
            markChatAsSynced(chat)
            
        } catch {
            print("同步聊天记录到云端失败: \(error)")
            // 添加到待同步队列
            addToPendingSyncQueue(chat)
        }
    }
    
    func fetchChatsFromCloud(limit: Int = 50) async -> [CloudChat] {
        guard AuthManager.shared.isAuthenticated,
              let currentUser = AuthManager.shared.currentUser else {
            return []
        }
        
        isLoading = true
        
        do {
            let response: [ChatResponse] = try await supabase.supabase
                .from("chats")
                .select("*")
                .eq("user_id", value: currentUser.id.uuidString)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            
            let cloudChats = response.map { chatResponse in
                CloudChat(
                    id: chatResponse.id,
                    uuid: chatResponse.uuid,
                    userId: chatResponse.userId,
                    parentChatId: chatResponse.parentChatId,
                    questionText: chatResponse.questionText,
                    answerText: chatResponse.answerText,
                    targetAge: chatResponse.targetAge,
                    language: chatResponse.language,
                    userFeedback: chatResponse.userFeedback,
                    createdAt: ISO8601DateFormatter().date(from: chatResponse.createdAt) ?? Date()
                )
            }
            
            isLoading = false
            return cloudChats
            
        } catch {
            errorMessage = "获取云端聊天记录失败: \(error.localizedDescription)"
            print("获取云端聊天记录失败: \(error)")
            isLoading = false
            return []
        }
    }
    
    func syncAllChatsToCloud() async {
        guard AuthManager.shared.isAuthenticated else { return }
        
        syncStatus = .syncing
        
        do {
            // 确保用户配置存在于云端（解决RLS策略问题）
            try await ensureUserProfileExists()
            
            // 获取所有本地聊天记录
            let localChats = dataManager.fetchChats()
            
            for chat in localChats {
                await syncChatToCloud(chat)
            }
            
            // 同步待同步队列中的聊天记录
            await syncPendingChats()
            
            syncStatus = .completed
            print("✅ 初始数据同步完成")
            
        } catch {
            print("同步所有聊天记录失败: \(error)")
            syncStatus = .failed
        }
    }
    
    func syncChatsFromCloud() async {
        guard AuthManager.shared.isAuthenticated else { return }
        
        syncStatus = .syncing
        
        let cloudChats = await fetchChatsFromCloud()
        
        // 将云端聊天记录同步到本地
        for cloudChat in cloudChats {
            await syncCloudChatToLocal(cloudChat)
        }
        
        syncStatus = .completed
    }
    
    // MARK: - Offline Sync Management
    
    private func addToPendingSyncQueue(_ chat: Chat) {
        guard let chatId = chat.id,
              let question = chat.question,
              let answer = chat.answer,
              let language = chat.language,
              let createdAt = chat.createdAt else {
            return
        }
        
        let pendingChat = PendingSyncChat(
            localId: chatId.uuidString,
            question: question,
            answer: answer,
            targetAge: Int(chat.targetAge),
            language: language,
            userFeedback: chat.userFeedback ?? "none",
            createdAt: createdAt,
            sessionId: currentSessionId // 可能为nil，这是正常的，会在同步时处理
        )
        
        pendingSyncChats.append(pendingChat)
        savePendingSyncChats()
    }
    
    private func syncPendingChats() async {
        guard AuthManager.shared.isAuthenticated,
              let currentUser = AuthManager.shared.currentUser else {
            return
        }
        
        // 确保用户配置存在于云端（解决RLS策略问题）
        do {
            try await ensureUserProfileExists()
        } catch {
            print("确保用户配置存在失败: \(error)")
            return
        }
        
        var syncedChats: [String] = []
        
        for pendingChat in pendingSyncChats {
            do {
                // 如果待同步的聊天记录没有会话ID，创建一个临时会话
                var sessionIdToUse = pendingChat.sessionId
                if sessionIdToUse == nil {
                    do {
                        sessionIdToUse = try await supabase.createChatSession(title: String(pendingChat.question.prefix(80)))
                    } catch {
                        print("为待同步聊天记录创建会话失败: \(error)")
                        // 如果创建会话失败，跳过这条记录
                        continue
                    }
                }
                
                let chatRequest = ChatRequest(
                    uuid: pendingChat.localId,
                    userId: currentUser.id.uuidString,
                    parentChatId: nil,
                    sessionId: sessionIdToUse,
                    questionText: pendingChat.question,
                    answerText: pendingChat.answer,
                    targetAge: pendingChat.targetAge,
                    language: pendingChat.language,
                    userFeedback: pendingChat.userFeedback
                )
                
                try await supabase.supabase
                    .from("chats")
                    .upsert(chatRequest, onConflict: "uuid")
                    .execute()
                
                syncedChats.append(pendingChat.localId)
                
            } catch {
                print("同步待同步聊天记录失败: \(error)")
            }
        }
        
        // 移除已同步的聊天记录
        pendingSyncChats.removeAll { syncedChats.contains($0.localId) }
        savePendingSyncChats()
    }
    
    private func markChatAsSynced(_ chat: Chat) {
        // 这里可以添加一个标记字段来表示聊天记录已同步
        // 暂时通过移除待同步队列中的记录来处理
        if let chatId = chat.id {
            pendingSyncChats.removeAll { $0.localId == chatId.uuidString }
            savePendingSyncChats()
        }
    }
    
    private func syncCloudChatToLocal(_ cloudChat: CloudChat) async {
        // 检查本地是否已存在该聊天记录
        let request: NSFetchRequest<Chat> = Chat.fetchRequest()
        let uuid = UUID(uuidString: cloudChat.uuid) ?? UUID()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        
        do {
            let existingChats = try dataManager.context.fetch(request)
            if existingChats.isEmpty {
                // 本地不存在，创建新的聊天记录
                let newChat = Chat(context: dataManager.context)
                newChat.id = UUID(uuidString: cloudChat.uuid)
                newChat.question = cloudChat.questionText
                newChat.answer = cloudChat.answerText
                newChat.targetAge = Int16(cloudChat.targetAge)
                newChat.language = cloudChat.language
                newChat.userFeedback = cloudChat.userFeedback
                newChat.createdAt = cloudChat.createdAt
                
                dataManager.save()
            }
        } catch {
            print("同步云端聊天记录到本地失败: \(error)")
        }
    }
    
    // MARK: - Persistence
    
    private func loadPendingSyncChats() {
        if let data = UserDefaults.standard.data(forKey: "PendingSyncChats"),
           let chats = try? JSONDecoder().decode([PendingSyncChat].self, from: data) {
            pendingSyncChats = chats
        }
    }
    
    private func savePendingSyncChats() {
        if let data = try? JSONEncoder().encode(pendingSyncChats) {
            UserDefaults.standard.set(data, forKey: "PendingSyncChats")
        }
    }
    
    // MARK: - Helper Methods
    
    /// 确保用户配置存在于云端，解决RLS策略问题
    private func ensureUserProfileExists() async throws {
        guard let currentUser = AuthManager.shared.currentUser else {
            throw SupabaseError.userNotAuthenticated
        }
        // 定义一个轻量级的结构体，仅用于存在性检查，避免解码缺少字段错误
        struct UserIdOnly: Codable { let id: String }
        // 仅查询 id 字段
        let existingProfile: [UserIdOnly] = try await supabase.supabase
            .from("users")
            .select("id")
            .eq("id", value: currentUser.id.uuidString)
            .execute()
            .value

        // 如果用户配置不存在，创建一个
        if existingProfile.isEmpty {
            let userProfile = UserProfileRequest(
                id: currentUser.id.uuidString,
                nickname: nil,
                avatarUrl: nil,
                preferredLanguage: "zh-CN",
                subscriptionStatus: "free"
            )
            
            try await supabase.supabase
                .from("users")
                .upsert(userProfile, onConflict: "id")
                .execute()
            
            print("✅ 用户配置已自动创建")
        }
    }
}

// MARK: - Data Models

enum SyncStatus {
    case idle
    case syncing
    case completed
    case failed
}

struct CloudChat {
    let id: Int
    let uuid: String
    let userId: String
    let parentChatId: Int?
    let questionText: String
    let answerText: String?
    let targetAge: Int
    let language: String
    let userFeedback: String
    let createdAt: Date
}

struct PendingSyncChat: Codable {
    let localId: String
    let question: String
    let answer: String
    let targetAge: Int
    let language: String
    let userFeedback: String
    let createdAt: Date
    let sessionId: Int?
}

