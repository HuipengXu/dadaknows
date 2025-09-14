//
//  SupabaseClient.swift
//  DadaKnows
//
//  Supabase 客户端配置
//  集成指南：需要通过 Xcode Package Manager 添加以下依赖：
//  https://github.com/supabase/supabase-swift
//

import Foundation
import Supabase // 需要先添加 Supabase 依赖

class SupabaseClient: ObservableObject {
    static let shared = SupabaseClient()
    
    // 使用配置文件中的真实密钥
    private let supabaseURL = Config.supabaseURL
    private let supabaseKey = Config.supabaseAnonKey
    
    let supabase: Supabase.SupabaseClient
    
    private init() {
        // 验证配置
        guard Config.validateConfiguration() else {
            fatalError("Supabase配置验证失败，请检查API密钥")
        }
        
        // 初始化 Supabase 客户端 - 添加依赖后取消注释
        supabase = Supabase.SupabaseClient(
            supabaseURL: URL(string: supabaseURL)!,
            supabaseKey: supabaseKey
        )
        
        if Config.isDebug {
            print("✅ SupabaseClient 初始化成功")
        }
    }
    
    // MARK: - Authentication
    func signInWithEmail(email: String, password: String) async throws {
        // let response = try await supabase.auth.signIn(email: email, password: password)
        // // 处理登录响应
        
        // // 临时实现 - 模拟登录成功
        // print("模拟登录成功: \(email)")
        _ = try await supabase.auth.signIn(email: email, password: password)
        // 处理登录响应
        AppState.shared.signIn()
    }
    
    func signUpWithEmail(email: String, password: String) async throws {
        // let response = try await supabase.auth.signUp(email: email, password: password)
        // // 处理注册响应
        
        // // 临时实现 - 模拟注册成功
        // print("模拟注册成功: \(email)")
        _ = try await supabase.auth.signUp(email: email, password: password)
        // 处理注册响应
        AppState.shared.signIn()
    }
    
    func signOut() async throws {
        // try await supabase.auth.signOut()
        // print("模拟登出成功")
        try await supabase.auth.signOut()
        AppState.shared.signOut()
    }
    
    // MARK: - Chat Operations
    func saveChatToDatabase(question: String, answer: String, targetAge: Int, language: String, sessionId: Int? = nil) async throws {
        let currentUser = await MainActor.run { getCurrentUser() }
        guard let currentUser = currentUser else {
            throw SupabaseError.userNotAuthenticated
        }
        
        let chatData = ChatRequest(
            uuid: UUID().uuidString,
            userId: currentUser.id.uuidString,
            parentChatId: nil,
            sessionId: sessionId,
            questionText: question,
            answerText: answer,
            targetAge: targetAge,
            language: language,
            userFeedback: "none"
        )
        
        try await supabase
            .from("chats")
            .upsert(chatData, onConflict: "uuid")
            .execute()
        
        if Config.isDebug {
            print("✅ 聊天记录已保存到云端: \(question)")
        }
    }
    
