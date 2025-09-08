//
//  ChatView.swift
//  DadaKnows
//
//  Enhanced with accessibility support
//

import SwiftUI
import Combine

struct ChatView: View {
    @StateObject private var aiManager = AIManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var speechManager = SpeechRecognitionManager.shared
    @StateObject private var offlineManager = OfflineManager.shared
    @StateObject private var analyticsManager = AnalyticsManager.shared
    
    // Parameters from HomeView
    let question: String
    let targetAge: Int
    let onDismiss: () -> Void
    
    @State private var currentQuestion = ""
    @State private var isListening = false
    @State private var showingVoicePermissionAlert = false
    @State private var showingProUpgrade = false
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Chat Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(aiManager.chatHistory) { chat in
                                ChatBubbleView(chat: chat)
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("\(chat.isFromUser ? "You asked" : "Dada answered"): \(chat.message)")
                            }
                            
                            if aiManager.isLoading {
                                TypingIndicator()
                                    .accessibilityLabel("Dada is thinking")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: aiManager.chatHistory.count) { _, _ in
                        if let lastChat = aiManager.chatHistory.last {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                proxy.scrollTo(lastChat.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Offline Indicator
                if !offlineManager.isOnline {
                    OfflineIndicator()
                        .accessibilityLabel("You are offline. Some features may not be available.")
                }
                
                // Input Area
                VStack(spacing: 12) {
                    // Usage limit indicator for free users
                    if !subscriptionManager.isProMember {
                        if let remaining = subscriptionManager.getRemainingQuestions() {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(.secondary)
                                Text("今天还可以问 \(remaining) 个问题")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("升级Pro") {
                                    showingProUpgrade = true
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            .padding(.horizontal)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("You have \(remaining) questions remaining today. Tap upgrade Pro for unlimited questions.")
                        }
                    }
                    
                    // Input field and buttons
                    HStack(spacing: 12) {
                        // Voice input button
                        Button(action: handleVoiceInput) {
                            Image(systemName: isListening ? "mic.fill" : "mic")
                                .font(.title2)
                                .foregroundColor(isListening ? .red : .blue)
                                .scaleEffect(isListening ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: isListening)
                        }
                        .accessibilityIdentifier("voiceInputButton")
                        .accessibilityLabel(isListening ? "Stop recording" : "Start voice input")
                        .accessibilityHint("Double tap to record your question using voice")
                        .disabled(!subscriptionManager.canUseFeature(.voiceInput) && !subscriptionManager.isProMember)
                        
                        // Text input
                        TextField("想问答答什么问题呢？", text: $currentQuestion, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(1...4)
                            .accessibilityIdentifier("questionInput")
                            .accessibilityLabel("Question input field")
                            .accessibilityHint("Type your question here")
                            .onSubmit {
                                sendQuestion()
                            }
                        
                        // Send button
                        Button(action: sendQuestion) {
                            Image(systemName: "paperplane.fill")
                                .font(.title2)
                                .foregroundColor(canSendQuestion ? .blue : .gray)
                        }
                        .accessibilityIdentifier("sendButton")
                        .accessibilityLabel("Send question")
                        .accessibilityHint("Double tap to send your question to Dada")
                        .disabled(!canSendQuestion)
                    }
                    .padding()
                }
                .background(Color(UIColor.systemBackground))
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("ChatView")
            .navigationTitle("问问答答")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        onDismiss()
                    }
                }
            }
            .onReceive(speechManager.$recognizedText) { text in
                if !text.isEmpty {
                    currentQuestion = text
                    isListening = false
                }
            }
            .onReceive(speechManager.$isRecording) { recording in
                isListening = recording
            }
            .alert("需要麦克风权限", isPresented: $showingVoicePermissionAlert) {
                Button("设置") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("请在设置中允许访问麦克风以使用语音输入功能")
            }
            .sheet(isPresented: $showingProUpgrade) {
                ProSubscriptionView()
            }
        }
        .onAppear {
            // Set initial question and send it automatically
            currentQuestion = question
            
            // Track analytics
            analyticsManager.trackSessionStart()
            
            // Automatically send the initial question
            if !question.isEmpty {
                sendQuestion()
            }
        }
    }
    
    private var canSendQuestion: Bool {
        !currentQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !aiManager.isLoading &&
        subscriptionManager.canAskQuestion()
    }
    
    private func sendQuestion() {
        guard canSendQuestion else { return }
        
        let question = currentQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        currentQuestion = ""
        
        // Track usage
        subscriptionManager.incrementQuestionCount()
        analyticsManager.trackQuestionAsked(question: question, category: "general", targetAge: targetAge)
        
        // Send to AI
        Task {
            await aiManager.sendMessage(question)
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func handleVoiceInput() {
        guard subscriptionManager.canUseFeature(.voiceInput) || subscriptionManager.isProMember else {
            showingProUpgrade = true
            return
        }
        
        if isListening {
            speechManager.stopRecording()
        } else {
            if speechManager.isAuthorized {
                speechManager.startRecording()
                analyticsManager.trackVoiceInputUsed()
            } else {
                speechManager.requestAuthorization()
                showingVoicePermissionAlert = true
            }
        }
    }
}

struct ChatBubbleView: View {
    let chat: ChatMessage
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    var body: some View {
        HStack {
            if chat.isFromUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: chat.isFromUser ? .trailing : .leading, spacing: 4) {
                Text(chat.message)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(chat.isFromUser ? Color.blue : Color(UIColor.systemGray5))
                    )
                    .foregroundColor(chat.isFromUser ? .white : .primary)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(chat.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !chat.isFromUser {
                Spacer(minLength: 50)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct TypingIndicator: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animationPhase
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(UIColor.systemGray5))
            )
            
            Spacer(minLength: 50)
        }
        .onAppear {
            animationPhase = 0
            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

#Preview {
    ChatView(
        question: "什么是恐龙？",
        targetAge: 5,
        onDismiss: {}
    )
}