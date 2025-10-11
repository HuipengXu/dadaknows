//
//  AIManager.swift
//  DadaKnows
//
//  AI智能调度中心 - 处理与AI服务的交互
//

import Foundation
import SwiftUI
import Combine

// MARK: - AI Model Types
enum AIModelType: String, CaseIterable {
    case gemini = "gemini"
    case local = "local"
    
    var displayName: String {
        switch self {
        case .gemini:
            return "Cloud Model (Gemini)"
        case .local:
            return "Local Model (MLX)"
        }
    }
    
    var description: String {
        switch self {
        case .gemini:
            return "Powerful, requires internet connection"
        case .local:
            return "Private, offline, unlimited usage"
        }
    }
}

@MainActor
class AIManager: ObservableObject {
    static let shared = AIManager()
    
    @Published var isLoading = false
    @Published var currentResponse = ""
    // Chat history used by ChatView
    @Published var chatHistory: [ChatMessage] = []
    @Published var error: Error?
    
    // 是否使用Gemini模型（默认false，使用本地模型）
    @Published var useGeminiModel: Bool {
        didSet {
            UserDefaults.standard.set(useGeminiModel, forKey: "useGeminiModel")
            if Config.isDebug {
                print("🔄 AIManager: 切换到\(useGeminiModel ? "Gemini" : "Local") Model")
            }
        }
    }
    
    // 当前模型类型（向后兼容）
    var currentModelType: AIModelType {
        return useGeminiModel ? .gemini : .local
    }
    
    // 标记是否正在使用端侧模型（向后兼容）
    var isUsingOnDeviceModel: Bool {
        return !useGeminiModel && localAIManager.isAvailable
    }
    
    private let apiClient = APIClient.shared
    private let supabaseClient = SupabaseClient.shared
    private let offlineManager = OfflineManager.shared
    private let subscriptionManager = SubscriptionManager.shared
    private let localAIManager = LocalAIManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // 从UserDefaults加载保存的模型选择（默认使用本地模型）
        self.useGeminiModel = UserDefaults.standard.bool(forKey: "useGeminiModel")
        
