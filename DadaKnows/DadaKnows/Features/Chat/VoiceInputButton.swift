//
//  VoiceInputButton.swift
//  DadaKnows
//
//  语音输入按钮 - 简洁的语音录制按钮
//  点击切换录音状态，实时显示识别结果
//
//  功能：
//  1. 点击开始/停止录音
//  2. 实时音频波形显示
//  3. 简洁的状态指示
//  4. 触觉反馈
//
//  创建日期: 2025-11-05
//

import SwiftUI

/// 语音输入按钮
struct VoiceInputButton: View {
    @ObservedObject private var speechManager = SpeechRecognitionManager.shared

    let onVoiceInputUpdate: (String) -> Void
    let onError: (String) -> Void

    @State private var showingPermissionAlert = false
    @State private var lastRecognizedText = ""

    var body: some View {
        Button(action: toggleRecording) {
            ZStack {
                // 背景圆圈 - 录音时稍微放大
                Circle()
                    .fill(speechManager.isRecording ? Color.statusError.opacity(0.1) : Color.backgroundSecondary)
                    .frame(width: speechManager.isRecording ? 48 : 44, height: speechManager.isRecording ? 48 : 44)
                    .overlay(
                        Circle()
                            .stroke(speechManager.isRecording ? Color.statusError : Color.separator, lineWidth: speechManager.isRecording ? 2 : 1)
                    )

                // 麦克风图标 - 使用与发送按钮相同的字体大小
                Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic")
                    .font(.title2)
                    .foregroundColor(speechManager.isRecording ? .statusError : .textSecondary)

                // 录音时的音频波形指示器
                if speechManager.isRecording {
                    AudioWaveformView(audioLevel: speechManager.audioLevel)
                        .frame(width: 64, height: 64)
                }
            }
        }
        .buttonStyle(VoiceButtonStyle(isRecording: speechManager.isRecording))
        .alert(NSLocalizedString("voice_recognition_permission", comment: ""), isPresented: $showingPermissionAlert) {
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("go_to_settings", comment: "")) {
                openAppSettings()
            }
        } message: {
            Text(NSLocalizedString("voice_permission_message", comment: ""))
        }
        .onChange(of: speechManager.recognizedText) { _, newText in
            // 实时更新输入框内容
            if !newText.isEmpty {
                lastRecognizedText = newText
                onVoiceInputUpdate(newText)
            }
        }
        .onChange(of: speechManager.isRecording) { _, isRecording in
            // 停止录音时，恢复最后一次识别的文本
            if !isRecording && !lastRecognizedText.isEmpty {
                onVoiceInputUpdate(lastRecognizedText)
            }
        }
        .onChange(of: speechManager.error) { _, error in
            if let error = error {
                onError(error.localizedDescription)
            }
        }
    }

    // MARK: - Private Methods

    private func toggleRecording() {
        if speechManager.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        Task {
            if speechManager.authorizationStatus == .notDetermined {
                let granted = await speechManager.requestPermissions()
                if !granted {
                    showingPermissionAlert = true
                    return
                }
            }

            let _ = await speechManager.startRecording()
        }
    }

    private func stopRecording() {
        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        Task {
            speechManager.stopRecording()
        }
    }

    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

/// 音频波形视图
struct AudioWaveformView: View {
    let audioLevel: Double

    @State private var animationPhase: Double = 0

    var body: some View {
        ZStack {
            // 外圈波形
            Circle()
                .stroke(
                    Color.statusError.opacity(0.3),
                    style: StrokeStyle(
                        lineWidth: 2,
                        lineCap: .round
                    )
                )
                .scaleEffect(1.0 + audioLevel * 0.3)
                .opacity(0.8)

            // 内圈波形
            Circle()
                .stroke(
                    Color.statusError.opacity(0.6),
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        lineCap: .round
                    )
                )
                .scaleEffect(1.0 + audioLevel * 0.2)
                .opacity(0.9)

            // 脉冲动画
            ForEach(0..<3) { index in
                Circle()
                    .stroke(
                        Color.statusError.opacity(0.2),
                        style: StrokeStyle(
                            lineWidth: 1,
                            lineCap: .round
                        )
                    )
                    .scaleEffect(1.0 + sin(animationPhase + Double(index) * .pi / 3) * 0.1)
                    .opacity(0.5)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                animationPhase = .pi * 2
            }
        }
    }
}

/// 语音按钮样式
struct VoiceButtonStyle: ButtonStyle {
    let isRecording: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .brightness(configuration.isPressed ? -0.1 : 0)
    }
}

#Preview {
    VStack(spacing: 20) {
        VoiceInputButton(
            onVoiceInputUpdate: { text in
                print("Voice input: \(text)")
            },
            onError: { error in
                print("Voice error: \(error)")
            }
        )

        Spacer()
    }
    .padding()
}