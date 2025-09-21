//
//  VoiceInputButton.swift
//  DadaKnows
//
//  语音输入按钮组件
//

import SwiftUI

struct VoiceInputButton: View {
    @ObservedObject private var speechManager = SpeechRecognitionManager.shared
    @Binding var text: String
    @State private var showPermissionAlert = false
    
    var body: some View {
        Button(action: handleVoiceInput) {
            ZStack {
                Circle()
                    .fill(speechManager.isRecording ? Color.statusError : Color.appPrimary)
                    .frame(width: 50, height: 50)
                    .scaleEffect(speechManager.isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: speechManager.isRecording)
                
                Image(systemName: speechManager.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .disabled(!speechManager.isAuthorized)
        .opacity(speechManager.isAuthorized ? 1.0 : 0.5)
        .overlay(
            // 录音时的波纹效果
            Group {
                if speechManager.isRecording {
                    Circle()
                        .stroke(Color.statusError.opacity(0.3), lineWidth: 2)
                        .frame(width: 70, height: 70)
                        .scaleEffect(speechManager.isRecording ? 1.5 : 1.0)
                        .opacity(speechManager.isRecording ? 0.0 : 1.0)
                        .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: speechManager.isRecording)
                }
            }
        )
        .alert(NSLocalizedString("需要权限", comment: ""), isPresented: $showPermissionAlert) {
            Button(NSLocalizedString("设置", comment: "")) {
                openSettings()
            }
            Button(NSLocalizedString("取消", comment: ""), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("请在设置中允许DadaKnows访问麦克风和语音识别功能", comment: ""))
        }
        .onChange(of: speechManager.recognizedText) { oldValue, newValue in
            if !newValue.isEmpty && !speechManager.isRecording {
                text = newValue
                speechManager.clearText()
            }
        }
        .onChange(of: speechManager.errorMessage) { oldValue, newValue in
            if newValue != nil && !speechManager.isAuthorized {
                showPermissionAlert = true
            }
        }
    }
    
    private func handleVoiceInput() {
        if speechManager.isAuthorized {
            speechManager.toggleRecording()
        } else {
            speechManager.requestAuthorization()
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Voice Input Field

struct VoiceInputField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.textPrimary)
            
            HStack {
                TextField(placeholder, text: $text, axis: .vertical)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .textFieldStyle(.roundedBorder)
                
                VoiceInputButton(text: $text)
                    .padding(.leading, 8)
            }
        }
    }
}

// MARK: - Voice Recording Overlay

struct VoiceRecordingOverlay: View {
    @ObservedObject private var speechManager = SpeechRecognitionManager.shared
    
    var body: some View {
        if speechManager.isRecording {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 录音动画
                    ZStack {
                        Circle()
                            .fill(Color.statusError.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .scaleEffect(speechManager.isRecording ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: speechManager.isRecording)
                        
                        Circle()
                            .fill(Color.statusError)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "mic.fill")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Text(NSLocalizedString("正在聆听...", comment: ""))
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if !speechManager.recognizedText.isEmpty {
                        Text(speechManager.recognizedText)
                            .font(.body)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(12)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(NSLocalizedString("停止录音", comment: "")) {
                        speechManager.stopRecording()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.statusError)
                    .cornerRadius(20)
                }
                .padding()
            }
        }
    }
}

#Preview {
    VStack {
        VoiceInputField(
            title: "问题",
            text: .constant(""),
            placeholder: "请输入您的问题..."
        )
        
        VoiceInputButton(text: .constant(""))
    }
    .padding()
}
