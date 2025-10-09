//
//  MLXStorageManager.swift
//  DadaKnows
//
//  MLX模型存储管理器 - 管理模型存储
//  直接下载模型文件，无需解压
//
//  创建日期: 2025-10-04
//  更新日期: 2025-10-08
//

import Foundation

/// MLX模型存储管理器（单例）
/// 职责：
/// 1. 管理模型存储结构
/// 2. 检查可用空间
/// 3. 提供模型路径
/// 4. 验证模型完整性
class MLXStorageManager {
    static let shared = MLXStorageManager()
    
    private init() {
        if Config.isDebug {
            print("📁 MLXStorage: 存储管理器初始化")
        }
    }
    
    // MARK: - 存储路径配置（按照文档 4.2 要求）
    
    /// Documents目录
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// Models根目录: Documents/Models/
    var modelsDirectory: URL {
        documentsDirectory.appendingPathComponent("Models")
    }
    
    /// 最终模型目录: Documents/Models/Qwen3-4B-MLX-4bit/
    /// 这是模型文件的最终存储目录
    var modelDirectory: URL {
        modelsDirectory.appendingPathComponent(ModelConfig.modelName)
    }
    
    /// 临时目录: NSTemporaryDirectory()/ModelDownload/
    /// 用于下载过程中的临时文件
    var tempDirectory: URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ModelDownload")
    }
    
    // MARK: - 存储空间管理
    
    /// 检查可用存储空间是否足够
    /// - Parameter requiredSize: 需要的存储空间（字节），默认使用 ModelConfig 中配置的大小
    /// - Returns: 是否有足够空间
    func checkAvailableStorage(requiredSize: Int64? = nil) -> Bool {
        let required = requiredSize ?? ModelConfig.requiredTotalSpace
        let available = getAvailableStorage()
        
        let hasEnoughSpace = available >= required
        
        if Config.isDebug {
            let availableGB = Double(available) / (1024 * 1024 * 1024)
            let requiredGB = Double(required) / (1024 * 1024 * 1024)
            print("""
                📊 MLXStorage: 存储空间检查
                   需要: \(String(format: "%.2f", requiredGB)) GB
                   可用: \(String(format: "%.2f", availableGB)) GB
                   结果: \(hasEnoughSpace ? "✅ 充足" : "❌ 不足")
                """)
        }
        
        return hasEnoughSpace
    }
    
    /// 获取可用存储空间（字节）
    func getAvailableStorage() -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(
                forPath: documentsDirectory.path
            )
            return attributes[.systemFreeSize] as? Int64 ?? 0
        } catch {
            if Config.isDebug {
                print("❌ MLXStorage: 获取存储空间失败 - \(error)")
            }
            return 0
        }
    }
    
    /// 获取模型占用的存储空间（字节）
    func getModelStorageSize() -> Int64 {
        guard FileManager.default.fileExists(atPath: modelDirectory.path) else {
            return 0
        }
        
        do {
            let resourceValues = try modelDirectory.resourceValues(
                forKeys: [.totalFileAllocatedSizeKey]
            )
            let size = Int64(resourceValues.totalFileAllocatedSize ?? 0)
            
            if Config.isDebug && size > 0 {
                let sizeGB = Double(size) / (1024 * 1024 * 1024)
                print("📊 MLXStorage: 模型占用空间 \(String(format: "%.2f", sizeGB)) GB")
            }
            
            return size
        } catch {
            if Config.isDebug {
                print("❌ MLXStorage: 计算模型存储大小失败 - \(error)")
            }
            return 0
        }
    }
    
    // MARK: - 模型状态检查
    
    /// 检查模型是否已准备就绪
    /// 通过检查模型目录及目录下的关键文件是否存在来判断
    /// - Returns: 模型是否准备就绪
    func isModelReady() -> Bool {
        // 1. 检查模型目录是否存在
        guard FileManager.default.fileExists(atPath: modelDirectory.path) else {
            if Config.isDebug {
                print("📁 MLXStorage: 模型目录不存在")
            }
            return false
        }
        
        // 2. 检查关键文件是否都存在
        for fileName in ModelConfig.requiredFiles {
            let filePath = modelDirectory.appendingPathComponent(fileName)
            if !FileManager.default.fileExists(atPath: filePath.path) {
                if Config.isDebug {
                    print("❌ MLXStorage: 缺少关键文件 - \(fileName)")
                }
                return false
            }
        }
        
        if Config.isDebug {
            print("✅ MLXStorage: 模型已就绪，所有关键文件存在")
        }
        
        return true
    }
    
    /// 检查模型目录是否存在且不为空
    func isModelDirectoryValid() -> Bool {
        guard FileManager.default.fileExists(atPath: modelDirectory.path) else {
            return false
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: modelDirectory.path)
            return !contents.isEmpty
        } catch {
            if Config.isDebug {
                print("❌ MLXStorage: 检查模型目录失败 - \(error)")
            }
            return false
        }
    }
    
    // MARK: - 目录管理
    
    /// 确保必要的目录存在
    /// 创建 Documents/Models/ 和临时目录
    func ensureDirectoriesExist() throws {
        let fileManager = FileManager.default
        
        // 创建 Models 目录
        if !fileManager.fileExists(atPath: modelsDirectory.path) {
            try fileManager.createDirectory(
                at: modelsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            if Config.isDebug {
                print("📁 MLXStorage: 创建目录 - \(modelsDirectory.path)")
            }
        }
        
        // 创建临时下载目录
        if !fileManager.fileExists(atPath: tempDirectory.path) {
            try fileManager.createDirectory(
                at: tempDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            if Config.isDebug {
                print("📁 MLXStorage: 创建临时目录 - \(tempDirectory.path)")
            }
        }
    }
    
    /// 删除模型目录和所有内容（同步版本）
    func deleteModelDirectory() throws {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: modelDirectory.path) else {
            if Config.isDebug {
                print("📁 MLXStorage: 模型目录不存在，无需删除")
            }
            return
        }
        
        try fileManager.removeItem(at: modelDirectory)
        
        if Config.isDebug {
            print("🗑️ MLXStorage: 已删除模型目录 - \(modelDirectory.path)")
        }
    }
    
    /// 删除模型目录和所有内容（异步版本，不阻塞主线程）
    func deleteModelDirectoryAsync() async throws {
        let fileManager = FileManager.default
        let modelDir = modelDirectory
        
        guard fileManager.fileExists(atPath: modelDir.path) else {
            if Config.isDebug {
                print("📁 MLXStorage: 模型目录不存在，无需删除")
            }
            return
        }
        
        if Config.isDebug {
            print("🗑️ MLXStorage: 开始删除模型目录 - \(modelDir.path)")
        }
        
        // 在后台线程执行删除操作，避免阻塞主线程
        try await Task.detached(priority: .userInitiated) {
            try fileManager.removeItem(at: modelDir)
            
            if Config.isDebug {
                await MainActor.run {
                    print("✅ MLXStorage: 模型目录删除完成")
                }
            }
        }.value
    }
    
    /// 清理所有临时文件和目录
    func cleanupTempFiles() {
        let fileManager = FileManager.default
        
        // 清理整个临时目录
        if fileManager.fileExists(atPath: tempDirectory.path) {
            do {
                try fileManager.removeItem(at: tempDirectory)
                if Config.isDebug {
                    print("🧹 MLXStorage: 清理临时目录")
                }
            } catch {
                if Config.isDebug {
                    print("⚠️ MLXStorage: 清理临时目录失败 - \(error)")
                }
            }
        }
    }
    
    /// 获取模型文件列表（用于调试）
    func getModelFileList() -> [String] {
        guard FileManager.default.fileExists(atPath: modelDirectory.path) else {
            return []
        }
        
        do {
            return try FileManager.default.contentsOfDirectory(atPath: modelDirectory.path)
        } catch {
            if Config.isDebug {
                print("❌ MLXStorage: 获取文件列表失败 - \(error)")
            }
            return []
        }
    }
    
    // MARK: - 调试辅助
    
    /// 打印存储状态（仅在调试模式下）
    func printStorageStatus() {
        guard Config.isDebug else { return }
        
        let modelExists = isModelReady()
        let modelSize = getModelStorageSize()
        let availableSpace = getAvailableStorage()
        
        let modelSizeGB = Double(modelSize) / (1024 * 1024 * 1024)
        let availableGB = Double(availableSpace) / (1024 * 1024 * 1024)
        
        print("""
        
        📂 ===== 存储状态 =====
        📁 模型目录: \(modelDirectory.path)
        ✅ 模型就绪: \(modelExists ? "是" : "否")
        📊 模型大小: \(String(format: "%.2f", modelSizeGB)) GB
        💾 可用空间: \(String(format: "%.2f", availableGB)) GB
        📄 文件列表: \(getModelFileList().joined(separator: ", "))
        ======================
        
        """)
    }
}

