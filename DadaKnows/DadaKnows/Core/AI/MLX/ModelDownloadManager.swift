//
//  ModelDownloadManager.swift
//  DadaKnows
//
//  模型下载管理器 - 核心组件，负责模型文件的下载和校验
//  直接下载模型文件，无需解压
//
//  功能：
//  1. 后台下载模型文件列表
//  2. 断点续传支持
//  3. SHA256 完整性校验
//  4. 原子化文件操作
//  5. 自动清理临时文件
//
//  创建日期: 2025-10-04
//  更新日期: 2025-10-08
//

import Foundation
import CryptoKit

/// 模型下载管理器（单例）
@MainActor
class ModelDownloadManager: NSObject, ObservableObject {
    static let shared = ModelDownloadManager()
    
    // MARK: - Published Properties
    
    /// 下载进度（0.0 - 1.0）
    @Published var downloadProgress: Double = 0.0
    
    /// 是否正在下载
    @Published var isDownloading = false
    
    /// 下载错误
    @Published var error: ModelError?
    
    /// 当前状态描述
    @Published var statusMessage: String = ""
    
    /// 是否暂停状态
    @Published var isPaused = false
    
    // MARK: - Private Properties
    
    private var urlSession: URLSession!
    private let storageManager = MLXStorageManager.shared
    
    /// 当前下载任务映射 (文件名 -> 下载任务)
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    
    /// 已下载的文件列表
    private var downloadedFiles: Set<String> = []
    
    /// 文件下载进度 (文件名 -> 进度)
    private var fileProgress: [String: Double] = [:]
    
    /// 恢复数据持久化键前缀
    private let resumeDataKeyPrefix = "com.dadaknows.model.resumeData."
    
    /// 已下载文件列表持久化键
    private let downloadedFilesKey = "com.dadaknows.model.downloadedFiles"
    
