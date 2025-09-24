//
//  LocalAIManager.swift
//  DadaKnows
//
//  本地AI模型管理器 - 使用llama.cpp框架
//

import Foundation
import SwiftUI
import Combine

@MainActor
class LocalAIManager: ObservableObject {
    static let shared = LocalAIManager()
    
    @Published var isAvailable = false
    @Published var isLoading = false
    @Published var error: Error?
    @Published var modelStatus: ModelStatus = .notDownloaded
    @Published var showDownloadPrompt = false
    
    private let llamaCppManager = LlamaCppManager.shared
    private let modelManager = ModelManager.shared
    private let modelDownloader = ModelDownloader.shared
    
    private init() {
        checkAvailability()
        updateModelStatus()
        
        // 监听下载状态变化
        modelDownloader.$downloadState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] downloadState in
                self?.handleDownloadStateChange(downloadState)
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Availability Check
    
    /// 检查设备是否支持llama.cpp本地模型
    private func checkAvailability() {
        // llama.cpp支持iOS 17.0+
        if #available(iOS 17.0, *) {
            isAvailable = true
            if Config.isDebug {
                print("📱 LocalAI: 设备支持llama.cpp (iOS 17.0+)")
            }
        } else {
            isAvailable = false
            if Config.isDebug {
                print("📱 LocalAI: 设备不支持llama.cpp (需要iOS 17.0+)")
            }
        }
    }
    
    /// 获取设备支持状态的详细信息
    func getAvailabilityStatus() -> LocalAIAvailabilityStatus {
        if #available(iOS 17.0, *) {
            return .supported
        } else {
            let currentVersion = UIDevice.current.systemVersion
            return .unsupportedVersion(currentVersion: currentVersion, requiredVersion: "17.0")
        }
    }
    
    /// 更新模型状态
    private func updateModelStatus() {
        modelStatus = modelManager.getModelStatus()
        
        if Config.isDebug {
            print("📱 LocalAI: 模型状态 - \(modelStatus.localizedDescription)")
        }
    }
    
    /// 处理下载状态变化
    private func handleDownloadStateChange(_ downloadState: DownloadState) {
        switch downloadState {
        case .idle:
            updateModelStatus()
        case .downloading:
            modelStatus = .downloading(progress: modelDownloader.downloadProgress)
        case .paused:
            modelStatus = .downloading(progress: modelDownloader.downloadProgress)
        case .extracting:
            modelStatus = .extracting
        case .completed:
            modelStatus = .ready
            Task {
                await loadModelIfNeeded()
            }
        case .failed(let error):
            modelStatus = .error(error.localizedDescription)
            self.error = error
        }
    }
    
    // MARK: - Model Management
    
    /// 检查并加载模型（如果需要）
    private func loadModelIfNeeded() async {
        guard isAvailable && modelStatus.isReady else { return }
        
        // 如果模型已经加载，直接返回
        if llamaCppManager.isModelLoaded { return }
        
        guard let modelPath = modelManager.getModelPath() else {
            if Config.isDebug {
                print("⚠️ LocalAI: 模型文件不存在")
            }
            return
        }
        
        do {
            try await llamaCppManager.loadModel(at: modelPath)
            if Config.isDebug {
                print("✅ LocalAI: llama.cpp模型加载成功")
            }
        } catch {
            self.error = error
            if Config.isDebug {
                print("❌ LocalAI: 模型加载失败 - \(error)")
            }
        }
    }
    
    /// 卸载模型释放内存
    func unloadModel() {
        llamaCppManager.unloadModel()
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
                
                // 检查模型状态
                if !modelStatus.isReady {
                    // 如果模型未下载，显示下载提示
                    await MainActor.run {
                        self.showDownloadPrompt = true
                    }
                    continuation.finish(throwing: LocalAIError.modelNotReady)
                    return
                }
                
                // 确保模型已加载
                await self.loadModelIfNeeded()
                
                await self.processQuestionWithLlamaCpp(
                    question: question,
                    targetAge: targetAge,
                    language: language,
                    continuation: continuation
                )
            }
        }
    }
    
    /// 使用llama.cpp处理问题
    private func processQuestionWithLlamaCpp(
        question: String,
        targetAge: Int,
        language: String,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async {
        do {
            await MainActor.run {
                self.isLoading = true
                self.error = nil
            }
            
            // 构建适合儿童的提示词
            let ageAppropriatePrompt = buildAgeAppropriatePrompt(
                question: question,
                targetAge: targetAge,
                language: language
            )
            
            // 使用llama.cpp生成回答
            let responseStream = llamaCppManager.generateResponse(prompt: ageAppropriatePrompt)
            
            for try await chunk in responseStream {
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
    
    // MARK: - Model Download Management
    
    /// 开始下载模型
    func startModelDownload(background: Bool = false) async throws {
        try await modelDownloader.startDownload(background: background)
    }
    
    /// 暂停下载
    func pauseModelDownload() async {
        await modelDownloader.pauseDownload()
    }
    
    /// 取消下载
    func cancelModelDownload() async {
        await modelDownloader.cancelDownload()
    }
    
    /// 删除模型
    func deleteModel() throws {
        unloadModel()
        try modelManager.deleteModel()
        updateModelStatus()
    }
    
    /// 获取模型存储使用情况
    func getModelStorageInfo() -> (used: Int64, available: Int64) {
        let used = modelManager.getModelStorageSize()
        let available = modelManager.checkAvailableStorage()
        return (used, available)
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
    case modelNotReady
    case modelNotInitialized
    case generationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return NSLocalizedString("本地AI模型不可用", comment: "")
        case .modelNotReady:
            return NSLocalizedString("本地模型未准备就绪，请先下载模型", comment: "")
        case .modelNotInitialized:
            return NSLocalizedString("本地AI模型未初始化", comment: "")
        case .generationFailed(let error):
            return String(format: NSLocalizedString("生成失败：%@", comment: ""), error.localizedDescription)
        }
    }
}
