//
//  MLXManager.swift
//  DadaKnows
//
//  MLX Swift核心管理器 - 本地模型加载与推理
//  参考文档: mlx_swift_local_llm_integration.md 第3.4节
//
//  功能：
//  1. 从本地路径加载模型（不使用 HuggingFace Hub 自动下载）
//  2. 流式文本生成
//  3. 内存管理和优化
//  4. 模型信息管理
//
//  创建日期: 2025-10-04
//

import Foundation
import SwiftUI
import MLX
import MLXLLM
import MLXLMCommon
import Hub

/// MLX Swift 核心管理器（单例）
@MainActor
class MLXManager: ObservableObject {
    static let shared = MLXManager()
    
    // MARK: - Published Properties
    
    /// 模型是否已加载
    @Published var isModelLoaded = false
    
    /// 是否正在加载模型
    @Published var isLoading = false
    
    /// 错误信息
    @Published var error: Error?
    
    // MARK: - Private Properties
    
    /// 当前加载的模型容器
    private var currentModelContainer: ModelContainer?
    
    /// 当前模型信息
    private var currentModel: LMModel?
    
    /// 模型缓存（避免重复加载）
    private let modelCache = NSCache<NSString, ModelContainer>()
    
    /// 存储管理器
    private let storageManager = MLXStorageManager.shared
    
    /// 是否已设置内存警告监听
    private var hasSetupMemoryWarning = false
    
    // MARK: - Initialization
    
    private init() {
        if Config.isDebug {
            print("🤖 MLXManager: 初始化")
        }
    }
    
    deinit {
        currentModelContainer = nil
        if Config.isDebug {
            print("🤖 MLXManager: 资源已清理")
        }
    }
    
    // MARK: - Model Loading
    
