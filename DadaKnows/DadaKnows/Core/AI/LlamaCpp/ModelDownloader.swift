//
//  ModelDownloader.swift
//  DadaKnows
//
//  模型下载管理器 - 支持前台、后台、暂停、续传和取消
//

import Foundation
import SwiftUI
import UserNotifications

@MainActor
class ModelDownloader: NSObject, ObservableObject {
    static let shared = ModelDownloader()
    
    @Published var downloadProgress: Double = 0.0
    @Published var downloadState: DownloadState = .idle
    @Published var downloadedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var isBackgroundMode = false
    
    private var currentDownloadTask: URLSessionDownloadTask?
    private var resumeData: Data?
    private let modelManager = ModelManager.shared
    
    // 支持后台下载的URLSession
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.DadaKnows.modeldownloader")
        config.isDiscretionary = false // 允许在非Wi-Fi网络下载（需用户同意）
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private override init() {
        super.init()
        
        // 检查是否有未完成的下载任务
        Task {
            await checkExistingDownloadTasks()
        }
    }
    
    // MARK: - Public Methods
    
    /// 开始下载模型
    /// - Parameter background: 是否使用后台模式
    func startDownload(background: Bool = false) async throws {
        // 防止重复启动下载
        guard downloadState != .downloading else {
            if Config.isDebug {
                print("📥 ModelDownloader: 下载已在进行中，忽略重复请求")
            }
            return
        }

        if Config.isDebug {
            print("📥 ModelDownloader: 开始下载 - 后台模式: \(background)")
        }
        
        // 检查存储空间
        guard modelManager.hasEnoughStorage() else {
            throw ModelDownloaderError.insufficientStorage
        }
        
        // 创建必要的目录
        try modelManager.createDirectoriesIfNeeded()
        
        await MainActor.run {
            self.isBackgroundMode = background
            self.downloadState = .downloading
            self.downloadProgress = 0.0
            self.downloadedBytes = 0
            self.totalBytes = Int64(ModelManager.modelInfo.expectedZipSize)
        }
        
        // 创建下载任务
        guard let url = URL(string: ModelManager.modelInfo.zipDownloadURL) else {
            throw ModelDownloaderError.invalidURL
        }
        
        if let resumeData = self.resumeData {
            // 恢复之前的下载
            currentDownloadTask = urlSession.downloadTask(withResumeData: resumeData)
            self.resumeData = nil
        } else {
            // 创建新的下载任务
            currentDownloadTask = urlSession.downloadTask(with: url)
        }
        
        currentDownloadTask?.resume()
        
        if background {
            await showBackgroundDownloadStartedMessage()
        }
    }
    
    /// 暂停下载
    func pauseDownload() async {
        if Config.isDebug {
            print("⏸️ ModelDownloader: 暂停下载")
        }
        
        currentDownloadTask?.cancel { [weak self] resumeData in
            Task { @MainActor in
                self?.resumeData = resumeData
                self?.downloadState = .paused
            }
        }
    }
    
    /// 取消下载
    func cancelDownload() async {
        if Config.isDebug {
            print("❌ ModelDownloader: 取消下载")
        }
        
        currentDownloadTask?.cancel()
        currentDownloadTask = nil
        resumeData = nil
        
        await MainActor.run {
            self.downloadState = .idle
            self.downloadProgress = 0.0
            self.downloadedBytes = 0
            self.totalBytes = 0
        }
        
        // 清理已下载的部分文件
        try? FileManager.default.removeItem(at: modelManager.zipDownloadPath)
    }
    
    /// 检查是否可以恢复下载
    var canResumeDownload: Bool {
        return resumeData != nil
    }
    
    // MARK: - Private Methods
    
    /// 检查现有的下载任务
    private func checkExistingDownloadTasks() async {
        urlSession.getAllTasks { [weak self] tasks in
            Task { @MainActor in
                guard let self = self else { return }
                let downloadTasks = tasks.compactMap { $0 as? URLSessionDownloadTask }
                if let existingTask = downloadTasks.first {
                    self.currentDownloadTask = existingTask
                    self.downloadState = .downloading
                    if Config.isDebug {
                        print("🔄 ModelDownloader: 发现现有下载任务")
                    }
                }
            }
        }
    }
    
