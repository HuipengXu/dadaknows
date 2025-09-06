//
//  AIManager.swift
//  DadaKnows
//
//  AI智能调度中心 - 处理与AI服务的交互
//

import Foundation
import Combine

@MainActor
class AIManager: ObservableObject {
    static let shared = AIManager()
    
    @Published var isLoading = false
    @Published var currentResponse = ""
    @Published var error: Error?
    
    private let apiClient = APIClient.shared
    private let supabaseClient = SupabaseClient.shared
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
                do {
                    await MainActor.run {
                        self.isLoading = true
                        self.currentResponse = ""
                        self.error = nil
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