    /// 加载本地模型
    /// 从 Documents/Models/Qwen3-4B-MLX-4bit/ 加载模型
    func loadLocalModel() async throws {
        if Config.isDebug {
            print("🤖 MLXManager: 开始加载本地模型")
        }
        
        // 检查模型是否已加载
        if isModelLoaded {
            if Config.isDebug {
                print("✅ MLXManager: 模型已加载")
            }
            return
        }
        
        // 增加isLoading检查，防止重复加载
        if isLoading {
            if Config.isDebug {
                print("⏳ MLXManager: 模型已在加载中，等待完成...")
            }
            // 直接返回，让UI响应isLoading状态
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            // 1. 检查模型文件是否存在
            guard storageManager.isModelReady() else {
                throw MLXError.modelNotFound("模型文件不存在，请先下载")
            }
            
            if Config.isDebug {
                print("🔍 MLXManager: 模型文件检查通过")
            }
            
            // 2. 性能优化配置（在模型加载前设置）
            if Config.isDebug {
                print("🔍 MLXManager: 准备设置性能优化")
            }
            setupPerformanceOptimizationSync()
            
            if Config.isDebug {
                print("🔍 MLXManager: 性能优化设置完成")
            }
            
            // 3. 加载模型容器（带超时机制）
            if Config.isDebug {
                print("🔍 MLXManager: 开始创建任务组")
            }
            
            let container = try await withThrowingTaskGroup(of: ModelContainer.self) { group in
                group.addTask {
                    try await self.loadModelContainerFromLocal()
                }
                
                // 添加超时任务
                group.addTask {
                    try await Task.sleep(nanoseconds: 60_000_000_000) // 60秒超时
                    throw MLXError.modelLoadFailed("模型加载超时（60秒）")
                }
                
                // 返回第一个完成的任务结果
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
            
            // 4. 更新状态
            currentModelContainer = container
            currentModel = LMModel(
                name: ModelConfig.modelName,
                configuration: ModelConfiguration(directory: storageManager.modelDirectory),
                type: .llm
            )
            isModelLoaded = true
            isLoading = false
            
            if Config.isDebug {
                print("✅ MLXManager: 模型加载成功")
                printModelInfo()
            }
            
        } catch {
            self.error = error
            isLoading = false
            isModelLoaded = false
            
            // 检查是否是 Metal/GPU 相关错误
            let errorDescription = error.localizedDescription
            let isMetalError = errorDescription.contains("MTL") || 
                             errorDescription.contains("Metal") ||
                             errorDescription.contains("GPU") ||
                             errorDescription.contains("Dispatch Threads")
            
            if Config.isDebug {
                print("❌ MLXManager: 模型加载失败 - \(error)")
                if isMetalError {
                    print("⚠️ MLXManager: 这是 Metal/GPU 相关错误")
                    #if targetEnvironment(simulator)
                    print("💡 MLXManager: 模拟器的 GPU 功能受限")
                    print("💡 MLXManager: 建议：")
                    print("   1. 在真机上测试本地模型功能")
                    print("   2. 或者使用云端模型（在模拟器上正常工作）")
                    #else
                    print("💡 MLXManager: 设备可能不支持 MLX 所需的 GPU 功能")
                    print("💡 MLXManager: 建议使用云端模型")
                    #endif
                }
            }
            
            throw error
        }
    }
    
    /// 从本地路径加载模型容器
    /// 核心逻辑：使用自定义 HubApi 指向本地目录
    private func loadModelContainerFromLocal() async throws -> ModelContainer {
        let cacheKey = ModelConfig.modelName as NSString
        
        // 检查缓存
        if let cachedContainer = modelCache.object(forKey: cacheKey) {
            if Config.isDebug {
                print("🤖 MLXManager: 使用缓存的模型")
            }
            return cachedContainer
        }
        
        let localModelDirectory = storageManager.modelDirectory

        if Config.isDebug {
            print("🤖 MLXManager: 从本地加载模型")
            print("   路径: \(localModelDirectory.path)")
            print("   这可能需要几秒钟，请稍候...")
        }

        // 1. 构造指向本地目录的 ModelConfiguration
        let localConfig = ModelConfiguration(directory: localModelDirectory)

        // 2. 对于本地模型，使用空的 HubApi()
        // ModelConfiguration.directory 会直接返回目录，不需要 hub 下载
        let localHub = HubApi()
        
        if Config.isDebug {
            print("🤖 MLXManager: 使用本地模型配置，路径: \(localModelDirectory.path)")
        }

        // 3. 使用 LLMModelFactory 加载本地模型
        let factory = LLMModelFactory.shared

        let container = try await factory.loadContainer(
            hub: localHub,
            configuration: localConfig
        ) { [weak self] progress in
            Task { @MainActor [weak self] in
                if Config.isDebug {
                    let percentage = Int(progress.fractionCompleted * 100)
                    print("🤖 MLXManager: 加载进度 \(percentage)%")
                }
            }
        }
        
        // 缓存模型
        modelCache.setObject(container, forKey: cacheKey)
        
        if Config.isDebug {
            print("✅ MLXManager: 模型容器加载完成")
        }
        
        return container
    }
    
    /// 性能优化设置（同步版本，在加载模型前调用）
    private func setupPerformanceOptimizationSync() {
        if Config.isDebug {
            print("⚙️ MLXManager: 开始设置性能优化")
        }
        
        // GPU内存优化 - 使用较小的初始值，避免崩溃
        // 参考官方示例的 20MB 设置
        #if targetEnvironment(simulator)
        if Config.isDebug {
            print("⚠️ MLXManager: 检测到模拟器环境")
            print("⚠️ MLXManager: 模拟器的 Metal GPU 功能受限，可能无法运行")
            print("⚠️ MLXManager: 建议在真机上测试以获得最佳体验")
        }
        // 在模拟器上也尝试设置，但可能会在后续加载时失败
        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)
        #else
        // 真机环境
        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024) // 20MB GPU缓存（参考官方示例）
        
        if Config.isDebug {
            print("⚙️ MLXManager: GPU 缓存限制设置为 20MB")
        }
        #endif
        