    /// 上次记录的进度百分比（用于避免重复日志）
    private var lastLoggedPercent = -1
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        
        // 配置后台 URLSession
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.dadaknows.modeldownload"
        )
        config.allowsConstrainedNetworkAccess = true   // 允许受限网络
        config.allowsExpensiveNetworkAccess = true     // 允许昂贵网络
        config.sessionSendsLaunchEvents = true         // 下载完成时启动应用
        config.isDiscretionary = false                 // 不由系统决定下载时机
        config.timeoutIntervalForRequest = 60          // 请求超时 60秒
        config.timeoutIntervalForResource = 86400      // 资源下载超时 24小时
        
        urlSession = URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: nil
        )
        
        // 加载已下载文件列表
        loadDownloadedFiles()
        
        if Config.isDebug {
            print("📥 ModelDownload: 下载管理器初始化")
            if !downloadedFiles.isEmpty {
                print("   已下载文件: \(downloadedFiles.joined(separator: ", "))")
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// 开始下载模型
    /// - Throws: 下载启动失败时抛出错误
    func startDownload() async throws {
        // 检查是否已在下载
        guard !isDownloading else {
            if Config.isDebug {
                print("⚠️ ModelDownload: 已在下载中")
            }
            return
        }
        
        // 重置错误状态
        error = nil
        
        // 检查存储空间
        guard storageManager.checkAvailableStorage() else {
            let error = ModelError.insufficientStorage(
                required: ModelConfig.requiredTotalSpace,
                available: storageManager.getAvailableStorage()
            )
            await setError(error)
            throw error
        }
        
        // 确保目录存在
        try storageManager.ensureDirectoriesExist()
        
        if Config.isDebug {
            print("""
                📥 ModelDownload: 准备开始下载
                   基础URL: \(ModelConfig.baseURL)
                   文件数量: \(ModelConfig.modelFiles.count)
                   总大小: \(ModelConfig.totalSizeFormatted)
                """)
        }
        
        isDownloading = true
        downloadProgress = 0.0
        statusMessage = ModelConfig.downloadingMessage
        
        // 开始下载所有文件
        await startDownloadingFiles()
    }
    
    /// 暂停下载
    func pauseDownload() async {
        guard isDownloading && !isPaused else {
            return
        }
        
        isPaused = true
        
        // 暂停所有下载任务
        for (fileName, task) in downloadTasks {
            task.cancel(byProducingResumeData: { [weak self] resumeData in
                Task { @MainActor in
                    if let resumeData = resumeData {
                        self?.saveResumeData(resumeData, for: fileName)
                        if Config.isDebug {
                            print("⏸️ ModelDownload: \(fileName) 已暂停")
                        }
                    }
                }
            })
        }
        
        downloadTasks.removeAll()
        statusMessage = "下载已暂停"
        
        if Config.isDebug {
            print("⏸️ ModelDownload: 下载已暂停")
        }
    }
    
    /// 恢复下载
    func resumeDownload() async throws {
        guard isPaused else {
            if Config.isDebug {
                print("⚠️ ModelDownload: 当前不是暂停状态，无法恢复")
            }
            return
        }
        
        if Config.isDebug {
            print("▶️ ModelDownload: 准备恢复下载")
        }
        
        // 重置状态
        isPaused = false
        isDownloading = false
        
        // 开始下载（会自动检测并使用恢复数据）
        try await startDownload()
    }
    
    /// 取消下载
    func cancelDownload() async {
        // 取消所有下载任务
        for (_, task) in downloadTasks {
            task.cancel()
        }
        downloadTasks.removeAll()
        
        // 清理恢复数据和已下载文件记录
        clearAllResumeData()
        clearDownloadedFiles()
        
        // 清理临时文件
        storageManager.cleanupTempFiles()
        
        isDownloading = false
        isPaused = false
        downloadProgress = 0.0
        fileProgress.removeAll()
        statusMessage = "下载已取消"
        
        if Config.isDebug {
            print("❌ ModelDownload: 下载已取消")
        }
    }
    
    /// 检查是否有未完成的下载
    func hasPendingDownload() -> Bool {
        return !downloadedFiles.isEmpty && downloadedFiles.count < ModelConfig.modelFiles.count
    }
    
    // MARK: - Private Methods - Download
    
    private func startDownloadingFiles() async {
        // 获取需要下载的文件列表（排除已下载的）
        let filesToDownload = ModelConfig.modelFiles.filter { !downloadedFiles.contains($0.name) }
        
        if filesToDownload.isEmpty {
            if Config.isDebug {
                print("✅ ModelDownload: 所有文件已下载")
            }
            await downloadCompleted()
            return
        }
        
        if Config.isDebug {
            print("📥 ModelDownload: 需要下载 \(filesToDownload.count) 个文件")
        }
        
        // 初始化文件进度
        for file in filesToDownload {
            fileProgress[file.name] = 0.0
        }
        
        // 开始下载每个文件
        for file in filesToDownload {
            await startDownloadingFile(file)
        }
    }
    
    private func startDownloadingFile(_ file: ModelFile) async {
        // 检查是否有恢复数据
        if let resumeData = loadResumeData(for: file.name) {
            if Config.isDebug {
                print("🔄 ModelDownload: 从断点恢复 \(file.name)")
            }
            let task = urlSession.downloadTask(withResumeData: resumeData)
            downloadTasks[file.name] = task
            task.resume()
        } else {
            if Config.isDebug {
                print("📥 ModelDownload: 开始下载 \(file.name)")
            }
            let task = urlSession.downloadTask(with: file.url)
            downloadTasks[file.name] = task
            task.resume()
        }
    }
    
    /// 单个文件下载完成
    private func fileDownloadCompleted(fileName: String, tempLocation: URL) async {
        do {
            // 找到对应的文件配置
            guard let fileConfig = ModelConfig.modelFiles.first(where: { $0.name == fileName }) else {
                throw ModelError.modelNotFound
            }
            
            if Config.isDebug {
                print("📥 ModelDownload: \(fileName) 下载完成，开始校验")
            }
            
            // 校验文件
            try verifyChecksum(fileURL: tempLocation, expectedChecksum: fileConfig.sha256)
            
            if Config.isDebug {
                print("✅ ModelDownload: \(fileName) 校验通过")
            }
            
            // 移动到最终位置
            let finalURL = storageManager.modelDirectory.appendingPathComponent(fileName)
            let fileManager = FileManager.default
            
            // 确保父目录存在
            let parentDir = finalURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDir.path) {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }
            
            // 删除旧文件（如果存在）
            if fileManager.fileExists(atPath: finalURL.path) {
                try fileManager.removeItem(at: finalURL)
            }
            
            // 移动文件
            try fileManager.moveItem(at: tempLocation, to: finalURL)
            
            if Config.isDebug {
                print("✅ ModelDownload: \(fileName) 已保存到最终位置")
            }
            
            // 记录已下载
            downloadedFiles.insert(fileName)
            saveDownloadedFiles()
            
            // 清理该文件的恢复数据
            clearResumeData(for: fileName)
            
            // 移除任务和进度记录
            downloadTasks.removeValue(forKey: fileName)
            fileProgress.removeValue(forKey: fileName)
            
            // 检查是否所有文件都已下载
            if downloadedFiles.count == ModelConfig.modelFiles.count {
                await downloadCompleted()
            }
            
        } catch {
            if Config.isDebug {
                print("❌ ModelDownload: \(fileName) 处理失败 - \(error)")
            }
            await setError(ModelError.downloadFailed(error))
        }
    }
    
    /// 所有文件下载完成
    private func downloadCompleted() async {
        isDownloading = false
        isPaused = false
        downloadProgress = 1.0
        statusMessage = ModelConfig.readyMessage
        
        // 清理所有恢复数据
        clearAllResumeData()
        clearDownloadedFiles()
        
        if Config.isDebug {
            print("🎉 ModelDownload: 所有文件下载完成！")
            storageManager.printStorageStatus()
        }
    }
    
    // MARK: - Private Methods - Resume Data
    
    private func saveResumeData(_ data: Data, for fileName: String) {
        UserDefaults.standard.set(data, forKey: resumeDataKeyPrefix + fileName)
        UserDefaults.standard.synchronize()
    }
    
    private func loadResumeData(for fileName: String) -> Data? {
        return UserDefaults.standard.data(forKey: resumeDataKeyPrefix + fileName)
    }
    
    private func clearResumeData(for fileName: String) {
        UserDefaults.standard.removeObject(forKey: resumeDataKeyPrefix + fileName)
        UserDefaults.standard.synchronize()
    }
    
    private func clearAllResumeData() {
        for file in ModelConfig.modelFiles {
            clearResumeData(for: file.name)
        }
    }
    
    // MARK: - Private Methods - Downloaded Files Tracking
    
    private func saveDownloadedFiles() {
        let array = Array(downloadedFiles)
        UserDefaults.standard.set(array, forKey: downloadedFilesKey)
        UserDefaults.standard.synchronize()
    }
    
    private func loadDownloadedFiles() {
        if let array = UserDefaults.standard.array(forKey: downloadedFilesKey) as? [String] {
            downloadedFiles = Set(array)
        }
    }
    
    private func clearDownloadedFiles() {
        downloadedFiles.removeAll()
        UserDefaults.standard.removeObject(forKey: downloadedFilesKey)
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Private Methods - SHA256 Verification
    
    /// 计算文件的 SHA256 校验和
    /// - Parameter fileURL: 文件URL
    /// - Returns: SHA256 十六进制字符串
    nonisolated private func calculateSHA256(fileURL: URL) throws -> String {
        let bufferSize = 1024 * 1024 // 1MB buffer
        
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            throw ModelError.verificationFailed("无法打开文件进行校验")
        }
        
        defer {
            try? fileHandle.close()
        }
        
        var hasher = SHA256()
        
        // 分块读取文件计算哈希（避免大文件占用过多内存）
        while autoreleasepool(invoking: {
            let data = fileHandle.readData(ofLength: bufferSize)
            if data.isEmpty {
                return false
            }
            hasher.update(data: data)
            return true
        }) {}
        
        let hash = hasher.finalize()
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        return hashString
    }
    
    /// 验证文件的 SHA256 校验和
    /// - Parameters:
    ///   - fileURL: 文件URL
    ///   - expectedChecksum: 期望的校验和
    /// - Throws: 校验失败时抛出错误
    nonisolated private func verifyChecksum(fileURL: URL, expectedChecksum: String) throws {
        let actualChecksum = try calculateSHA256(fileURL: fileURL)
        
        if actualChecksum.lowercased() != expectedChecksum.lowercased() {
            if Config.isDebug {
                print("""
                    ❌ ModelDownload: SHA256 校验失败
                       期望: \(expectedChecksum)
                       实际: \(actualChecksum)
                    """)
            }
            throw ModelError.checksumMismatch(
                expected: expectedChecksum,
                actual: actualChecksum
            )
        }
    }
    
    // MARK: - Private Methods - Progress Calculation
    
    /// 更新总体下载进度
    private func updateOverallProgress() {
        let totalFiles = ModelConfig.modelFiles.count
        let completedFiles = downloadedFiles.count
        
        // 计算当前正在下载的文件的进度总和
        let currentProgress = fileProgress.values.reduce(0.0, +)
        
        // 总进度 = (已完成文件数 + 当前下载进度总和) / 总文件数
        // 确保进度不超过 1.0 (100%)
        let overall = min(1.0, (Double(completedFiles) + currentProgress) / Double(totalFiles))
        downloadProgress = overall
        
        // 更新状态消息
        let percentInt = Int(overall * 100)
        statusMessage = "正在下载... \(percentInt)% (\(completedFiles)/\(totalFiles) 文件)"
        
        // 调试日志
        if Config.isDebug && percentInt % 5 == 0 && percentInt != lastLoggedPercent {
            lastLoggedPercent = percentInt
            print("📥 ModelDownload: 总进度 \(percentInt)% (\(completedFiles)/\(totalFiles) 文件)")
        }
    }
    
    // MARK: - Private Methods - Error Handling
    
    private func setError(_ error: ModelError) async {
        self.error = error
        isDownloading = false
        statusMessage = error.localizedDescription
        
        if Config.isDebug {
            print("❌ ModelDownload: \(error.localizedDescription)")
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloadManager: URLSessionDownloadDelegate {
    
    /// 下载完成
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // 获取文件名
        guard let fileName = getFileName(from: downloadTask) else {
            if Config.isDebug {
                print("❌ ModelDownload: 无法获取文件名")
            }
            return
        }
        
        // 同步移动文件到临时安全位置
        let fileManager = FileManager.default
        let storageManager = MLXStorageManager.shared
        let tempFileURL = storageManager.tempDirectory.appendingPathComponent(fileName)
        
        do {
            // 确保临时目录存在
            try storageManager.ensureDirectoriesExist()
            
            // 删除旧的临时文件（如果存在）
            if fileManager.fileExists(atPath: tempFileURL.path) {
                try fileManager.removeItem(at: tempFileURL)
            }
            
            // 同步移动文件
            try fileManager.moveItem(at: location, to: tempFileURL)
            
            if Config.isDebug {
                print("✅ ModelDownload: \(fileName) 已移动到临时位置")
            }
            
            // 异步处理后续步骤
            Task { @MainActor in
                await self.fileDownloadCompleted(fileName: fileName, tempLocation: tempFileURL)
            }
            
        } catch {
            if Config.isDebug {
                print("❌ ModelDownload: \(fileName) 移动失败 - \(error)")
            }
            
            Task { @MainActor in
                await self.setError(ModelError.downloadFailed(error))
            }
        }
    }
    
    /// 下载进度更新
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let fileName = getFileName(from: downloadTask) else {
            return
        }
        
        Task { @MainActor in
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            fileProgress[fileName] = progress
            updateOverallProgress()
        }
    }
    
    /// 恢复下载
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didResumeAtOffset fileOffset: Int64,
        expectedTotalBytes: Int64
    ) {
        guard let fileName = getFileName(from: downloadTask) else {
            return
        }
        
        Task { @MainActor in
            let progress = Double(fileOffset) / Double(expectedTotalBytes)
            fileProgress[fileName] = progress
            
            if Config.isDebug {
                print("🔄 ModelDownload: \(fileName) 从 \(fileOffset) 字节恢复")
            }
        }
    }
    
    /// 从下载任务中获取文件名
    nonisolated private func getFileName(from task: URLSessionDownloadTask) -> String? {
        // 从 URL 中提取文件名
        return task.originalRequest?.url?.lastPathComponent
    }
}

