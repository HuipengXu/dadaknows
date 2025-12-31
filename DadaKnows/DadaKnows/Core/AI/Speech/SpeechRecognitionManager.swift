//
//  SpeechRecognitionManager.swift
//  DadaKnows
//
//  语音识别管理器 - 负责语音录制和语音转文字功能
//  支持实时语音转文字，遵循苹果官方UI/UX规范
//
//  功能：
//  1. 语音录制权限管理
//  2. 实时语音识别
//  3. 音频质量检测
//  4. 错误处理和重试
//
//  创建日期: 2025-11-05
//

import Foundation
import Speech
import AVFoundation
import Combine

/// 语音识别管理器（单例）
@MainActor
class SpeechRecognitionManager: NSObject, ObservableObject {
    static let shared = SpeechRecognitionManager()

    // MARK: - Published Properties

    /// 是否正在录音
    @Published var isRecording = false

    /// 识别结果
    @Published var recognizedText = ""

    /// 录音状态消息
    @Published var statusMessage = "轻触开始录音"

    /// 错误信息
    @Published var error: SpeechError?

    /// 音量等级（0.0 - 1.0）
    @Published var audioLevel: Double = 0.0

    /// 录音权限状态
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    // MARK: - Private Properties

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var audioSession = AVAudioSession.sharedInstance()
    private var audioSessionCategory: AVAudioSession.Category = .playAndRecord

    /// 音频监控
    private var audioInputNode: AVAudioInputNode?
    private var audioFormat: AVAudioFormat?

    /// 音量监测定时器
    private var audioLevelTimer: Timer?

    // MARK: - Initialization