        // 内存警告监听（只设置一次）
        if !hasSetupMemoryWarning {
            NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleMemoryWarning()
                }
            }
            hasSetupMemoryWarning = true
            
            if Config.isDebug {
                print("⚙️ MLXManager: 内存警告监听已设置")
            }
        }
    }
    
    /// 处理内存警告
    private func handleMemoryWarning() {
        if Config.isDebug {
            print("⚠️ MLXManager: 收到内存警告，卸载模型释放内存")
        }
        unloadModel()
    }
    
    /// 卸载模型释放内存（同步版本，用于快速清理）
    func unloadModel() {
        if Config.isDebug {
            print("🤖 MLXManager: 开始卸载模型")
        }
        
        // 快速清理主要引用
        currentModelContainer = nil
        currentModel = nil
        isModelLoaded = false
        
        // 异步清理重量级资源，避免阻塞主线程
        Task.detached(priority: .background) {
            // 清理GPU内存
            MLX.GPU.clearCache()
            
            // 清理模型缓存
            await MainActor.run {
                self.modelCache.removeAllObjects()
            }
            
            if Config.isDebug {
                await MainActor.run {
                    print("✅ MLXManager: 后台清理完成")
                }
            }
        }
        
        if Config.isDebug {
            print("🤖 MLXManager: 模型已卸载，后台清理中...")
        }
    }
    
    /// 卸载模型释放内存（异步版本，等待清理完成）
    func unloadModelAsync() async {
        if Config.isDebug {
            print("🤖 MLXManager: 开始异步卸载模型")
        }
        
        // 快速清理主要引用
        currentModelContainer = nil
        currentModel = nil
        isModelLoaded = false
        
        // 等待清理完成
        await Task.detached(priority: .userInitiated) {
            // 清理GPU内存
            MLX.GPU.clearCache()
            
            // 清理模型缓存
            await MainActor.run {
                self.modelCache.removeAllObjects()
            }
            
            if Config.isDebug {
                await MainActor.run {
                    print("✅ MLXManager: 模型清理完成")
                }
            }
        }.value
    }
    
    // MARK: - Text Generation
    
    /// 生成回答（流式输出）
    /// - Parameter prompt: 输入提示词
    /// - Returns: 异步生成流
    func generateResponse(prompt: String) async throws -> AsyncStream<Generation> {
        guard isModelLoaded,
              let container = currentModelContainer else {
            throw MLXError.modelNotLoaded("模型未加载")
        }
        
        if Config.isDebug {
            print("🤖 MLXManager: 开始生成回答")
            print("   提示词: \(prompt.prefix(100))...")
        }
        
        // 准备消息输入
        let messages: [Message] = [
            .system("You are a helpful assistant for children. Answer in a friendly, educational way."),
            .user(prompt)
        ]
        
        if Config.isDebug {
            print("🤖 MLXManager: 准备消息列表完成，共\(messages.count)条消息")
        }
        
        // 转换为MLX格式的消息
        let chat = messages.map { message in
            let role: MLXLMCommon.Chat.Message.Role = switch message.role {
            case .assistant: .assistant
            case .user: .user
            case .system: .system
            }
            return MLXLMCommon.Chat.Message(role: role, content: message.content)
        }
        
        if Config.isDebug {
            print("🤖 MLXManager: 转换为MLX消息格式完成")
        }
        
        // 创建用户输入
        let userInput = UserInput(chat: chat)
        
        if Config.isDebug {
            print("🤖 MLXManager: 创建UserInput完成")
        }
        
        // 生成参数
        let parameters = GenerateParameters(
            maxTokens: 512,  // 限制最大 token 数
            temperature: 0.7,
            topP: 0.9
        )
        
        if Config.isDebug {
            print("🤖 MLXManager: 生成参数设置完成，准备调用container.perform...")
        }
        
        // 生成文本流
        return try await container.perform { (context: ModelContext) in
            // ✅ 修复：使用同步 print，避免 Actor 死锁
            // 不要在 container.perform 闭包内使用 await MainActor.run
            if Config.isDebug {
                print("🤖 MLXManager: 进入container.perform闭包，准备处理输入...")
            }
            
            let lmInput = try await context.processor.prepare(input: userInput)
            
            if Config.isDebug {
                print("🤖 MLXManager: 输入准备完成，开始生成...")
            }
            
            return try MLXLMCommon.generate(
                input: lmInput,
                parameters: parameters,
                context: context
            )
        }
    }
    
    // MARK: - Model Management
    
    /// 获取当前模型信息
    var currentModelInfo: LMModel? {
        return currentModel
    }
    
    /// 获取目标模型信息
    var targetModelInfo: LMModel {
        return LMModel(
            name: ModelConfig.modelName,
            configuration: ModelConfiguration(directory: storageManager.modelDirectory),
            type: .llm
        )
    }
    
    /// 打印模型信息（调试用）
    private func printModelInfo() {
        guard Config.isDebug else { return }
        
        let memoryLimit = GPU.memoryLimit
        let memoryLimitGB = Double(memoryLimit) / (1024 * 1024 * 1024)
        
        print("""
        
        🤖 ===== 模型信息 =====
        📦 模型名称: \(ModelConfig.modelName)
        📁 模型路径: \(storageManager.modelDirectory.path)
        💾 GPU 内存限制: \(String(format: "%.2f", memoryLimitGB)) GB
        ✅ 状态: 已加载
        ========================
        
        """)
    }
}

