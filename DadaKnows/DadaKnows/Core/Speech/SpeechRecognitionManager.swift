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
        // 优先使用中文识别器，如果不可用则使用系统默认
        if let chineseRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")) {
            speechRecognizer = chineseRecognizer
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
                    self?.errorMessage = "语音识别权限被拒绝"
                @unknown default:
                    self?.isAuthorized = false
                    self?.errorMessage = "未知的权限状态"
                }
            }
        }
    }
    
    private func requestMicrophonePermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    if !granted {
                        self?.errorMessage = "麦克风权限被拒绝"
                    }
                }
            }
        } else {
            audioSession.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    if !granted {
                        self?.errorMessage = "麦克风权限被拒绝"
                    }
                }
            }
        }
    }
    
    // MARK: - Recording Control
    
    func startRecording() {
        guard isAuthorized else {
            errorMessage = "请先授权语音识别权限"
            return
        }
        
        guard !isRecording else { return }
        
        // 停止之前的任务
        stopRecording()
        
        do {
            try startRecordingSession()
            isRecording = true
            recognizedText = ""
            errorMessage = nil
        } catch {
            errorMessage = "开始录音失败: \(error.localizedDescription)"
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        isRecording = false
    }
    
    private func startRecordingSession() throws {
        // 配置音频会话
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.recognitionRequestFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // 如果设备支持，启用设备上识别以提高隐私性
        if #available(iOS 13.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        
        // 获取音频输入节点
        let inputNode = audioEngine.inputNode
        
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
                    self?.errorMessage = "语音识别错误: \(error.localizedDescription)"
                    self?.stopRecording()
                }
            }
        }
        
        // 配置音频格式
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // 启动音频引擎
        audioEngine.prepare()
        try audioEngine.start()
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
        stopRecording()
        
        let locale = Locale(identifier: languageCode)
        if let recognizer = SFSpeechRecognizer(locale: locale) {
            speechRecognizer = recognizer
            speechRecognizer?.delegate = self
        } else {
            errorMessage = "不支持的语言: \(languageCode)"
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
                self.errorMessage = "语音识别服务暂时不可用"
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
    
    var errorDescription: String? {
        switch self {
        case .recognitionRequestFailed:
            return "创建语音识别请求失败"
        case .audioEngineError:
            return "音频引擎错误"
        case .noMicrophonePermission:
            return "没有麦克风权限"
        case .noSpeechPermission:
            return "没有语音识别权限"
        }
    }
}