    private override init() {
        // 设置中文语音识别
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))

        super.init()

        // 不在init中配置音频会话，延迟到真正需要（startRecording）时配置
        // 避免启动时的50-200ms主线程阻塞
        
        // 监听语音识别权限变化
        updateAuthorizationStatus()

        if Config.isDebug {
            print("🎤 SpeechRecognition: 语音识别管理器初始化")
            print("   识别语言: zh-CN")
            print("   识别器可用: \(speechRecognizer?.isAvailable ?? false)")
        }
    }

    deinit {
        // 清理资源，但不调用MainActor方法
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        audioLevelTimer?.invalidate()
        audioLevelTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }

    // MARK: - Public Methods

    /// 请求录音权限
    func requestPermissions() async -> Bool {
        do {
            // 请求语音识别权限
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    DispatchQueue.main.async {
                        self.authorizationStatus = status
                        switch status {
                        case .authorized:
                            if Config.isDebug {
                                print("🎤 SpeechRecognition: 语音识别权限已授权")
                            }
                            continuation.resume(returning: true)
                        case .denied, .restricted:
                            if Config.isDebug {
                                print("🎤 SpeechRecognition: 语音识别权限被拒绝")
                            }
                            continuation.resume(returning: false)
                        case .notDetermined:
                            continuation.resume(returning: false)
                        @unknown default:
                            continuation.resume(returning: false)
                        }
                    }
                }
            }
        } catch {
            await setError(.permissionDenied(error))
            return false
        }
    }

    /// 开始录音
    /// - Returns: 是否成功开始录音
    func startRecording() async -> Bool {
        // 检查权限
        guard authorizationStatus == .authorized else {
            if Config.isDebug {
                print("🎤 SpeechRecognition: 未授权录音权限")
            }
            await setError(.permissionDenied(nil))
            return false
        }

        // 检查识别器是否可用
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            await setError(.recognizerUnavailable)
            return false
        }

        // 停止之前的录音
        if isRecording {
            stopRecording()
        }

        do {
            // 配置音频会话
            try audioSession.setCategory(audioSessionCategory, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            // 创建识别请求
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                await setError(.recognitionFailed("无法创建识别请求"))
                return false
            }

            // 配置识别请求
            recognitionRequest.shouldReportPartialResults = true

            // 获取输入节点
            audioInputNode = audioEngine.inputNode
            guard let inputNode = audioInputNode else {
                await setError(.audioEngineFailed)
                return false
            }

            // 配置音频格式
            audioFormat = inputNode.outputFormat(forBus: 0)

            // 安装录音tap
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: audioFormat) { [weak self] buffer, _ in
                recognitionRequest.append(buffer)
                self?.updateAudioLevel(from: buffer)
            }

            // 准备并启动音频引擎
            audioEngine.prepare()
            try audioEngine.start()

            // 开始语音识别
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    if let result = result {
                        // 更新识别结果
                        let transcription = result.bestTranscription.formattedString
                        self?.recognizedText = transcription

                        if Config.isDebug {
                            print("🎤 SpeechRecognition: 识别结果 - \(transcription)")
                        }

                        // 更新状态
                        if result.isFinal {
                            self?.statusMessage = "识别完成"
                        } else {
                            self?.statusMessage = "正在识别..."
                        }
                    }

                    if let error = error {
                        if Config.isDebug {
                            print("🎤 SpeechRecognition: 识别错误 - \(error)")
                        }
                        await self?.setError(.recognitionFailed(error.localizedDescription))
                    }
                }
            }

            isRecording = true
            statusMessage = "正在录音..."
            error = nil
            // 只有在开始新录音会话时才清空文本
            recognizedText = ""

            // 开始音量监控
            startAudioLevelMonitoring()

            if Config.isDebug {
                print("🎤 SpeechRecognition: 开始录音")
            }

            return true

        } catch {
            await setError(.audioEngineFailed)
            return false
        }
    }

    /// 停止录音
    func stopRecording() {
        guard isRecording else { return }

        // 停止音频引擎
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // 停止识别任务
        recognitionTask?.cancel()
        recognitionTask = nil

        // 结束音频并清理识别请求
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // 停止音量监控
        stopAudioLevelMonitoring()

        // 停用音频会话
        do {
            try audioSession.setActive(false)
        } catch {
            if Config.isDebug {
                print("🎤 SpeechRecognition: 停用音频会话失败 - \(error)")
            }
        }

        isRecording = false
        statusMessage = "录音已停止"
        audioLevel = 0.0

        if Config.isDebug {
            print("🎤 SpeechRecognition: 停止录音")
            print("   最终识别结果: \(recognizedText)")
        }
    }

    /// 清空识别结果
    func clearResults() {
        recognizedText = ""
        statusMessage = "轻触开始录音"
        error = nil
        audioLevel = 0.0
    }

    // MARK: - Private Methods

    /// 配置音频会话
    private func configureAudioSession() {
        do {
            try audioSession.setCategory(audioSessionCategory, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            if Config.isDebug {
                print("🎤 SpeechRecognition: 配置音频会话失败 - \(error)")
            }
        }
    }

    /// 更新权限状态
    private func updateAuthorizationStatus() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    /// 更新音频级别
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }

        // 计算平均音量
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0.0

        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }

        let averagePower = sum / Float(frameLength)
        let normalizedLevel = min(1.0, Double(averagePower) * 10) // 放大音量信号

        Task { @MainActor in
            audioLevel = normalizedLevel
        }
    }

    /// 开始音量监控
    private func startAudioLevelMonitoring() {
        stopAudioLevelMonitoring() // 确保之前的定时器已停止

        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            // 音量级别会在音频引擎的回调中更新
            // 这里不需要手动更新
        }
    }

    /// 停止音量监控
    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
    }

    /// 设置错误
    private func setError(_ error: SpeechError) async {
        self.error = error
        statusMessage = error.localizedDescription
        stopRecording()
    }
}

// MARK: - Speech Error

/// 语音识别错误类型
enum SpeechError: LocalizedError, Equatable {
    case permissionDenied(Error?)
    case recognizerUnavailable
    case audioEngineFailed
    case recognitionFailed(String)
    case microphoneUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "需要麦克风和语音识别权限才能使用语音输入功能"
        case .recognizerUnavailable:
            return "语音识别服务暂时不可用"
        case .audioEngineFailed:
            return "音频引擎启动失败"
        case .recognitionFailed(let message):
            return "语音识别失败：\(message)"
        case .microphoneUnavailable:
            return "麦克风不可用"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "请在设置中允许应用访问麦克风和语音识别"
        case .recognizerUnavailable:
            return "请稍后再试"
        case .audioEngineFailed:
            return "请检查设备音频设置"
        case .recognitionFailed:
            return "请重新录音"
        case .microphoneUnavailable:
            return "请检查麦克风连接"
        }
    }

    // MARK: - Equatable

    static func == (lhs: SpeechError, rhs: SpeechError) -> Bool {
        switch (lhs, rhs) {
        case (.permissionDenied(let lhsError), .permissionDenied(let rhsError)):
            return lhsError?.localizedDescription == rhsError?.localizedDescription
        case (.recognizerUnavailable, .recognizerUnavailable):
            return true
        case (.audioEngineFailed, .audioEngineFailed):
            return true
        case (.recognitionFailed(let lhsMessage), .recognitionFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.microphoneUnavailable, .microphoneUnavailable):
            return true
        default:
            return false
        }
    }
}