// MARK: - URLSessionTaskDelegate

extension ModelDownloadManager: URLSessionTaskDelegate {
    
    /// 下载任务完成（包括成功和失败）
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error = error else {
            return
        }
        
        // 检查是否是用户取消
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            if Config.isDebug {
                print("⏸️ ModelDownload: 用户取消下载")
            }
            return
        }
        
        Task { @MainActor in
            await setError(ModelError.downloadFailed(error))
        }
    }
}

// MARK: - Model Error

/// 模型相关错误类型
enum ModelError: LocalizedError {
    case insufficientStorage(required: Int64, available: Int64)
    case downloadFailed(Error)
    case checksumMismatch(expected: String, actual: String)
    case verificationFailed(String)
    case modelNotFound
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .insufficientStorage(_, let available):
            return ModelConfig.insufficientStorageMessage(available: available)
            
        case .downloadFailed(let error):
            return "下载失败: \(error.localizedDescription)"
            
        case .checksumMismatch:
            return ModelConfig.checksumFailureMessage
            
        case .verificationFailed(let message):
            return "文件校验失败: \(message)"
            
        case .modelNotFound:
            return "模型文件未找到"
            
        case .networkUnavailable:
            return "网络不可用。请连接到WiFi后重试。"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .insufficientStorage:
            return "请清理设备存储空间后重试。"
            
        case .downloadFailed:
            return "请检查网络连接后重试。"
            
        case .checksumMismatch:
            return "请删除后重新下载。"
            
        case .verificationFailed:
            return "请重新下载模型文件。"
            
        case .modelNotFound:
            return "请重新下载模型。"
            
        case .networkUnavailable:
            return "请连接到WiFi网络后重试。"
        }
    }
}