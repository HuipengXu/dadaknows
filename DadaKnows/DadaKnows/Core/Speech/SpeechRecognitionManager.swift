//
//  SpeechRecognitionManager.swift
//  DadaKnows
//
//  语音识别管理器
//

import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
class SpeechRecognitionManager: NSObject, ObservableObject {
    static let shared = SpeechRecognitionManager()
    
    @Published var isRecording = false
    @Published var isAuthorized = false
    @Published var recognizedText = ""
    @Published var errorMessage: String?
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioSession = AVAudioSession.sharedInstance()
    
    override init() {
        super.init()
        setupSpeechRecognizer()
        requestAuthorization()
    }
    
    // MARK: - Setup
    
    private func setupSpeechRecognizer() {
        // 优先使用英文识别器，如果不可用则使用系统默认
        if let englishRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) {
            speechRecognizer = englishRecognizer
        } else {
            speechRecognizer = SFSpeechRecognizer()
        }
        
        speechRecognizer?.delegate = self
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.isAuthorized = true
                    self?.requestMicrophonePermission()
                case .denied, .restricted, .notDetermined:
                    self?.isAuthorized = false
                    self?.errorMessage = NSLocalizedString("语音识别权限被拒绝", comment: "")
                @unknown default:
                    self?.isAuthorized = false
                    self?.errorMessage = NSLocalizedString("未知的权限状态", comment: "")
                }
            }
        }
    }
    
    private func requestMicrophonePermission() {
        print("🎤 Requesting microphone permission...")
        
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    print("🎤 iOS 17+ microphone permission: \(granted)")
                    if !granted {
                        self?.errorMessage = NSLocalizedString("需要麦克风权限", comment: "")
                    }
                }
            }
        } else {
            audioSession.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    print("🎤 Legacy microphone permission: \(granted)")
                    if !granted {
                        self?.errorMessage = NSLocalizedString("需要麦克风权限", comment: "")
                    }
                }
            }
        }
    }
    
    // MARK: - Recording Control
    
    func startRecording() {
        print("🎤 Starting recording...")
        
        guard isAuthorized else {
            errorMessage = NSLocalizedString("请先授权语音识别权限", comment: "")
            print("❌ Not authorized for speech recognition")
            return
        }
        
        guard !isRecording else { 
            print("⚠️ Already recording")
            return 
        }
        
        // 停止之前的任务
        stopRecording()
        
        do {
            try startRecordingSession()
            isRecording = true
            recognizedText = ""
            errorMessage = nil
            print("✅ Recording started successfully")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func isRunningOnSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        isRecording = false
        
        // 停止音频引擎
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // 移除输入节点上的 tap
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // 清理识别相关资源
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        // 重置音频会话
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    private func startRecordingSession() throws {
        // 在iOS 26及以上版本的模拟器上，直接抛出错误，因为存在已知的音频引擎bug
        if #available(iOS 26.0, *) {
            #if targetEnvironment(simulator)
            print("❌ Recording is not supported on iOS 26+ simulators due to audio engine bugs.")
            throw SpeechError.simulatorNotSupported
            #endif
        }

        print("🔧 Starting recording session...")
        
        // 确保音频引擎处于干净状态
        if audioEngine.isRunning {
            print("⚠️ Stopping existing audio engine")
            audioEngine.stop()
        }
        
        // 移除可能存在的旧 tap
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // 配置音频会话 - 使用更适合语音识别的配置
        do {
            print("🔧 Configuring audio session...")
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ Audio session configured successfully")
        } catch {
            print("❌ Audio session configuration failed: \(error)")
            throw SpeechError.audioEngineError
        }
        
        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("❌ Failed to create recognition request")
            throw SpeechError.recognitionRequestFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // 如果设备支持，启用设备上识别以提高隐私性
        if #available(iOS 13.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        
        // 获取音频输入节点
        let inputNode = audioEngine.inputNode
        print("🔧 Input node format: \(inputNode.outputFormat(forBus: 0))")
        
        // 创建识别任务
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.recognizedText = result.bestTranscription.formattedString
                    
                    // 如果识别完成
                    if result.isFinal {
                        self?.stopRecording()
                    }
                }
                
                if let error = error {
                    self?.errorMessage = String(format: NSLocalizedString("语音识别错误: %@", comment: ""), error.localizedDescription)
                    self?.stopRecording()
                }
            }
        }
        
        // 使用输入节点的原生格式安装 tap，避免与硬件格式不匹配
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        print("🔧 Original format - Sample Rate: \(recordingFormat.sampleRate), Channels: \(recordingFormat.channelCount)")
        let bufferSize: AVAudioFrameCount = 2048
        print("🔧 Installing tap with nil format (use HW/client format), buffer size: \(bufferSize)")
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: nil) { [weak recognitionRequest] buffer, _ in
            recognitionRequest?.append(buffer)
        }
        
        // 启动音频引擎
        do {
            print("🔧 Preparing audio engine...")
            audioEngine.prepare()
            print("🔧 Starting audio engine...")
            try audioEngine.start()
            print("✅ Audio engine started successfully")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
            throw SpeechError.audioEngineError
        }
    }
    
    // MARK: - Utility Methods
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func clearText() {
        recognizedText = ""
        errorMessage = nil
    }
    
    // MARK: - Language Support
    
    func switchToLanguage(_ languageCode: String) {
        // 确保完全停止当前录音
        if isRecording {
            stopRecording()
        }
        
        let locale = Locale(identifier: languageCode)
        if let recognizer = SFSpeechRecognizer(locale: locale) {
            speechRecognizer = recognizer
            speechRecognizer?.delegate = self
        } else {
            errorMessage = String(format: NSLocalizedString("不支持的语言: %@", comment: ""), languageCode)
        }
    }
    
    func getSupportedLanguages() -> [String] {
        return SFSpeechRecognizer.supportedLocales().map { $0.identifier }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognitionManager: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                self.errorMessage = NSLocalizedString("语音识别服务暂时不可用", comment: "")
                self.stopRecording()
            }
        }
    }
}

// MARK: - Error Types

enum SpeechError: Error, LocalizedError {
    case recognitionRequestFailed
    case audioEngineError
    case noMicrophonePermission
    case noSpeechPermission
    case simulatorNotSupported
    
    var errorDescription: String? {
        switch self {
        case .recognitionRequestFailed:
            return NSLocalizedString("创建语音识别请求失败", comment: "")
        case .audioEngineError:
            return NSLocalizedString("音频引擎错误", comment: "")
        case .noMicrophonePermission:
            return NSLocalizedString("需要麦克风权限", comment: "")
        case .noSpeechPermission:
            return NSLocalizedString("需要语音识别权限", comment: "")
        case .simulatorNotSupported:
            return NSLocalizedString("模拟器不支持录音功能，请在真机上测试", comment: "")
        }
    }
}
