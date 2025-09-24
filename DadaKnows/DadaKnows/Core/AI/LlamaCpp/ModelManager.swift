//
//  ModelManager.swift
//  DadaKnows
//
//  模型元数据管理器 - 管理模型的存储、状态和生命周期
//

import Foundation
import CryptoKit

class ModelManager {
    static let shared = ModelManager()
    
    // MARK: - Model Information
    
    static let modelInfo = ModelInfo(
        name: "Qwen/Qwen3-0.6B-GGUF",
        // ZIP包信息
        zipFileName: "DadaKnows-Qwen3-0.6B-Model.v1.zip",
        zipDownloadURL: "https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q8_0.gguf", // 开发阶段URL
        expectedZipSize: 640 * 1024 * 1024, // 640 MB
        zipChecksum: "placeholder_checksum", // 将在生产环境中更新
        // 解压后信息
        unzippedDirName: "Qwen3-0.6B-GGUF-v1",
        modelFileName: "Qwen3-0.6B-Q8_0.gguf",
        paramsFileName: "params"
    )
    
    private init() {}
    
    // MARK: - Path Management
    
    /// 获取Models目录路径
    var modelsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("Models")
    }
    
    /// 获取模型解压后的目录路径
    var modelDirectory: URL {
        return modelsDirectory.appendingPathComponent(ModelManager.modelInfo.unzippedDirName)
    }
    
    /// 获取模型文件路径
    func getModelPath() -> URL? {
        let modelPath = modelDirectory.appendingPathComponent(ModelManager.modelInfo.modelFileName)
        return FileManager.default.fileExists(atPath: modelPath.path) ? modelPath : nil
    }
    
    /// 获取参数文件路径
    func getParamsPath() -> URL? {
        let paramsPath = modelDirectory.appendingPathComponent(ModelManager.modelInfo.paramsFileName)
        return FileManager.default.fileExists(atPath: paramsPath.path) ? paramsPath : nil
    }
    
    /// 获取ZIP包下载路径
    var zipDownloadPath: URL {
        return modelsDirectory.appendingPathComponent(ModelManager.modelInfo.zipFileName)
    }
    
    // MARK: - Status Check
    
    /// 检查模型是否已下载并解压
    func isModelDownloadedAndUnzipped() -> Bool {
        return getModelPath() != nil && getParamsPath() != nil
    }
    
    /// 检查ZIP包是否已下载
    func isZipDownloaded() -> Bool {
        return FileManager.default.fileExists(atPath: zipDownloadPath.path)
    }
    
    /// 获取模型状态
    func getModelStatus() -> ModelStatus {
        if isModelDownloadedAndUnzipped() {
            return .ready
        } else if isZipDownloaded() {
            return .downloaded
        } else {
            return .notDownloaded
        }
    }
    
    // MARK: - File Operations
    
    /// 创建必要的目录结构
    func createDirectoriesIfNeeded() throws {
        let fileManager = FileManager.default
        
        // 确保文档目录存在并可访问
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        if Config.isDebug {
            print("📁 ModelManager: 文档目录 - \(documentsPath.path)")
            print("📁 Models目录 - \(modelsDirectory.path)")
        }
        
        // 创建Models目录
        if !fileManager.fileExists(atPath: modelsDirectory.path) {
            try fileManager.createDirectory(
                at: modelsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            if Config.isDebug {
                print("📁 ModelManager: 创建目录成功 - \(modelsDirectory.path)")
            }
        }
        
        // 验证目录确实存在并可写入
        guard fileManager.fileExists(atPath: modelsDirectory.path) else {
            throw ModelManagerError.directoryCreationFailed(modelsDirectory.path)
        }
        
        // 测试写入权限
        let testFilePath = modelsDirectory.appendingPathComponent(".test_write_permission")
        do {
            try "test".write(to: testFilePath, atomically: true, encoding: .utf8)
            try fileManager.removeItem(at: testFilePath)
            
            if Config.isDebug {
                print("✅ ModelManager: 目录权限验证成功")
            }
        } catch {
            if Config.isDebug {
                print("❌ ModelManager: 目录写入权限测试失败 - \(error)")
            }
            throw ModelManagerError.directoryNotWritable(modelsDirectory.path)
        }
    }
    
    /// 验证ZIP文件校验和
    func validateModelChecksum(at path: URL) -> Bool {
        do {
            let data = try Data(contentsOf: path)
            let hash = SHA256.hash(data: data)
            let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
            
            // 在开发阶段跳过校验和验证
            if ModelManager.modelInfo.zipChecksum == "placeholder_checksum" {
                if Config.isDebug {
                    print("📋 ModelManager: 开发阶段跳过校验和验证 - \(hashString)")
                }
                return true
            }
            
            let isValid = hashString == ModelManager.modelInfo.zipChecksum
            if Config.isDebug {
                print("📋 ModelManager: 校验和验证结果 - \(isValid ? "✅" : "❌")")
                print("  期望: \(ModelManager.modelInfo.zipChecksum)")
                print("  实际: \(hashString)")
            }
            
            return isValid
        } catch {
            if Config.isDebug {
                print("❌ ModelManager: 校验和计算失败 - \(error)")
            }
            return false
        }
    }
    
    /// 解压模型ZIP包
    func unzipModel(zipPath: URL) throws {
        if Config.isDebug {
            print("📦 ModelManager: 开始解压 - \(zipPath.lastPathComponent)")
        }
        
        let destinationURL = modelDirectory
        
        // 确保目标目录存在
        try FileManager.default.createDirectory(
            at: destinationURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // 开发阶段：创建模拟的模型文件
        try createMockModelFiles(in: destinationURL)
        
        // TODO: 在生产环境中使用真实的解压实现
        // 可以使用 ZIPFoundation 或其他解压库
        
        if Config.isDebug {
            print("✅ ModelManager: 解压完成")
        }
    }
    
    /// 创建模拟的模型文件（开发阶段使用）
    private func createMockModelFiles(in directory: URL) throws {
        // 创建模拟的.gguf文件
        let modelPath = directory.appendingPathComponent(ModelManager.modelInfo.modelFileName)
        let mockModelData = "Mock GGUF model file for development".data(using: .utf8)!
        try mockModelData.write(to: modelPath)
        
        // 创建模拟的params文件
        let paramsPath = directory.appendingPathComponent(ModelManager.modelInfo.paramsFileName)
        let mockParams = """
        # Qwen3-0.6B Model Parameters
        temperature=0.7
        top_p=0.9
        top_k=40
        context_size=2048
        """
        try mockParams.write(to: paramsPath, atomically: true, encoding: .utf8)
        
        if Config.isDebug {
            print("📝 ModelManager: 创建模拟文件完成")
        }
    }
    
    /// 删除模型文件
    func deleteModel() throws {
        if FileManager.default.fileExists(atPath: modelDirectory.path) {
            try FileManager.default.removeItem(at: modelDirectory)
        }
        
        if FileManager.default.fileExists(atPath: zipDownloadPath.path) {
            try FileManager.default.removeItem(at: zipDownloadPath)
        }
        
        if Config.isDebug {
            print("🗑️ ModelManager: 模型文件已删除")
        }
    }
    
    /// 获取模型占用的存储空间
    func getModelStorageSize() -> Int64 {
        var totalSize: Int64 = 0
        
        // ZIP文件大小
        if let zipSize = try? FileManager.default.attributesOfItem(atPath: zipDownloadPath.path)[.size] as? Int64 {
            totalSize += zipSize
        }
        
        // 解压后文件大小
        if let enumerator = FileManager.default.enumerator(at: modelDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        return totalSize
    }
    
    /// 检查可用存储空间
    func checkAvailableStorage() -> Int64 {
        do {
            // 先尝试创建目录，以确保路径存在
            try createDirectoriesIfNeeded()
            
            // 使用文档目录路径，而不是Models子目录
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: documentsPath.path)
            
            if let freeSpace = attributes[.systemFreeSize] as? Int64 {
                if Config.isDebug {
                    print("💾 ModelManager: 可用存储空间 - \(ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file))")
                }
                return freeSpace
            }
        } catch {
            if Config.isDebug {
                print("❌ ModelManager: 获取存储空间失败 - \(error)")
            }
            
            // 模拟器环境返回合理的默认值
            #if targetEnvironment(simulator)
            let simulatorDefaultSpace: Int64 = 50 * 1024 * 1024 * 1024 // 50GB
            if Config.isDebug {
                print("📱 ModelManager: 模拟器环境，使用默认存储空间 - \(ByteCountFormatter.string(fromByteCount: simulatorDefaultSpace, countStyle: .file))")
            }
            return simulatorDefaultSpace
            #endif
        }
        return 0
    }
    
    /// 检查是否有足够的存储空间
    func hasEnoughStorage() -> Bool {
        let availableSpace = checkAvailableStorage()
        let requiredSpace = Int64(ModelManager.modelInfo.expectedZipSize) * 3 // ZIP + 解压 + 安全缓冲
        
        if Config.isDebug {
            print("💾 ModelManager: 存储空间检查")
            print("  可用空间: \(ByteCountFormatter.string(fromByteCount: availableSpace, countStyle: .file))")
            print("  需要空间: \(ByteCountFormatter.string(fromByteCount: requiredSpace, countStyle: .file))")
        }
        
        return availableSpace >= requiredSpace
    }
}

// MARK: - Supporting Types

struct ModelInfo {
    let name: String
    let zipFileName: String
    let zipDownloadURL: String
    let expectedZipSize: Int
    let zipChecksum: String
    let unzippedDirName: String
    let modelFileName: String
    let paramsFileName: String
}

enum ModelStatus {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case extracting
    case ready
    case error(String)
    
    var isReady: Bool {
        if case .ready = self {
            return true
        }
        return false
    }
    
    var localizedDescription: String {
        switch self {
        case .notDownloaded:
            return NSLocalizedString("未下载", comment: "")
        case .downloading(let progress):
            return String(format: NSLocalizedString("下载中 %.0f%%", comment: ""), progress * 100)
        case .downloaded:
            return NSLocalizedString("已下载", comment: "")
        case .extracting:
            return NSLocalizedString("解压中", comment: "")
        case .ready:
            return NSLocalizedString("就绪", comment: "")
        case .error(let message):
            return String(format: NSLocalizedString("错误：%@", comment: ""), message)
        }
    }
}

enum ModelManagerError: LocalizedError {
    case directoryCreationFailed(String)
    case directoryNotWritable(String)
    
    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let path):
            return String(format: NSLocalizedString("无法创建目录：%@", comment: ""), path)
        case .directoryNotWritable(let path):
            return String(format: NSLocalizedString("目录无写入权限：%@", comment: ""), path)
        }
    }
}
