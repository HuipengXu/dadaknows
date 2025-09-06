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
    func saveChatToDatabase(question: String, answer: String, targetAge: Int, language: String) async throws {
        // 保存聊天记录到 Supabase 数据库
        // let chatData = [
        //     "question_text": question,
        //     "answer_text": answer,
        //     "target_age": targetAge,
        //     "language": language,
        //     "user_id": getCurrentUserId(),
        //     "created_at": ISO8601DateFormatter().string(from: Date())
        // ]
        // try await supabase.from("chats").insert(chatData)
        
        print("模拟保存聊天记录: \(question)")
    }
    
    func fetchUserChats(limit: Int = 50) async throws -> [ChatRecord] {
        // 从数据库获取用户的聊天历史
        // let response = try await supabase.from("chats")
        //     .select("*")
        //     .order("created_at", ascending: false)
        //     .limit(limit)
        //     .execute()
        
        // 临时返回空数组
        return []
    }
    
    // MARK: - Edge Functions
    func callAskDadaFunction(question: String, targetAge: Int, language: String, previousAnswer: String? = nil) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // 准备请求参数
                    let _ = [
                        "question": question,
                        "age": targetAge,
                        "language": language,
                        "previousAnswer": previousAnswer ?? NSNull(),
                        "apiKey": Config.geminiAPIKey
                    ]
                    
                    // 调用 Supabase Edge Function - 添加依赖后取消注释
                    // 调用 Supabase Edge Function 进行流式响应
                    // 临时注释掉有问题的代码，使用模拟响应
                    /*
                    let functionResponse = try await supabase.functions.invoke(
                        "ask-dada",
                        options: FunctionInvokeOptions(
                            body: parameters
                        )
                    )
                    */
                    let functionResponse: (data: Data?, response: URLResponse?) = (nil, nil)
                    
                    // 处理流式响应
                    if let responseData = functionResponse.data,
                       let responseString = String(data: responseData, encoding: .utf8) {
                        
                        // 解析Server-Sent Events格式的流式数据
                        let lines = responseString.components(separatedBy: "\n")
                        
                        for line in lines {
                            if line.hasPrefix("data: ") {
                                let jsonString = String(line.dropFirst(6)) // 移除 "data: " 前缀
                                
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
                                        }
                                        return
                                    case "complete":
                                        return
                                    default:
                                        continue
                                    }
                                }
                            }
                        }
                    } else {
                        // 如果无法解析流式响应，使用增强的模拟响应作为后备
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
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
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
    private func getCurrentUserId() -> String {
        // 获取当前用户ID
        // return supabase.auth.currentUser?.id ?? ""
        return "mock-user-id"
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