    /// 显示后台下载开始消息
    private func showBackgroundDownloadStartedMessage() async {
        // 在UI上显示简短提示
        await MainActor.run {
            // 可以通过通知或toast显示
            if Config.isDebug {
                print("🌙 ModelDownloader: 后台下载已开始")
            }
        }
    }
    
    /// 处理下载完成
    private func postProcessDownloadedFile(at location: URL) async {
        do {
            if Config.isDebug {
                print("✅ ModelDownloader: 下载完成，开始处理文件")
                print("📁 源文件路径: \(location.path)")
                print("📁 源文件是否存在: \(FileManager.default.fileExists(atPath: location.path))")
            }
            
            // 首先验证源文件确实存在
            guard FileManager.default.fileExists(atPath: location.path) else {
                throw ModelDownloaderError.downloadedFileNotFound(location.path)
            }
            
            // 如果路径已经是最终文件，则跳过移动逻辑
            let finalPath = modelManager.zipDownloadPath
            guard location == finalPath else {
                // 已在 delegate 中完成移动，如果仍传入临时路径则抛错
                throw ModelDownloaderError.unexpectedFileLocation(location.path)
            }
            
            // 验证文件完整性
            guard modelManager.validateModelChecksum(at: finalPath) else {
                throw ModelDownloaderError.checksumMismatch
            }
            
            await MainActor.run {
                self.downloadState = .extracting
            }
            
            // 解压文件
            try modelManager.unzipModel(zipPath: finalPath)
            
            await MainActor.run {
                self.downloadState = .completed
            }
            
            // 如果是后台下载，发送通知
            if isBackgroundMode {
                await sendDownloadCompletedNotification()
            }
            
            if Config.isDebug {
                print("🎉 ModelDownloader: 模型准备就绪")
            }
            
        } catch {
            await MainActor.run {
                self.downloadState = .failed(error)
            }
            
            if Config.isDebug {
                print("❌ ModelDownloader: 处理失败 - \(error)")
            }
        }
    }
    
    /// 发送下载完成通知
    private func sendDownloadCompletedNotification() async {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("模型下载完成", comment: "")
        content.body = NSLocalizedString("'答答'的AI模型已下载完成，快来体验吧！", comment: "")
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "model_download_completed",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            if Config.isDebug {
                print("⚠️ ModelDownloader: 发送通知失败 - \(error)")
            }
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloader: URLSessionDownloadDelegate {
    
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            // This call is synchronous, non-isolated, and MUST happen before the delegate method returns.
            let finalURL = try moveDownloadedFileToFinalLocation(location: location)
            
            // Dispatch async to main actor for post-processing (checksum, extraction, etc.)
            Task { @MainActor in
                await postProcessDownloadedFile(at: finalURL)
            }
        } catch {
            // If the critical file move fails, dispatch async to main actor to update state.
            Task { @MainActor in
                self.downloadState = .failed(error)
                if Config.isDebug {
                    print("❌ ModelDownloader: 文件移动失败 - \(error.localizedDescription)")
                }
            }
        }
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor in
            self.downloadedBytes = totalBytesWritten
            
            // 使用预设的 totalBytes 作为备用，防止 totalBytesExpectedToWrite 为 -1
            var totalBytes = self.totalBytes
            if totalBytesExpectedToWrite != -1 /* URLSessionTransferSizeUnknown */ {
                totalBytes = totalBytesExpectedToWrite
                self.totalBytes = totalBytesExpectedToWrite
            }
            
            if totalBytes > 0 {
                self.downloadProgress = Double(totalBytesWritten) / Double(totalBytes)
            }
            
            if Config.isDebug && Int(totalBytesWritten) % (10 * 1024 * 1024) == 0 { // 每10MB打印一次
                let progressPercent = self.downloadProgress * 100
                print("📊 ModelDownloader: 下载进度 \(String(format: "%.1f", progressPercent))%")
            }
        }
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                let nsError = error as NSError
                