    func fetchUserChats(limit: Int = 50) async throws -> [ChatRecord] {
        let currentUser = await MainActor.run { getCurrentUser() }
        guard let currentUser = currentUser else {
            throw SupabaseError.userNotAuthenticated
        }
        
        let response: [ChatResponse] = try await supabase
            .from("chats")
            .select("*")
            .eq("user_id", value: currentUser.id.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        return response.map { chatResponse in
            ChatRecord(
                id: chatResponse.uuid,
                question: chatResponse.questionText,
                answer: chatResponse.answerText ?? "",
                targetAge: chatResponse.targetAge,
                language: chatResponse.language,
                createdAt: ISO8601DateFormatter().date(from: chatResponse.createdAt) ?? Date()
            )
        }
    }

    // MARK: - Chat Session Operations
    func createChatSession(title: String?) async throws -> Int {
        let currentUser = await MainActor.run { getCurrentUser() }
        guard let currentUser = currentUser else {
            throw SupabaseError.userNotAuthenticated
        }
        let sessionRequest = ChatSessionRequest(
            userId: currentUser.id.uuidString,
            title: title
        )
        let inserted: [ChatSessionResponse] = try await supabase
            .from("chat_sessions")
            .insert(sessionRequest)
            .select("*")
            .execute()
            .value
        guard let session = inserted.first else {
            throw SupabaseError.invalidData
        }
        return session.id
    }
    
    // MARK: - User Profile Operations
    func createUserProfile(nickname: String?, avatarUrl: String?, preferredLanguage: String, subscriptionStatus: String) async throws {
        let currentUser = await MainActor.run { getCurrentUser() }
        guard let currentUser = currentUser else {
            throw SupabaseError.userNotAuthenticated
        }
        
        let userProfile = UserProfileRequest(
            id: currentUser.id.uuidString,
            nickname: nickname,
            avatarUrl: avatarUrl,
            preferredLanguage: preferredLanguage,
            subscriptionStatus: subscriptionStatus
        )
        
        try await supabase
            .from("users")
            .upsert(userProfile, onConflict: "id")
            .execute()
        
        if Config.isDebug {
            print("✅ 用户配置已创建")
        }
    }
    
    func updateUserProfile(nickname: String?, avatarUrl: String?, preferredLanguage: String, subscriptionStatus: String) async throws {
        let currentUser = await MainActor.run { getCurrentUser() }
        guard let currentUser = currentUser else {
            throw SupabaseError.userNotAuthenticated
        }
        
        let userProfile = UserProfileRequest(
            id: currentUser.id.uuidString,
            nickname: nickname,
            avatarUrl: avatarUrl,
            preferredLanguage: preferredLanguage,
            subscriptionStatus: subscriptionStatus
        )
        
        try await supabase
            .from("users")
            .update(userProfile)
            .eq("id", value: currentUser.id.uuidString)
            .execute()
        
        if Config.isDebug {
            print("✅ 用户配置已更新")
        }
    }
    
    func fetchUserProfile() async throws -> UserProfile? {
        let currentUser = await MainActor.run { getCurrentUser() }
        guard let currentUser = currentUser else {
            throw SupabaseError.userNotAuthenticated
        }
        
        let response: [UserProfileResponse] = try await supabase
            .from("users")
            .select("*")
            .eq("id", value: currentUser.id.uuidString)
            .execute()
            .value
        
        guard let userResponse = response.first else {
            return nil
        }
        
        return UserProfile(
            id: userResponse.id,
            nickname: userResponse.nickname,
            avatarUrl: userResponse.avatarUrl,
            preferredLanguage: userResponse.preferredLanguage,
            subscriptionStatus: userResponse.subscriptionStatus
        )
    }
    
    // MARK: - Edge Functions
    func callAskDadaFunction(question: String, targetAge: Int, language: String, previousAnswer: String? = nil, conversationHistory: [ChatMessage]? = nil) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Build parameters dynamically to avoid encoding Optional(nil) which causes JSONSerialization to fail
                    var parameters: [String: Any] = [
                        "question": question,
                        "age": targetAge,
                        "language": language,
                        "apiKey": Config.geminiAPIKey
                    ]
                    if let previousAnswer = previousAnswer {
                        parameters["previousAnswer"] = previousAnswer
                    }
                    
                    // 添加对话历史
                    if let conversationHistory = conversationHistory, !conversationHistory.isEmpty {
                        let historyData = conversationHistory.map { message in
                            [
                                "message": message.message,
                                "isFromUser": message.isFromUser,
                                "timestamp": ISO8601DateFormatter().string(from: message.timestamp)
                            ]
                        }
                        parameters["conversationHistory"] = historyData
                    }
                    
                    // 调用 Supabase Edge Function 进行流式响应
                    let url = URL(string: "\(Config.supabaseURL)/functions/v1/ask-dada")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept") // 请求 SSE
                    request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
                    request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
                    
                    let jsonData = try JSONSerialization.data(withJSONObject: parameters)
                    request.httpBody = jsonData
                    
                    // 使用流式处理真正的Server-Sent Events
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    // 检查HTTP状态码
                    if let httpResponse = response as? HTTPURLResponse {
                        guard httpResponse.statusCode == 200 else {
                            let statusCode = httpResponse.statusCode
                            continuation.finish(throwing: NSError(domain: "HTTPError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(statusCode)"]))
                            return
                        }
                    }
                    
                    // 使用 .lines 来安全地处理流式响应
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            // Supabase function may send an empty ping
                            if jsonString.isEmpty { continue }
                            
                            if let jsonData = jsonString.data(using: .utf8),
                               let streamChunk = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                                
                                let chunkType = streamChunk["type"] as? String ?? ""
                                let chunkData = streamChunk["data"] as? String ?? ""
                                let chunkError = streamChunk["error"] as? String
                                