// MARK: - 存储错误类型

extension MLXStorageManager {
    /// 存储错误类型
    enum StorageError: LocalizedError {
        case insufficientSpace(required: Int64, available: Int64)
        case directoryCreationFailed(Error)
        case modelDirectoryNotFound
        case cleanupFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .insufficientSpace(let required, let available):
                return ModelConfig.insufficientStorageMessage(available: available)
                
            case .directoryCreationFailed(let error):
                return "创建目录失败: \(error.localizedDescription)"
                
            case .modelDirectoryNotFound:
                return "模型目录不存在"
                
            case .cleanupFailed(let error):
                return "清理临时文件失败: \(error.localizedDescription)"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .insufficientSpace:
                return "请清理设备存储空间后重试。可以删除不需要的照片、视频或应用。"
                
            case .directoryCreationFailed:
                return "请检查应用权限设置，或尝试重启应用。"
                
            case .modelDirectoryNotFound:
                return "请重新下载模型。"
                
            case .cleanupFailed:
                return "临时文件清理失败不影响使用，系统会在适当时候自动清理。"
            }
        }
    }
}

// MARK: - 存储状态枚举

/// 模型存储状态
enum ModelStorageStatus: Equatable {
    case notDownloaded      // 未下载
    case downloading        // 下载中
    case paused             // 已暂停
    case extracting         // 解压中
    case ready              // 已就绪
    case error(String)      // 错误状态
    
    var isReady: Bool {
        if case .ready = self {
            return true
        }
        return false
    }
    
    var isProcessing: Bool {
        switch self {
        case .downloading, .extracting, .paused:
            return true
        default:
            return false
        }
    }
    
    var localizedDescription: String {
        switch self {
        case .notDownloaded:
            return NSLocalizedString("未下载", comment: "")
        case .downloading:
            return NSLocalizedString("下载中", comment: "")
        case .paused:
            return NSLocalizedString("已暂停", comment: "")
        case .extracting:
            return NSLocalizedString("解压中", comment: "")
        case .ready:
            return NSLocalizedString("已就绪", comment: "")
        case .error(let message):
            return NSLocalizedString("错误: \(message)", comment: "")
        }
    }
    
    var icon: String {
        switch self {
        case .notDownloaded:
            return "arrow.down.circle"
        case .downloading:
            return "arrow.down.circle.fill"
        case .paused:
            return "pause.circle.fill"
        case .extracting:
            return "archivebox"
        case .ready:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}
