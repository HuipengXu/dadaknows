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
        // 从UserDefaults加载保存的模型选择（默认使用云端模型）
        if UserDefaults.standard.object(forKey: "useGeminiModel") != nil {
            self.useGeminiModel = UserDefaults.standard.bool(forKey: "useGeminiModel")
        } else {
            // 首次启动，默认使用云端模型
            self.useGeminiModel = true
            UserDefaults.standard.set(true, forKey: "useGeminiModel")
        }

        // 如果设备不支持本地模型，确保使用Gemini
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
                    // 使用Gemini模型，根据用户类型计入不同计数
                    if self.subscriptionManager.isProMember {
                        // Pro用户：增加月度使用次数
                        self.subscriptionManager.incrementMonthlyUsage()
                        print("📊 Pro用户月度使用次数 +1，当前: \(self.subscriptionManager.monthlyUsageCount)")
                    } else {
                        // 免费用户：增加日使用次数
                        self.subscriptionManager.incrementQuestionCount()
                        print("📊 免费用户日使用次数 +1")
                    }
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

            // 检查本地模型是否已下载并准备好使用
            guard localAIManager.modelStatus.isReady else {
                // 根据具体状态给出不同的错误提示
                switch localAIManager.modelStatus {
                case .notDownloaded:
                    throw AIError.localModelNotDownloaded
                case .downloading, .paused, .extracting:
                    throw AIError.localModelNotAvailable
                case .error(_):
                    throw AIError.localModelNotAvailable
                case .ready:
                    // 理论上不会走到这里，因为上面已经检查过 isReady
                    throw AIError.localModelNotAvailable
                }
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
            // 智能错误恢复：如果是本地模型相关错误，自动切换到云端模型
            if let aiError = error as? AIError {
                await handleLocalModelError(aiError)
            }

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

            if Config.isDebug {
                print("🤖 AIManager: 开始处理云端模型请求，用户类型: \(subscriptionManager.isProMember ? "Pro" : "免费")")
            }

            // Pro用户检查月度限制
            if subscriptionManager.isProMember {
                let canAsk = await subscriptionManager.canAskQuestion()
                let remaining = subscriptionManager.monthlyRemaining
                if Config.isDebug {
                    print("📊 AIManager: Pro用户额度检查 - 剩余: \(remaining)，当前已用: \(subscriptionManager.monthlyUsageCount)")
                }
                if !canAsk {
                    if Config.isDebug {
                        print("❌ AIManager: Pro用户月度额度已用完")
                    }
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
                
                let offlineMessage = NSLocalizedString("offline_message", comment: "")
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
            
            // 成功获取回答后，从服务器获取最新使用次数（仅限Pro用户）
            // 注意：服务器端的 ask-dada 函数已经增加了计数，这里只需要同步即可
            if await MainActor.run(body: { self.subscriptionManager.isProMember }) {
                // 延迟一小段时间确保服务器端已完成计数更新
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                await subscriptionManager.fetchMonthlyUsage()
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

    /// 检查本地模型是否可以使用（已下载且设备支持）
    var isLocalModelReady: Bool {
        return localAIManager.isAvailable && localAIManager.modelStatus.isReady
    }

    /// 获取本地模型的完整状态信息
    func getLocalModelStatusInfo() -> (isSupported: Bool, isDownloaded: Bool, status: ModelStorageStatus) {
        return (
            isSupported: localAIManager.isAvailable,
            isDownloaded: localAIManager.modelStatus.isReady,
            status: localAIManager.modelStatus
        )
    }
    
    /// 获取本地模型的可用性状态
    func getLocalModelStatus() -> LocalAIAvailabilityStatus {
        return localAIManager.getAvailabilityStatus()
    }

    // MARK: - Error Recovery

    /// 处理本地模型错误，智能切换到云端模型
    private func handleLocalModelError(_ error: AIError) async {
        // 只处理本地模型相关的错误
        switch error {
        case .localModelNotDownloaded, .localModelDeleted, .localModelNotAvailable:
            break // 继续处理这些错误
        default:
            return // 其他错误不处理
        }

        // 如果当前已经在使用云端模型，不需要切换
        guard !useGeminiModel else {
            return
        }

        // 自动切换到云端模型
        useGeminiModel = true

        if Config.isDebug {
            print("🔄 AIManager: 检测到本地模型错误，自动切换到云端模型 - \(error.localizedDescription)")
        }
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
                return NSLocalizedString("认证失败，请检查网络连接或稍后重试。", comment: "")
            case 403:
                return NSLocalizedString("访问被拒绝，可能是API配额已用完。", comment: "")
            case 404:
                return NSLocalizedString("服务暂时不可用，请稍后重试。", comment: "")
            case 429:
                return NSLocalizedString("请求过于频繁，请稍等片刻再试。", comment: "")
            case 500...599:
                return NSLocalizedString("服务器暂时出现问题，请稍后重试。", comment: "")
            case -1009:
                return NSLocalizedString("网络连接已断开，请检查网络设置。", comment: "")
            case -1001:
                return NSLocalizedString("请求超时，请检查网络连接。", comment: "")
            default:
                break
            }
        }

        let errorDescription = error.localizedDescription.lowercased()
        if errorDescription.contains("network") || errorDescription.contains("internet") {
            return NSLocalizedString("网络连接出现问题，请检查网络设置后重试。", comment: "")
        } else if errorDescription.contains("timeout") {
            return NSLocalizedString("请求超时，请稍后重试。", comment: "")
        } else if errorDescription.contains("json") || errorDescription.contains("decode") {
            return NSLocalizedString("数据解析出现问题，请稍后重试。", comment: "")
        }

        return NSLocalizedString("抱歉，出现了一些问题，请稍后重试。如果问题持续，请联系客服。", comment: "")
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
            var parserState: StreamParserState = .idle
            var buffer = ""
            
            for try await chunk in stream {
                // Append chunk to buffer
                buffer += chunk
                
                var processedBuffer = ""
                var remainingBuffer = buffer
                
                while !remainingBuffer.isEmpty {
                    switch parserState {
                    case .idle:
                        if let range = remainingBuffer.range(of: "<think>") {
                            // Found start tag
                            let prefix = remainingBuffer[..<range.lowerBound]
                            if !prefix.isEmpty {
                                // Append content before tag to message
                                if let index = chatHistory.firstIndex(where: { $0.id == responseId }) {
                                    chatHistory[index].message += String(prefix)
                                } else {
                                    chatHistory.append(ChatMessage(id: responseId, message: String(prefix), isFromUser: false))
                                }
                            }
                            
                            // Switch to thinking state
                            parserState = .thinking
                            // Update UI state
                            if let index = chatHistory.firstIndex(where: { $0.id == responseId }) {
                                chatHistory[index].isThinking = true
                            } else {
                                chatHistory.append(ChatMessage(id: responseId, message: "", isFromUser: false, isThinking: true))
                            }
                            
                            remainingBuffer = String(remainingBuffer[range.upperBound...])
                        } else {
                            // No start tag found yet
                            // Check if buffer ends with partial tag
                            if "<think>".hasPrefix(remainingBuffer) || remainingBuffer.hasSuffix("<") || remainingBuffer.hasSuffix("<t") || remainingBuffer.hasSuffix("<th") || remainingBuffer.hasSuffix("<thi") || remainingBuffer.hasSuffix("<thin") || remainingBuffer.hasSuffix("<think") {
                                // Wait for more data
                                processedBuffer = "" // Don't process partial tag
                                break // Break inner loop to get more data
                            } else {
                                // Safe to append everything
                                if let index = chatHistory.firstIndex(where: { $0.id == responseId }) {
                                    var textToAppend = remainingBuffer
                                    // If the message is currently empty, trim leading whitespace from the new content
                                    if chatHistory[index].message.isEmpty {
                                        textToAppend = textToAppend.trimmingCharacters(in: .whitespacesAndNewlines)
                                    }
                                    chatHistory[index].message += textToAppend
                                } else {
                                    // New message
                                    let textToAppend = remainingBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                                    chatHistory.append(ChatMessage(id: responseId, message: textToAppend, isFromUser: false))
                                }
                                remainingBuffer = ""
                            }
                        }
                        
                    case .thinking:
                        if let range = remainingBuffer.range(of: "</think>") {
                            // Found end tag
                            let thoughtContent = remainingBuffer[..<range.lowerBound]
                            if !thoughtContent.isEmpty {
                                if let index = chatHistory.firstIndex(where: { $0.id == responseId }) {
                                    chatHistory[index].thought = (chatHistory[index].thought ?? "") + String(thoughtContent)
                                }
                            }
                            
                            // Switch back to idle (answering)
                            parserState = .idle
                            // Update UI state
                            if let index = chatHistory.firstIndex(where: { $0.id == responseId }) {
                                chatHistory[index].isThinking = false
                            }
                            
                            var remainingAfterTag = String(remainingBuffer[range.upperBound...])
                            // Aggressively trim leading newlines and whitespace
                            remainingAfterTag = remainingAfterTag.trimmingCharacters(in: .whitespacesAndNewlines)
                            remainingBuffer = remainingAfterTag
                        } else {
                            // No end tag found yet
                            // Check for partial end tag
                            let endTag = "</think>"
                            var partialMatch = false
                            for i in 1..<endTag.count {
                                let suffix = String(endTag.prefix(i))
                                if remainingBuffer.hasSuffix(suffix) {
                                    partialMatch = true
                                    // Append everything BEFORE the partial match
                                    let safeContent = remainingBuffer.dropLast(i)
                                    if !safeContent.isEmpty {
                                        if let index = chatHistory.firstIndex(where: { $0.id == responseId }) {
                                            chatHistory[index].thought = (chatHistory[index].thought ?? "") + String(safeContent)
                                        }
                                    }
                                    remainingBuffer = suffix // Keep suffix in buffer
                                    break
                                }
                            }
                            
                            if partialMatch {
                                break // Break inner loop to get more data
                            } else {
                                // Safe to append everything
                                if let index = chatHistory.firstIndex(where: { $0.id == responseId }) {
                                    chatHistory[index].thought = (chatHistory[index].thought ?? "") + remainingBuffer
                                }
                                remainingBuffer = ""
                            }
                        }
                    }
                }
                
                // Update buffer for next iteration
                buffer = remainingBuffer
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
    case localModelNotDownloaded
    case localModelDeleted
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
            return NSLocalizedString("本地模型不可用，请切换到云端模型", comment: "")
        case .localModelNotDownloaded:
            return NSLocalizedString("本地模型未下载，请先下载模型后再使用", comment: "")
        case .localModelDeleted:
            return NSLocalizedString("本地模型已被删除，已自动切换到云端模型", comment: "")
        case .monthlyLimitExceeded:
            return NSLocalizedString("您本月的3000次问答额度已用完，请下月再来或切换到本地模型使用。", comment: "")
        }
    }
}

enum StreamParserState {
    case idle
    case thinking
}