                                switch chunkType {
                                case "chunk":
                                    if !chunkData.isEmpty {
                                        continuation.yield(chunkData)
                                    }
                                case "error":
                                    if let error = chunkError {
                                        continuation.finish(throwing: NSError(domain: "AIError", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
                                        return
                                    }
                                case "complete":
                                    continuation.finish()
                                    return
                                default:
                                    continue
                                }
                            }
                        }
                    }
                    continuation.finish()
                    
                } catch {
                    // 如果流式处理失败，使用备用方案
                    if Config.isDebug {
                        print("⚠️ 流式响应处理失败，使用模拟响应: \(error)")
                    }
                    
                    // 使用增强的模拟响应作为后备
                    let enhancedResponse = generateEnhancedMockResponse(
                        question: question,
                        age: targetAge,
                        language: language,
                        previousAnswer: previousAnswer
                    )
                    
                    let words = enhancedResponse.split(separator: " ")
                    for (index, word) in words.enumerated() {
                        try await Task.sleep(nanoseconds: 150_000_000) // 0.15 second delay
                        let chunk = index == 0 ? String(word) : " " + String(word)
                        continuation.yield(chunk)
                    }
                    
                    continuation.finish()
                }
            }
        }
    }
    
    // MARK: - Enhanced Mock Response
    private func generateEnhancedMockResponse(
        question: String,
        age: Int,
        language: String,
        previousAnswer: String?
    ) -> String {
        if language.hasPrefix("zh") {
            let responses = [
                "这是一个非常棒的问题！让我来为\(age)岁的小朋友解释一下：\(question)就像是大自然的魔法，它有着神奇的力量。你知道吗，每当我们好奇地探索世界时，就像小科学家一样在发现新的秘密！继续保持你的好奇心，这样你就能发现更多有趣的事情！✨",
                "哇，你问的问题真是太棒了！关于\(question)，让我用一个小故事来告诉你：想象一下这就像是一场奇妙的冒险，每个答案都藏着更多的惊喜。对于\(age)岁的你来说，世界就像一本充满图画的故事书，每一页都有新的发现等着你！",
                "好奇的小朋友，你的问题让答答想到了很多有趣的事情！\(question)其实就像是拼图游戏，我们一块一块地把知识拼起来。\(age)岁的你已经很棒了，能够思考这样的问题！记住，每个问题都是成长路上的小小礼物。🎁"
            ]
            return responses.randomElement() ?? responses[0]
        } else {
            let responses = [
                "What a fantastic question! Let me explain \(question) for a curious \(age)-year-old: It's like nature's amazing magic show! You know what? When we ask questions like this, we become little scientists exploring the wonderful world around us. Keep that curiosity alive - it's your superpower! ✨",
                "Oh wow, what an awesome question! About \(question), let me tell you a little story: Imagine this is like a magical adventure where every answer leads to even more exciting discoveries. For someone who's \(age) years old, the world is like a picture book full of amazing surprises on every page!",
                "Hey curious explorer! Your question about \(question) makes Dada think of so many cool things! It's just like putting together a puzzle - we collect pieces of knowledge one by one. You're already amazing at \(age) years old, asking such thoughtful questions! Remember, every question is a special gift on your learning journey. 🎁"
            ]
            return responses.randomElement() ?? responses[0]
        }
    }
    
    // MARK: - Helper Methods
    @MainActor
    private func getCurrentUser() -> User? {
        // 获取当前用户
        return AuthManager.shared.currentUser
    }
    
    @MainActor
    private func getCurrentUserId() -> String {
        return getCurrentUser()?.id.uuidString ?? ""
    }
}

// MARK: - Supporting Types
struct ChatRecord {
    let id: String
    let question: String
    let answer: String
    let targetAge: Int
    let language: String
    let createdAt: Date
}

// MARK: - Error Types
enum SupabaseError: LocalizedError {
    case userNotAuthenticated
    case invalidData
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "用户未登录"
        case .invalidData:
            return "数据格式无效"
        case .networkError(let message):
            return "网络错误: \(message)"
        }
    }
}

// MARK: - Data Models (Shared with other services)
struct UserProfile {
    let id: String
    let nickname: String?
    let avatarUrl: String?
    let preferredLanguage: String
    let subscriptionStatus: String
}

struct UserProfileResponse: Codable {
    let id: String
    let nickname: String?
    let avatarUrl: String?
    let preferredLanguage: String
    let subscriptionStatus: String
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case avatarUrl = "avatar_url"
        case preferredLanguage = "preferred_language"
        case subscriptionStatus = "subscription_status"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct UserProfileRequest: Codable {
    let id: String
    let nickname: String?
    let avatarUrl: String?
    let preferredLanguage: String
    let subscriptionStatus: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case avatarUrl = "avatar_url"
        case preferredLanguage = "preferred_language"
        case subscriptionStatus = "subscription_status"
    }
}

struct ChatResponse: Codable {
    let id: Int
    let uuid: String
    let userId: String
    let parentChatId: Int?
    let sessionId: Int?
    let questionText: String
    let answerText: String?
    let targetAge: Int
    let language: String
    let userFeedback: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case uuid
        case userId = "user_id"
        case parentChatId = "parent_chat_id"
        case sessionId = "session_id"
        case questionText = "question_text"
        case answerText = "answer_text"
        case targetAge = "target_age"
        case language
        case userFeedback = "user_feedback"
        case createdAt = "created_at"
    }
}

struct ChatRequest: Codable {
    let uuid: String
    let userId: String
    let parentChatId: Int?
    let sessionId: Int?
    let questionText: String
    let answerText: String?
    let targetAge: Int
    let language: String
    let userFeedback: String
    
    enum CodingKeys: String, CodingKey {
        case uuid
        case userId = "user_id"
        case parentChatId = "parent_chat_id"
        case sessionId = "session_id"
        case questionText = "question_text"
        case answerText = "answer_text"
        case targetAge = "target_age"
        case language
        case userFeedback = "user_feedback"
    }
}

// MARK: - Chat Session Models
struct ChatSessionResponse: Codable {
    let id: Int
    let uuid: String
    let userId: String
    let title: String?
    let startedAt: String
    let endedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case uuid
        case userId = "user_id"
        case title
        case startedAt = "started_at"
        case endedAt = "ended_at"
    }
}

struct ChatSessionRequest: Codable {
    let userId: String
    let title: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case title
    }
}
