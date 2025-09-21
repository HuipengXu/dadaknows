//
//  LocalAIManager.swift
//  DadaKnows
//
//  本地AI模型管理器 - 使用苹果Foundation Models框架
//

import Foundation
import SwiftUI
import Combine

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
class LocalAIManager: ObservableObject {
    static let shared = LocalAIManager()
    
    @Published var isAvailable = false
    @Published var isLoading = false
    @Published var error: Error?
    
    #if canImport(FoundationModels)
    private var languageModelSession: Any?
    #endif
    
    private init() {
        checkAvailability()
    }
    
    // MARK: - Availability Check
    
    /// 检查设备是否支持Foundation Models
    private func checkAvailability() {
        if #available(iOS 26.0, *) {
            isAvailable = true
            initializeModel()
        } else {
            isAvailable = false
            if Config.isDebug {
                print("📱 LocalAI: 设备不支持Foundation Models (需要iOS 26.0+)")
            }
        }
    }
    
    /// 获取设备支持状态的详细信息
    func getAvailabilityStatus() -> LocalAIAvailabilityStatus {
        if #available(iOS 26.0, *) {
            return .supported
        } else {
            let currentVersion = UIDevice.current.systemVersion
            return .unsupportedVersion(currentVersion: currentVersion, requiredVersion: "26.0")
        }
    }
    
    // MARK: - Model Initialization
    
    @available(iOS 26.0, *)
    private func initializeModel() {
        #if canImport(FoundationModels)
        Task {
            // 创建语言模型会话
            self.languageModelSession = LanguageModelSession()
            
            if Config.isDebug {
                print("✅ LocalAI: Foundation Models初始化成功")
            }
        }
        #endif
    }
    
    // MARK: - Question Answering
    
    /// 使用本地模型回答问题
    func askQuestion(
        question: String,
        targetAge: Int,
        language: String = "zh-CN"
    ) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                guard isAvailable else {
                    continuation.finish(throwing: LocalAIError.notAvailable)
                    return
                }
                
                if #available(iOS 26.0, *) {
                    await self.processQuestionWithFoundationModels(
                        question: question,
                        targetAge: targetAge,
                        language: language,
                        continuation: continuation
                    )
                } else {
                    continuation.finish(throwing: LocalAIError.notAvailable)
                }
            }
        }
    }
    
    @available(iOS 26.0, *)
    private func processQuestionWithFoundationModels(
        question: String,
        targetAge: Int,
        language: String,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async {
        #if canImport(FoundationModels)
        do {
            await MainActor.run {
                self.isLoading = true
                self.error = nil
            }
            
            guard let sessionAny = self.languageModelSession else {
                continuation.finish(throwing: LocalAIError.modelNotInitialized)
                return
            }
            
            // 构建适合儿童的提示词
            let ageAppropriatePrompt = buildAgeAppropriatePrompt(
                question: question,
                targetAge: targetAge,
                language: language
            )
            
            // 使用真实的Foundation Models API
            let session = sessionAny as! LanguageModelSession
            let response = try await session.respond(to: ageAppropriatePrompt)
            
            // 处理响应并流式输出
            let responseText = String(describing: response)
            let words = responseText.components(separatedBy: " ")
            for (index, word) in words.enumerated() {
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05秒延迟
                let chunk = index == 0 ? word : " " + word
                continuation.yield(chunk)
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
        #else
        continuation.finish(throwing: LocalAIError.notAvailable)
        #endif
    }
    
    // MARK: - Helper Methods
    
    private func buildAgeAppropriatePrompt(
        question: String,
        targetAge: Int,
        language: String
    ) -> String {
        let languageInstruction = language.hasPrefix("zh") ? "请用中文回答" : "Please answer in English"
        
        return """
        \(languageInstruction)。你是一个专业的儿童教育助手，请为\(targetAge)岁的孩子回答以下问题。
        
        请注意：
        1. 使用适合\(targetAge)岁孩子理解的简单语言
        2. 回答要准确、有趣且富有教育意义
        3. 如果问题不适合儿童，请礼貌地引导到更合适的话题
        4. 保持积极正面的态度
        
        问题：\(question)
        """
    }
}

// MARK: - Supporting Types

enum LocalAIAvailabilityStatus {
    case supported
    case unsupportedVersion(currentVersion: String, requiredVersion: String)
    
    var isSupported: Bool {
        switch self {
        case .supported:
            return true
        case .unsupportedVersion:
            return false
        }
    }
    
    var localizedDescription: String {
        switch self {
        case .supported:
            return NSLocalizedString("支持本地模型", comment: "")
        case .unsupportedVersion(let current, let required):
            return String(format: NSLocalizedString("需要iOS %@或更高版本（当前：%@）", comment: ""), required, current)
        }
    }
}

enum LocalAIError: LocalizedError {
    case notAvailable
    case modelNotInitialized
    case generationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return NSLocalizedString("本地AI模型不可用", comment: "")
        case .modelNotInitialized:
            return NSLocalizedString("本地AI模型未初始化", comment: "")
        case .generationFailed(let error):
            return String(format: NSLocalizedString("生成失败：%@", comment: ""), error.localizedDescription)
        }
    }
}