                if Config.isDebug {
                    print("❌ ModelDownloader: 下载错误详情")
                    print("  错误描述: \(error.localizedDescription)")
                    print("  错误代码: \(nsError.code)")
                    print("  错误域: \(nsError.domain)")
                    print("  用户信息: \(nsError.userInfo)")
                }
                
                // 保存恢复数据（如果可用）
                if let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                    self.resumeData = resumeData
                    self.downloadState = .paused
                    if Config.isDebug {
                        print("📄 ModelDownloader: 保存恢复数据，大小: \(resumeData.count) 字节")
                    }
                } else {
                    self.downloadState = .failed(error)
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum DownloadState: Equatable {
    case idle
    case downloading
    case paused
    case extracting
    case completed
    case failed(Error)
    
    static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.downloading, .downloading),
             (.paused, .paused),
             (.extracting, .extracting),
             (.completed, .completed):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
    
    var localizedDescription: String {
        switch self {
        case .idle:
            return NSLocalizedString("等待中", comment: "")
        case .downloading:
            return NSLocalizedString("下载中", comment: "")
        case .paused:
            return NSLocalizedString("已暂停", comment: "")
        case .extracting:
            return NSLocalizedString("解压中", comment: "")
        case .completed:
            return NSLocalizedString("已完成", comment: "")
        case .failed(let error):
            return String(format: NSLocalizedString("失败：%@", comment: ""), error.localizedDescription)
        }
    }
}

enum ModelDownloaderError: LocalizedError {
    case invalidURL
    case insufficientStorage
    case checksumMismatch
    case extractionFailed
    case networkError(Error)
    case downloadedFileNotFound(String)
    case targetDirectoryCreationFailed(String)
    case unexpectedFileLocation(String)
    case couldNotLocateDocumentsDirectory
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("无效的下载链接", comment: "")
        case .insufficientStorage:
            return NSLocalizedString("存储空间不足，请清理设备空间后重试", comment: "")
        case .checksumMismatch:
            return NSLocalizedString("文件校验失败，请重新下载", comment: "")
        case .extractionFailed:
            return NSLocalizedString("文件解压失败", comment: "")
        case .networkError(let error):
            return String(format: NSLocalizedString("网络错误：%@", comment: ""), error.localizedDescription)
        case .downloadedFileNotFound(let path):
            return String(format: NSLocalizedString("下载的文件不存在：%@", comment: ""), path)
        case .targetDirectoryCreationFailed(let path):
            return String(format: NSLocalizedString("无法创建目标目录：%@", comment: ""), path)
        case .unexpectedFileLocation(let path):
            return String(format: NSLocalizedString("文件位置异常：%@", comment: ""), path)
        case .couldNotLocateDocumentsDirectory:
            return NSLocalizedString("无法访问应用数据目录", comment: "")
        }
    }
}

// MARK: - File I/O Helper
extension ModelDownloader {
    /// NOTE: This function is `nonisolated` because it is called directly from a URLSession delegate method
    /// running on a background thread. It must be self-contained and not access any actor-isolated state from `self`.
    private nonisolated func moveDownloadedFileToFinalLocation(location: URL) throws -> URL {
        let fileManager = FileManager.default
        
        // Reconstruct the destination path using static information to avoid data races.
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ModelDownloaderError.couldNotLocateDocumentsDirectory
        }
        let modelsDirectory = documentsPath.appendingPathComponent("Models")
        let finalPath = modelsDirectory.appendingPathComponent(ModelManager.modelInfo.zipFileName)
        
        // The rest of the logic is synchronous file I/O, which is safe to perform here.
        if !fileManager.fileExists(atPath: modelsDirectory.path) {
            try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        if fileManager.fileExists(atPath: finalPath.path) {
            try fileManager.removeItem(at: finalPath)
        }
        
        try fileManager.moveItem(at: location, to: finalPath)
        
        return finalPath
    }
}
