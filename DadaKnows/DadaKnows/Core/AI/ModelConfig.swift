//
//  ModelConfig.swift
//  DadaKnows
//
//  本地大模型配置中心 - 模型文件元数据配置
//  模型文件直接从 R2 存储桶下载，无需解压
//
//  创建日期: 2025-10-04
//  更新日期: 2025-10-08
//  模型元数据获取日期: 2025-10-08
//

import Foundation

/// 模型文件信息
struct ModelFile {
    let name: String
    let size: Int64
    let sha256: String
    
    var url: URL {
        URL(string: "https://pub-07b3fe62045d44dc9e762f7d8e258566.r2.dev/Qwen3-4B-MLX-4bit/\(name)")!
    }
}

/// 本地大模型配置
/// 提供应用级别的静态配置，尤其是模型元数据
struct ModelConfig {
    // MARK: - 模型标识
    
    /// 模型名称
    static let modelName = "Qwen3-4B-MLX-4bit"
    
    /// R2 存储桶 URL 前缀
    static let baseURL = "https://pub-07b3fe62045d44dc9e762f7d8e258566.r2.dev/Qwen3-4B-MLX-4bit"
    
    // MARK: - 模型文件列表（已从实际文件获取）
    // 测量日期：2025-10-08
    // 测量命令：stat -f %z <file> && shasum -a 256 <file>
    
    /// 所有需要下载的模型文件
    static let modelFiles: [ModelFile] = [
        // 核心模型文件
        ModelFile(
            name: "model.safetensors",
            size: 2_137_326_367,  // 约 2.0 GB
            sha256: "e56a94b846a2dce7d1cc154ce58b9cfc4b8d99e8ffb74bfe256a265f4cbc7fb9"
        ),
        
        // Tokenizer 文件
        ModelFile(
            name: "tokenizer.json",
            size: 11_422_654,  // 约 11 MB
            sha256: "aeb13307a71acd8fe81861d94ad54ab689df773318809eed3cbe794b4492dae4"
        ),
        ModelFile(
            name: "tokenizer_config.json",
            size: 9_732,
            sha256: "d5d09f07b48c3086c508b30d1c9114bd1189145b74e982a265350c923acd8101"
        ),
        
        // 词汇表文件
        ModelFile(
            name: "vocab.json",
            size: 2_776_833,  // 约 2.6 MB
            sha256: "ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910"
        ),
        ModelFile(
            name: "merges.txt",
            size: 1_671_853,  // 约 1.6 MB
            sha256: "8831e4f1a044471340f7c0a83d7bd71306a5b867e95fd870f74d0c5308a904d5"
        ),
        
        // 配置文件
        ModelFile(
            name: "config.json",
            size: 988,
            sha256: "76eae114d67a444c7296be7a6bc0409ecc15c340e113f1bac7572cb7d0928b6f"
        ),
        ModelFile(
            name: "configuration.json",
            size: 48,
            sha256: "a78221ae93dd8977b26fcd1d106fa5ad7e7f1fd3a7d93bfd9d6fba5ed00ec4d2"
        ),
        ModelFile(
            name: "model.safetensors.index.json",
            size: 63_924,
            sha256: "278844a566da15beab6e9068c57f606c50a99c440d4515206b871a8b5282b3de"
        ),
        
        // 许可证和说明文件
        ModelFile(
            name: "LICENSE",
            size: 11_343,
            sha256: "832dd9e00a68dd83b3c3fb9f5588dad7dcf337a0db50f7d9483f310cd292e92e"
        ),
        ModelFile(
            name: "README.md",
            size: 14_708,
            sha256: "a3ac01d2a1fff2f02be25e1d2e9160f03db51dbee2cc17f13b774f646648adf9"
        ),
    ]
    
    // MARK: - 模型元数据
    
    /// 所有文件总大小（字节）
    /// 实际测量值：2,153,298,450 bytes (约 2.0 GB)
    /// 测量日期：2025-10-08
    static let totalSize: Int64 = 2_153_298_450
    
    /// 存储缓冲空间（字节）
    /// 200 MB 安全缓冲，用于下载过程中的临时文件
    static let storageBuffer: Int64 = 209_715_200  // 200 MB
    
    // MARK: - 计算属性
    
    /// 所需总存储空间（模型大小 + 缓冲）
    /// 约 2.2 GB
    static var requiredTotalSpace: Int64 {
        return totalSize + storageBuffer
    }
    
    /// 模型总大小（人类可读）
    static var totalSizeFormatted: String {
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    /// 所需总空间（人类可读）
    static var requiredTotalSpaceFormatted: String {
        return ByteCountFormatter.string(fromByteCount: requiredTotalSpace, countStyle: .file)
    }
    
    // MARK: - 模型关键文件
    
    /// 模型必须包含的关键文件列表
    /// 用于验证模型完整性
    static let requiredFiles = [
        "model.safetensors",      // 模型权重（2.0 GB）
        "tokenizer.json",         // 分词器配置（11 MB）
        "config.json",            // 模型配置
        "vocab.json",             // 词汇表（2.6 MB）
    ]
    
    // MARK: - 用户提示文案
    
    /// 首次下载提示文案
    static var downloadPromptTitle: String {
        NSLocalizedString("download_prompt_title", comment: "")
    }
    
    /// 首次下载提示详细说明
    static var downloadPromptMessage: String {
        String(format: NSLocalizedString("download_prompt_message", comment: ""), totalSizeFormatted)
    }
    
    /// 存储空间不足提示
    static func insufficientStorageMessage(available: Int64) -> String {
        let availableFormatted = ByteCountFormatter.string(fromByteCount: available, countStyle: .file)
        return String(format: NSLocalizedString("insufficient_storage_message", comment: ""), availableFormatted, requiredTotalSpaceFormatted)
    }
    
    /// 校验失败提示
    static var checksumFailureMessage: String {
        NSLocalizedString("checksum_failure_message", comment: "")
    }
    
    /// 下载进度提示
    static var downloadingMessage: String {
        NSLocalizedString("downloading_message", comment: "")
    }
    
    /// 加载模型提示
    static var loadingMessage: String {
        NSLocalizedString("loading_message", comment: "")
    }
    
    /// 模型准备就绪提示
    static var readyMessage: String {
        NSLocalizedString("ready_message", comment: "")
    }
}

// MARK: - 调试辅助

extension ModelConfig {
    /// 打印配置信息（仅在调试模式下）
    static func printConfiguration() {
        guard Config.isDebug else { return }
        
        print("""
        
        📋 ===== 模型配置信息 =====
        📦 模型名称: \(modelName)
        🔗 基础URL: \(baseURL)
        📊 模型总大小: \(totalSizeFormatted) (\(totalSize) bytes)
        💾 所需总空间: \(requiredTotalSpaceFormatted) (\(requiredTotalSpace) bytes)
        📄 文件数量: \(modelFiles.count)
        📄 关键文件: \(requiredFiles.joined(separator: ", "))
        ===========================
        
        """)
        
        print("📄 文件列表:")
        for file in modelFiles {
            let sizeFormatted = ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)
            print("  - \(file.name): \(sizeFormatted)")
        }
        print("")
    }
}
