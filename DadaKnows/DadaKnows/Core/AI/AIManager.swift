//
//  AIManager.swift
//  DadaKnows
//
//  AI智能调度中心 - 处理与AI服务的交互
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AIManager: ObservableObject {
    static let shared = AIManager()
    
    @Published var isLoading = false
    @Published var currentResponse = ""
    // Chat history used by ChatView
    @Published var chatHistory: [ChatMessage] = []
    @Published var error: Error?
    
    // 标记是否正在使用端侧模型
    @Published var isUsingOnDeviceModel = false
    
    private let apiClient = APIClient.shared
    private let supabaseClient = SupabaseClient.shared
    private let offlineManager = OfflineManager.shared
    private let subscriptionManager = SubscriptionManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Core Ask Function with Streaming
    func askQuestion(
        question: String,
        targetAge: Int,
        language: String = "zh-CN",
        previousAnswer: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                // 如果不是端侧模型，则增加使用次数计数
                if !self.isUsingOnDeviceModel {
                    self.subscriptionManager.incrementQuestionCount()
                }
                
                do {
                    await MainActor.run {
                        self.isLoading = true
                        self.currentResponse = ""
                        self.error = nil
                    }
                    
                    // 检查是否有缓存的答案
                    if let cachedAnswer = offlineManager.getCachedAnswer(
                        question: question,
                        targetAge: targetAge,
                        language: language
                    ) {
                        // 模拟流式输出缓存的答案
                        let words = cachedAnswer.split(separator: " ")
                        for (index, word) in words.enumerated() {
                            try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒延迟
                            let chunk = index == 0 ? String(word) : " " + String(word)
                            continuation.yield(chunk)
                        }
                        continuation.finish()
                        return
                    }
                    
                    // 检查网络状态
                    if !offlineManager.isOnline {
                        // 离线模式：添加到队列并返回离线提示
                        offlineManager.addToOfflineQueue(
                            question: question,
                            targetAge: targetAge,
                            language: language
                        )
                        
                        let offlineMessage = "您当前处于离线状态。这个问题已经保存，我们会在网络恢复后为您处理。现在您可以浏览一些离线内容！"
                        continuation.yield(offlineMessage)
                        continuation.finish()
                        return
                    }
                    
                    // 使用 Supabase Edge Function 进行真实的AI调用
                    let streamingResponse = supabaseClient.callAskDadaFunction(
                        question: question,
                        targetAge: targetAge,
                        language: language,
                        previousAnswer: previousAnswer
                    )
                    
                    for try await chunk in streamingResponse {
                        continuation.yield(chunk)
                        await MainActor.run {
                            self.currentResponse += chunk
                        }
                    }
                    
                    continuation.finish()
                    
                    // 缓存答案
                    await MainActor.run {
                        if !self.currentResponse.isEmpty {
                            self.offlineManager.cacheAnswer(
                                question: question,
                                answer: self.currentResponse,
                                targetAge: targetAge,
                                language: language
                            )
                        }
                        self.isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        self.error = error
                        self.isLoading = false
                    }
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Regenerate Answer
    func regenerateAnswer(
        for question: String,
        targetAge: Int,
        language: String = "zh-CN",
        previousAnswer: String
    ) -> AsyncThrowingStream<String, Error> {
        return askQuestion(
            question: question,
            targetAge: targetAge,
            language: language,
            previousAnswer: previousAnswer
        )
    }
    
    // MARK: - Helper Methods
    func clearCurrentResponse() {
        currentResponse = ""
        error = nil
    }

    func clearChatHistory() {
        chatHistory.removeAll()
    }
}

// MARK: - Chat Message Support

extension AIManager {
    /// Simple helper to send a message and append it to the chat history.
    /// This is a stub implementation to unblock compilation; you can replace it with a real streaming call later.
    @MainActor
    func sendMessage(_ text: String, targetAge: Int) async {
        // Add the user's question
        chatHistory.append(ChatMessage(message: text, isFromUser: true))

        let responseId = UUID()
        var isFirstChunk = true

        // Call askQuestion
        do {
            let stream = askQuestion(question: text, targetAge: targetAge)
            for try await chunk in stream {
                if isFirstChunk {
                    // On the first chunk, create the AI message
                    chatHistory.append(ChatMessage(id: responseId, message: chunk, isFromUser: false))
                    isFirstChunk = false
                } else {
                    // For subsequent chunks, append to the existing message
                    if let index = chatHistory.firstIndex(where: { $0.id == responseId }) {
                        chatHistory[index].message += chunk
                    }
                }
            }
        } catch {
            // If an error occurs, show an error message.
            // Check if we already have a bubble to update, otherwise create a new one.
            if let index = chatHistory.firstIndex(where: { $0.id == responseId }) {
                chatHistory[index].message = "抱歉，我好像出错了..."
                chatHistory[index].isError = true
            } else {
                chatHistory.append(ChatMessage(id: responseId, message: "抱歉，我好像出错了...", isFromUser: false, isError: true))
            }
            self.error = error
        }
    }
}

// MARK: - Supporting Types
struct AIRequest {
    let question: String
    let targetAge: Int
    let language: String
    let previousAnswer: String?
}

struct AIResponse {
    let answer: String
    let requestId: String
    let timestamp: Date
}

enum AIError: LocalizedError {
    case invalidRequest
    case networkError(Error)
    case streamingError
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Invalid request"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .streamingError:
            return "Streaming response error"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        }
    }
}
