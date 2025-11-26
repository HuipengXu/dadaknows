//
//  LocalAIManager.swift
//  DadaKnows
//
//  本地AI模型管理器 - 使用MLX Swift框架
//  集成所有本地模型相关组件
//
//  更新日期: 2025-10-04
//

import Foundation
import SwiftUI
import Combine

@MainActor
class LocalAIManager: ObservableObject {
    static let shared = LocalAIManager()
    
    // MARK: - Published Properties
    
    /// 设备是否支持本地AI
    @Published var isAvailable = false
    
    /// 是否正在处理（加载模型或生成答案）
    @Published var isLoading = false
    
    /// 错误信息
    @Published var error: Error?
    
    /// 模型状态
    @Published var modelStatus: ModelStorageStatus = .notDownloaded
    
    /// 模型是否已加载到内存（用于UI显示）
    var isModelLoaded: Bool {
        return mlxManager.isModelLoaded
    }
    
    /// 是否显示下载提示
    @Published var showDownloadPrompt = false
    
    /// 下载进度（0.0 - 1.0）
    @Published var downloadProgress: Double = 0.0
    
    /// 下载状态消息
    @Published var downloadStatusMessage: String = ""
    
    // MARK: - Private Properties
    
    private let mlxManager = MLXManager.shared
    private let storageManager = MLXStorageManager.shared
    private let downloadManager = ModelDownloadManager.shared
    // private let aiManager = AIManager.shared // Removed to avoid circular dependency
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        checkAvailability()
        updateModelStatus()
        setupObservers()
        