        // 如果设备不支持本地模型，自动切换到Gemini
        if !useGeminiModel && !localAIManager.isAvailable {
            useGeminiModel = true
            if Config.isDebug {
                print("⚠️ AIManager: 设备不支持MLX本地模型，自动切换到Gemini模型")
            }
        }
    }
    
    // MARK: - Core Ask Function with Streaming
    func askQuestion(
        question: String,
        targetAge: Int,
        language: String = "zh-CN",
        previousAnswer: String? = nil,
        conversationHistory: [ChatMessage]? = nil
    ) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                // 根据当前模型选择处理方式
                if self.useGeminiModel {
                    // 使用Gemini模型，计入使用次数
                    self.subscriptionManager.incrementQuestionCount()
                    await self.processWithCloudModel(
                        question: question,
                        targetAge: targetAge,
                        language: language,
                        previousAnswer: previousAnswer,
                        conversationHistory: conversationHistory,
                        continuation: continuation
                    )
                } else {
                    // 使用本地模型，不计入使用次数
                    await self.processWithLocalModel(
                        question: question,
                        targetAge: targetAge,
                        language: language,
                        continuation: continuation
                    )
                }
            }
        }
    }
    
    // MARK: - Local Model Processing
    private func processWithLocalModel(
        question: String,
        targetAge: Int,
        language: String,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async {
        do {
            await MainActor.run {
                self.isLoading = true
                self.currentResponse = ""
                self.error = nil
            }
            
            // 检查本地模型是否可用
            guard localAIManager.isAvailable else {
                throw AIError.localModelNotAvailable
            }
            
            // 使用本地模型生成回答
            let localStream = localAIManager.askQuestion(
                question: question,
                targetAge: targetAge,
                language: language
            )
            
            for try await chunk in localStream {
                continuation.yield(chunk)
                await MainActor.run {
                    self.currentResponse += chunk
                }
            }
            
            continuation.finish()
            
            await MainActor.run {
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
    
    // MARK: - Cloud Model Processing
    private func processWithCloudModel(
        question: String,
        targetAge: Int,
        language: String,
        previousAnswer: String?,
        conversationHistory: [ChatMessage]?,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async {
        do {
            await MainActor.run {
                self.isLoading = true
                self.currentResponse = ""
                self.error = nil
            }
            
            // Pro用户检查月度限制
            if subscriptionManager.isProMember {
                let canAsk = await subscriptionManager.canAskQuestion()
                if !canAsk {
                    throw AIError.monthlyLimitExceeded
                }
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
                previousAnswer: previousAnswer,
                conversationHistory: conversationHistory
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
    
    // 加载历史会话到当前聊天记录
    func loadHistoricalChat(from session: ChatSession) {
        clearChatHistory()
        let historicalMessages = session.chats.flatMap { chat -> [ChatMessage] in
            var messages: [ChatMessage] = []
            if let question = chat.question, let timestamp = chat.createdAt {
                messages.append(ChatMessage(message: question, isFromUser: true, timestamp: timestamp))
            }
            if let answer = chat.answer, let timestamp = chat.createdAt {
                // To maintain order, we can slightly increment the timestamp for the answer
                let answerTimestamp = timestamp.addingTimeInterval(1)
                messages.append(ChatMessage(message: answer, isFromUser: false, timestamp: answerTimestamp))
            }
            return messages
        }
        // Sort by timestamp to ensure correct order
        self.chatHistory = historicalMessages.sorted(by: { $0.timestamp < $1.timestamp })
    }
    
    // MARK: - Model Management
    
    /// 切换到Gemini模型
    func switchToGemini(_ enabled: Bool) -> Bool {
        // 如果要切换到本地模型但设备不支持，返回false
        if !enabled && !localAIManager.isAvailable {
            if Config.isDebug {
                print("⚠️ AIManager: 无法切换到MLX本地模型，设备不支持")
            }
            return false
        }
        
        useGeminiModel = enabled
        return true
    }
    
    /// 获取本地模型的可用性状态
    func getLocalModelStatus() -> LocalAIAvailabilityStatus {
        return localAIManager.getAvailabilityStatus()
    }
    
    /// 检查是否可以使用本地模型
    var canUseLocalModel: Bool {
        return localAIManager.isAvailable
    }
    
    // MARK: - Error Handling
    private func getErrorMessage(for error: Error) -> String {
        if let nsError = error as NSError? {
            switch nsError.code {
            case 401:
                return "认证失败，请检查网络连接或稍后重试。"
            case 403:
                return "访问被拒绝，可能是API配额已用完。"
            case 404:
                return "服务暂时不可用，请稍后重试。"
            case 429:
                return "请求过于频繁，请稍等片刻再试。"
            case 500...599:
                return "服务器暂时出现问题，请稍后重试。"
            case -1009:
                return "网络连接已断开，请检查网络设置。"
            case -1001:
                return "请求超时，请检查网络连接。"
            default:
                break
            }
        }
        
        let errorDescription = error.localizedDescription.lowercased()
        if errorDescription.contains("network") || errorDescription.contains("internet") {
            return "网络连接出现问题，请检查网络设置后重试。"
        } else if errorDescription.contains("timeout") {
            return "请求超时，请稍后重试。"
        } else if errorDescription.contains("json") || errorDescription.contains("decode") {
            return "数据解析出现问题，请稍后重试。"
        }
        
        return "抱歉，出现了一些问题，请稍后重试。如果问题持续，请联系客服。"
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

        // Create a placeholder chat record so the History tab updates instantly
        let placeholderChat = DataManager.shared.createChat(
            question: text,
            answer: "", // empty answer for now
            targetAge: targetAge,
            language: "zh-CN"
        )

        let responseId = UUID()
        var isFirstChunk = true
        let requestStartTime = Date()

        // Call askQuestion with conversation history
        do {
            let stream = askQuestion(
                question: text, 
                targetAge: targetAge,
                conversationHistory: chatHistory.isEmpty ? nil : chatHistory
            )
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

            let finalAnswer = self.currentResponse
            if !finalAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Update the placeholder chat instead of creating a duplicate
                placeholderChat.answer = finalAnswer
                DataManager.shared.save()
                // 异步同步到云端
                DataManager.shared.syncChatToCloudAsync(placeholderChat)
            }

            // Track analytics after successful save to keep counts consistent with history
            let responseTime = Date().timeIntervalSince(requestStartTime)
            AnalyticsManager.shared.trackQuestionAsked(
                question: text,
                category: "general",
                targetAge: targetAge
            )
            AnalyticsManager.shared.trackAnswerReceived(
                question: text,
                answer: finalAnswer,
                category: "general",
                targetAge: targetAge,
                responseTime: responseTime
            )
        } catch {
            // If an error occurs, show an error message.
            let errorMessage = getErrorMessage(for: error)
            
            // Check if we already have a bubble to update, otherwise create a new one.
            if let index = chatHistory.firstIndex(where: { $0.id == responseId }) {
                chatHistory[index].message = errorMessage
                chatHistory[index].isError = true
            } else {
                chatHistory.append(ChatMessage(id: responseId, message: errorMessage, isFromUser: false, isError: true))
            }
            self.error = error
            
            if Config.isDebug {
                print("❌ AI问答错误: \(error)")
            }
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
    case localModelNotAvailable
    case monthlyLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Invalid request"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .streamingError:
            return "Streaming response error"
        case .rateLimitExceeded:
            return NSLocalizedString("已达到使用限制，请稍后再试", comment: "")
        case .localModelNotAvailable:
            return NSLocalizedString("本地模型不可用，请切换到云端模型或等待模型下载完成", comment: "")
        case .monthlyLimitExceeded:
            return NSLocalizedString("您本月的3000次问答额度已用完，请下月再来或切换到本地模型使用。", comment: "")
        }
    }
}
