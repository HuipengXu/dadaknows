//
//  LlamaCppManager.swift
//  DadaKnows
//
//  llama.cpp核心管理器 - 直接封装llama.cpp C API
//

import Foundation
import SwiftUI

// 暂时注释掉直接的llama.cpp调用，使用模拟实现
// 待LlamaFramework正确集成后启用
// #if canImport(LlamaFramework)
// import LlamaFramework
// #endif

@MainActor
class LlamaCppManager: ObservableObject {
    static let shared = LlamaCppManager()
    
    @Published var isModelLoaded = false
    @Published var isLoading = false
    @Published var error: Error?
    
    // 暂时使用模拟实现，待LlamaFramework集成后恢复
    private var isModelLoadedInternal = false
    private var modelPath: URL?
    
    private init() {
        if Config.isDebug {
            print("🦙 LlamaCppManager: 初始化")
        }
    }
    
    deinit {
        // 清理资源
        // 注意: deinit中不能调用async方法，所以同步清理
        modelPath = nil
        isModelLoadedInternal = false
        // 在deinit中，我们只能同步清理，isModelLoaded会在下次访问时更新
    }
    
    // MARK: - Model Loading
    
    /// 加载模型到内存
    /// - Parameter modelPath: .gguf文件的本地路径
    func loadModel(at modelPath: URL) async throws {
        if Config.isDebug {
            print("🦙 LlamaCppManager: 开始加载模型 - \(modelPath.lastPathComponent)")
        }
        
        await MainActor.run {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            // 模拟模型加载过程
            try await Task.detached { [weak self] in
                guard let self = self else { return }
                
                // 检查模型文件是否存在
                guard FileManager.default.fileExists(atPath: modelPath.path) else {
                    throw LlamaCppError.modelLoadFailed("Model file not found at \(modelPath.path)")
                }
                
                // 模拟加载延迟
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                
                // 保存模型路径
                await MainActor.run {
                    self.modelPath = modelPath
                    self.isModelLoadedInternal = true
                    self.isModelLoaded = true
                    self.isLoading = false
                }
                
                if Config.isDebug {
                    print("✅ LlamaCppManager: 模型加载成功 (模拟)")
                }
            }.value
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
                self.isModelLoaded = false
            }
            throw error
        }
    }
    
    /// 卸载模型释放内存
    func unloadModel() {
        // 清理模拟状态
        modelPath = nil
        isModelLoadedInternal = false
        isModelLoaded = false
        
        if Config.isDebug {
            print("🦙 LlamaCppManager: 模型已卸载 (模拟)")
        }
    }
    
    // MARK: - Text Generation
    
    /// 生成回答（流式输出）
    /// - Parameter prompt: 输入提示词
    /// - Returns: 异步文本流
    func generateResponse(prompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                guard isModelLoaded else {
                    continuation.finish(throwing: LlamaCppError.modelNotLoaded)
                    return
                }
                
                do {
                    // 模拟生成回答
                    let mockResponse = "这是一个模拟的本地AI回答。提问：\(prompt)"
                    let words = mockResponse.components(separatedBy: " ")
                    
                    for (index, word) in words.enumerated() {
                        // 检查是否需要停止
                        if Task.isCancelled {
                            break
                        }
                        
                        // 逐词输出，模拟流式生成
                        let output = index == 0 ? word : " \(word)"
                        continuation.yield(output)
                        
                        // 短暂延迟以模拟真实的生成速度
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// 从params文件加载模型参数
    private func loadModelParams(from paramsPath: URL) throws -> ModelParams {
        guard FileManager.default.fileExists(atPath: paramsPath.path) else {
            if Config.isDebug {
                print("⚠️ LlamaCppManager: params文件不存在，使用默认参数")
            }
            return ModelParams.default
        }
        
        let paramsData = try Data(contentsOf: paramsPath)
        let paramsString = String(data: paramsData, encoding: .utf8) ?? ""
        
        return parseModelParams(from: paramsString)
    }
    
    /// 解析模型参数
    private func parseModelParams(from content: String) -> ModelParams {
        var params = ModelParams.default
        
        content.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { return }
            
            let components = trimmed.components(separatedBy: "=")
            guard components.count == 2 else { return }
            
            let key = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            switch key {
            case "temperature":
                params.temperature = Float(value) ?? params.temperature
            case "top_p":
                params.topP = Float(value) ?? params.topP
            case "top_k":
                params.topK = Int(value) ?? params.topK
            case "context_size":
                params.contextSize = Int(value) ?? params.contextSize
            default:
                break
            }
        }
        
        return params
    }
}

// MARK: - Supporting Types

struct ModelParams {
    var temperature: Float
    var topP: Float
    var topK: Int
    var contextSize: Int
    
    static let `default` = ModelParams(
        temperature: 0.7,
        topP: 0.9,
        topK: 40,
        contextSize: 2048
    )
}

enum LlamaCppError: LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(String)
    case generationFailed(String)
    case invalidParams
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return NSLocalizedString("模型未加载", comment: "")
        case .modelLoadFailed(let message):
            return String(format: NSLocalizedString("模型加载失败：%@", comment: ""), message)
        case .generationFailed(let message):
            return String(format: NSLocalizedString("文本生成失败：%@", comment: ""), message)
        case .invalidParams:
            return NSLocalizedString("无效的模型参数", comment: "")
        }
    }
}