        if Config.isDebug {
            print("📱 LocalAI: 本地AI管理器初始化")
        }
    }
    
    // MARK: - Setup
    
    /// 设置观察者
    private func setupObservers() {
        // 监听 MLX 模型加载状态
        mlxManager.$isModelLoaded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoaded in
                self?.handleMLXModelStateChange(isLoaded)
            }
            .store(in: &cancellables)
        
        // 监听下载进度
        downloadManager.$downloadProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.downloadProgress = progress
            }
            .store(in: &cancellables)
        
        // 监听下载状态消息
        downloadManager.$statusMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.downloadStatusMessage = message
            }
            .store(in: &cancellables)
        
        // 监听暂停状态
        downloadManager.$isPaused
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPaused in
                if isPaused {
                    self?.modelStatus = .paused
                }
            }
            .store(in: &cancellables)
        
        // 监听下载状态
        downloadManager.$isDownloading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isDownloading in
                guard let self = self else { return }
                if isDownloading && !self.downloadManager.isPaused {
                    self.modelStatus = .downloading
                } else if !isDownloading && !self.downloadManager.isPaused {
                    // 下载停止后，等待一下再更新状态，确保解压完成
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                        self.updateModelStatus()
                    }
                }
            }
            .store(in: &cancellables)
        
        // 注意：新的下载方案不需要解压，已移除 isExtracting 监听
        
        // 监听下载错误
        downloadManager.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error = error {
                    self?.handleDownloadError(error)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Availability Check
    
    /// 检查设备是否支持MLX本地模型
    private func checkAvailability() {
        // 按app要求支持iOS 17.0+
        if #available(iOS 17.0, *) {
            isAvailable = true
            if Config.isDebug {
                print("📱 LocalAI: 设备支持MLX (iOS 17.0+)")
            }
        } else {
            isAvailable = false
            if Config.isDebug {
                print("📱 LocalAI: 设备不支持MLX (需要iOS 17.0+)")
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
    
    // MARK: - Model Status Management
    
    /// 更新模型状态
    private func updateModelStatus() {
        // 如果正在下载，保持当前状态
        if downloadManager.isDownloading {
            modelStatus = .downloading
            return
        }
        
        // 注意：新的下载方案不需要解压，已移除 isExtracting 检查
        
        // 检查模型是否准备就绪
        if storageManager.isModelReady() {
            modelStatus = .ready
        } else {
            modelStatus = .notDownloaded
        }
        
        if Config.isDebug {
            print("📱 LocalAI: 模型状态 - \(modelStatus.localizedDescription)")
        }
    }
    
    /// 处理MLX模型状态变化
    private func handleMLXModelStateChange(_ isLoaded: Bool) {
        updateModelStatus()
        if Config.isDebug {
            print("📱 LocalAI: MLX模型状态变化 - 已加载: \(isLoaded)")
        }
    }
    
    /// 处理下载错误
    private func handleDownloadError(_ error: ModelError) {
        self.error = error
        modelStatus = .error(error.localizedDescription)
        
        if Config.isDebug {
            print("❌ LocalAI: 下载错误 - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Model Download
    
    /// 开始下载模型
    func downloadModel() async throws {
        guard isAvailable else {
            throw LocalAIError.notAvailable
        }
        
        // 检查是否已经下载
        if storageManager.isModelReady() {
            if Config.isDebug {
                print("📱 LocalAI: 模型已存在，无需下载")
            }
            return
        }
        
        // 检查是否正在下载
        if downloadManager.isDownloading {
            if Config.isDebug {
                print("📱 LocalAI: 已在下载中")
            }
            return
        }
        
        // 注意：不要在这里设置 isLoading = true，让观察者自动更新
        // 状态更新完全由 Combine 观察者驱动
        
        if Config.isDebug {
            print("📱 LocalAI: 启动模型下载任务")
        }
        
        // 启动后台下载（不等待完成）
        // 下载进度和完成状态由 Combine 观察者自动更新
        try await downloadManager.startDownload()
        
        if Config.isDebug {
            print("📱 LocalAI: 下载任务已启动，等待后台完成")
        }
    }
    
    /// 暂停下载
    func pauseDownload() async {
        await downloadManager.pauseDownload()
    }
    
    /// 恢复下载
    func resumeDownload() async throws {
        try await downloadManager.resumeDownload()
    }
    
    /// 取消下载
    func cancelDownload() async {
        await downloadManager.cancelDownload()
        updateModelStatus()
    }
    
    /// 检查是否有未完成的下载
    func hasPendingDownload() -> Bool {
        return downloadManager.hasPendingDownload()
    }
    
    // MARK: - Model Loading
    
    /// 加载模型到内存
    private func loadModelIfNeeded() async {
        guard isAvailable else { return }
        
        // 如果模型已经加载，直接返回
        if mlxManager.isModelLoaded {
            if Config.isDebug {
                print("📱 LocalAI: 模型已在内存中")
            }
            return
        }
        
        // 检查模型文件是否存在
        guard storageManager.isModelReady() else {
            if Config.isDebug {
                print("📱 LocalAI: 模型文件不存在，需要先下载")
            }
            return
        }
        
        do {
            if Config.isDebug {
                print("📱 LocalAI: 开始加载模型到内存...")
            }
            
            // 使用新的 MLXManager 加载本地模型
            try await mlxManager.loadLocalModel()
            
            if Config.isDebug {
                print("✅ LocalAI: 模型加载成功")
                mlxManager.printMemoryUsage()
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
        mlxManager.unloadModel()
        if Config.isDebug {
            print("📱 LocalAI: 模型已卸载")
        }
    }
    
    // MARK: - Question Answering
    
    /// 使用本地模型回答问题
    func askQuestion(
        question: String,
        targetAge: Int,
        language: String = "zh-CN"
    ) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task { @MainActor in
                do {
                    // 检查可用性
                    guard self.isAvailable else {
                        throw LocalAIError.notAvailable
                    }
                    
                    // 在主actor上加载模型（避免actor隔离问题）
                    await self.loadModelIfNeeded()
                    
                    // 检查模型是否加载成功
                    guard self.mlxManager.isModelLoaded else {
                        throw LocalAIError.modelNotReady
                    }
                    
                    // 处理问题
                    await self.processQuestionWithMLX(
                        question: question,
                        targetAge: targetAge,
                        language: language,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// 使用MLX处理问题
    private func processQuestionWithMLX(
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
            
            if Config.isDebug {
                print("🤖 LocalAI: 开始处理问题，构建提示词...")
            }
            
            // 构建适合儿童的提示词
            let ageAppropriatePrompt = buildAgeAppropriatePrompt(
                question: question,
                targetAge: targetAge,
                language: language
            )
            
            if Config.isDebug {
                print("🤖 LocalAI: 提示词构建完成，准备调用MLX生成...")
            }
            
            // 使用MLX生成回答
            let responseStream = try await mlxManager.generateResponse(prompt: ageAppropriatePrompt)
            
            if Config.isDebug {
                print("🤖 LocalAI: 开始接收生成流...")
            }
            
            var chunkCount = 0
            for await generation in responseStream {
                switch generation {
                case .chunk(let chunk):
                    chunkCount += 1
                    if Config.isDebug && chunkCount == 1 {
                        print("🤖 LocalAI: 收到第一个chunk")
                    }
                    continuation.yield(chunk)
                case .info(let info):
                    // 可以记录推理速度等信息
                    if Config.isDebug {
                        print("🤖 LocalAI: 生成速度 \(info.tokensPerSecond) tokens/s")
                    }
                case .toolCall(_):
                    // 本应用不使用工具调用
                    break
                }
            }
            
            if Config.isDebug {
                print("✅ LocalAI: 生成完成，共\(chunkCount)个chunks")
            }
            
            continuation.finish()
            
            await MainActor.run {
                self.isLoading = false
            }
            
        } catch {
            if Config.isDebug {
                print("❌ LocalAI: 处理问题时出错 - \(error)")
            }
            
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            continuation.finish(throwing: error)
        }
    }
    
    // MARK: - Helper Methods
    
    /// 构建适合儿童的提示词
    private func buildAgeAppropriatePrompt(
        question: String,
        targetAge: Int,
        language: String
    ) -> String {
        let languageInstruction = language.hasPrefix("zh") ? "请用中文回答" : "Please answer in English"
        
        return """
        \(languageInstruction)。你是一个专业的儿童教育助手"答答"，请为\(targetAge)岁的孩子回答以下问题。
        
        请注意：
        1. 使用适合\(targetAge)岁孩子理解的简单语言
        2. 回答要准确、有趣且富有教育意义
        3. 如果问题不适合儿童，请礼貌地引导到更合适的话题
        4. 保持积极正面的态度
        5. 回答长度适中，不要太长
        
        问题：\(question)
        """
    }
    
    // MARK: - Model Information
    
    /// 获取目标模型信息
    func getTargetModelInfo() -> LMModel {
        return mlxManager.targetModelInfo
    }
    
    /// 获取当前使用的模型信息
    func getCurrentModelInfo() -> LMModel? {
        return mlxManager.currentModelInfo
    }
    
    /// 获取模型存储信息
    func getModelStorageInfo() -> (used: Int64, available: Int64) {
        let used = storageManager.getModelStorageSize()
        let available = storageManager.getAvailableStorage()
        return (used, available)
    }
    
    // MARK: - Model Management
    
    /// 删除模型
    func deleteModel() async throws {
        if Config.isDebug {
            print("🗑️ LocalAI: 开始删除模型...")
        }
        
        // 1. 异步卸载模型并等待清理完成
        await mlxManager.unloadModelAsync()
        
        if Config.isDebug {
            print("🗑️ LocalAI: 模型已卸载，准备删除文件...")
        }
        
        // 2. 在后台线程删除模型文件（避免阻塞主线程）
        try await storageManager.deleteModelDirectoryAsync()
        
        if Config.isDebug {
            print("🗑️ LocalAI: 模型文件已删除，更新状态...")
        }
        
        // 3. 在主线程更新状态
        await MainActor.run {
            updateModelStatus()

            // 4. 检查是否需要自动切换到云端模型
            // 如果用户当前正在使用本地模型，但模型已被删除，自动切换到云端模型
            if !AIManager.shared.useGeminiModel {
                AIManager.shared.useGeminiModel = true
                if Config.isDebug {
                    print("🔄 LocalAI: 本地模型已删除，自动切换到云端模型")
                }
            }
        }
        
        if Config.isDebug {
            print("✅ LocalAI: 模型删除完成")
        }
    }
    
    /// 检查存储空间是否足够
    func checkStorageSpace() -> Bool {
        return storageManager.checkAvailableStorage()
    }
    
    /// 获取存储空间信息（用于UI显示）
    func getStorageSpaceInfo() -> (required: String, available: String, sufficient: Bool) {
        let required = ModelConfig.requiredTotalSpaceFormatted
        let available = ByteCountFormatter.string(
            fromByteCount: storageManager.getAvailableStorage(),
            countStyle: .file
        )
        let sufficient = storageManager.checkAvailableStorage()
        return (required, available, sufficient)
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