// MARK: - Supporting Types

/// 简化的消息结构，兼容现有代码
struct Message {
    let role: Role
    let content: String
    
    enum Role {
        case user
        case assistant
        case system
    }
    
    static func user(_ content: String) -> Message {
        Message(role: .user, content: content)
    }
    
    static func assistant(_ content: String) -> Message {
        Message(role: .assistant, content: content)
    }
    
    static func system(_ content: String) -> Message {
        Message(role: .system, content: content)
    }
}

/// MLX相关错误类型
enum MLXError: LocalizedError {
    case modelNotLoaded(String)
    case modelNotFound(String)
    case modelLoadFailed(String)
    case generationFailed(String)
    case unsupportedModel
    case insufficientMemory
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded(let message):
            return "本地模型未加载: \(message)"
        case .modelNotFound(let message):
            return "本地模型未找到: \(message)"
        case .modelLoadFailed(let message):
            return "本地模型加载失败: \(message)"
        case .generationFailed(let message):
            return "文本生成失败: \(message)"
        case .unsupportedModel:
            return "不支持的模型类型"
        case .insufficientMemory:
            return "设备内存不足，无法加载模型"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .modelNotLoaded:
            return "请先加载模型后再使用。"
        case .modelNotFound:
            return "请先下载模型文件。"
        case .modelLoadFailed:
            return "请检查模型文件完整性，或尝试重新下载。"
        case .generationFailed:
            return "请重试，或联系技术支持。"
        case .unsupportedModel:
            return "请使用支持的模型类型。"
        case .insufficientMemory:
            return "请关闭其他应用释放内存，或使用云端模型。"
        }
    }
}

/// LMModel 结构体，表示语言模型信息
struct LMModel {
    let name: String
    let configuration: ModelConfiguration
    let type: ModelType
    
    enum ModelType {
        case llm    // 大语言模型
        case vlm    // 视觉语言模型
    }
    
    var displayName: String {
        return name
    }
    
    var isLanguageModel: Bool {
        return type == .llm
    }
}

extension LMModel: Identifiable, Hashable {
    var id: String { name }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    static func == (lhs: LMModel, rhs: LMModel) -> Bool {
        return lhs.name == rhs.name
    }
}

// MARK: - Memory Usage Monitoring

extension MLXManager {
    /// 获取当前 GPU 内存使用情况
    func getMemoryUsage() -> (active: Int64, cache: Int64, peak: Int64) {
        let usage = GPU.snapshot()
        return (
            active: Int64(usage.activeMemory),
            cache: Int64(usage.cacheMemory),
            peak: Int64(usage.peakMemory)
        )
    }
    
    /// 打印内存使用情况（调试用）
    func printMemoryUsage() {
        guard Config.isDebug else { return }
        
        let usage = getMemoryUsage()
        let activeGB = Double(usage.active) / (1024 * 1024 * 1024)
        let cacheGB = Double(usage.cache) / (1024 * 1024 * 1024)
        let peakGB = Double(usage.peak) / (1024 * 1024 * 1024)
        let limitGB = Double(GPU.memoryLimit) / (1024 * 1024 * 1024)
        
        print("""
        
        💾 ===== GPU 内存使用 =====
        🟢 活跃内存: \(String(format: "%.2f", activeGB)) GB
        🔵 缓存内存: \(String(format: "%.2f", cacheGB)) GB
        🔴 峰值内存: \(String(format: "%.2f", peakGB)) GB
        📊 内存限制: \(String(format: "%.2f", limitGB)) GB
        ===========================
        
        """)
    }
}
