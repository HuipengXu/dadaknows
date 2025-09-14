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
    @StateObject private var chatService = ChatService.shared
    
    // Parameters from HomeView or HistoryView
    let question: String
    let targetAge: Int
    let onDismiss: () -> Void
    let historicalSession: ChatSession? // Optional historical session to display
    
    @State private var currentQuestion = ""
    @State private var isListening = false
    @State private var showingVoicePermissionAlert = false
    @State private var showingProUpgrade = false
    @State private var sessionStartTime: Date?
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Chat Messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                // Unified chat history display
                                ForEach(aiManager.chatHistory) { chat in
                                    ChatBubbleView(chat: chat)
                                        .accessibilityElement(children: .combine)
                                        .accessibilityLabel("\(chat.isFromUser ? "You asked" : "Dada answered"): \(chat.message)")
                                }
                                
                                if aiManager.isLoading && (aiManager.chatHistory.last?.isFromUser ?? true) {
                                    TypingIndicator()
                                        .accessibilityLabel("Dada is thinking")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .background(Color.backgroundSecondary)
                        .onChange(of: aiManager.chatHistory.count) { _, _ in
                            if let lastChat = aiManager.chatHistory.last {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(lastChat.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Input Area
                    VStack(spacing: 0) {
                        // Usage limit indicator for free users
                        if !subscriptionManager.isProMember && !aiManager.isUsingOnDeviceModel {
                            if let remaining = subscriptionManager.getRemainingQuestions() {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.textSecondary)
                                        .font(.caption)
                                    
                                    Text("今天还可以问 \(remaining) 个问题")
                                        .font(.caption)
                                        .foregroundColor(.textSecondary)
                                    
                                    Spacer()
                                    
                                    if remaining <= 5 {
                                        Button("升级Pro") {
                                            showingProUpgrade = true
                                        }
                                        .font(.caption)
                                        .foregroundColor(.appPrimary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.backgroundTertiary)
                            }
                        }
                        
                        // Input field and buttons
                        HStack(spacing: 12) {
                            // Text input
                            TextField("输入你的问题...", text: $currentQuestion, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(1...4)
                                .onSubmit {
                                    sendQuestion()
                                }
                            
                            // Send button
                            Button(action: sendQuestion) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(canSendQuestion ? .appPrimary : .textTertiary)
                            }
                            .buttonStyle(.plain)
                            .disabled(!canSendQuestion)
                            .opacity(canSendQuestion ? 1.0 : 0.5)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.backgroundPrimary)
                    }
                }
                
                // Floating voice button in bottom right corner
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: handleVoiceInput) {
                            ZStack {
                                Circle()
                                    .fill(isListening ? Color.statusError : Color.appPrimary)
                                    .frame(width: 50, height: 50)
                                    .scaleEffect(isListening ? 1.2 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: isListening)
                                
                                Image(systemName: isListening ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .overlay(
                            // Recording ripple effect
                            Group {
                                if isListening {
                                    Circle()
                                        .stroke(Color.statusError.opacity(0.3), lineWidth: 2)
                                        .frame(width: 70, height: 70)
                                        .scaleEffect(isListening ? 1.5 : 1.0)
                                        .opacity(isListening ? 0.0 : 1.0)
                                        .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: isListening)
                                }
                            }
                        )
                        .padding(.trailing, 20)
                        .padding(.bottom, 100) // Above input area
                    }
                }
            }
            .navigationTitle(historicalSession != nil ? "继续对话" : "对话")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") {
                        // Track session end before dismissing
                        if let startTime = sessionStartTime {
                            let sessionDuration = Date().timeIntervalSince(startTime)
                            analyticsManager.trackSessionEnd(duration: sessionDuration)
                        }
                        onDismiss()
                    }
                    .foregroundColor(.appPrimary)
                }
            }
            .onReceive(speechManager.$recognizedText) { text in
                if !text.isEmpty && !speechManager.isRecording {
                    currentQuestion = text
                    isListening = false
                    speechManager.clearText()
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
            if let session = historicalSession {
                // Load historical chat to continue the conversation
                aiManager.loadHistoricalChat(from: session)
            } else {
                // Clear previous chat history when starting a new session
                aiManager.clearChatHistory()
            }

            // Set initial question
            currentQuestion = question
            
            // Track analytics and session start time
            sessionStartTime = Date()
            analyticsManager.trackSessionStart()
            
            // Create a new chat session in backend for this page instance
            Task {
                if let session = historicalSession, let firstChat = session.chats.first {
                    // For historical sessions, use the first question as title
                    await chatService.startNewSessionIfNeeded(title: String((firstChat.question ?? "继续对话").prefix(80)))
                } else {
                    // For new sessions, use the current question
                    await chatService.startNewSessionIfNeeded(title: String(question.prefix(80)))
                }
            }
            
            // Automatically send the initial question only for new conversations
            if !question.isEmpty && historicalSession == nil {
                sendQuestion()
            }
        }
        .onDisappear {
            // Track session end time when view disappears
            if let startTime = sessionStartTime {
                let sessionDuration = Date().timeIntervalSince(startTime)
                analyticsManager.trackSessionEnd(duration: sessionDuration)
            }
            chatService.endCurrentSession()
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
        
        // Send to AI
        Task {
            await aiManager.sendMessage(question, targetAge: targetAge)
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func handleVoiceInput() {
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
        HStack(alignment: .bottom, spacing: 8) {
            if chat.isFromUser {
                Spacer(minLength: 60)
            } else {
                // AI avatar
                Circle()
                    .fill(Color.appPrimary.opacity(0.1))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.appPrimary)
                    )
            }
            
            VStack(alignment: chat.isFromUser ? .trailing : .leading, spacing: 4) {
                Text(chat.message)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(chat.isFromUser ? Color.userMessageBackground : 
                                  (chat.isError ? Color.statusError : Color.aiMessageBackground))
                    )
                    .foregroundColor(chat.isFromUser ? .white : (chat.isError ? .white : .textPrimary))
                    .font(.body)
                
                Text(chat.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.textTertiary)
            }
            
            if !chat.isFromUser {
                Spacer(minLength: 60)
            } else {
                // User avatar placeholder
                Circle()
                    .fill(Color.appPrimary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    )
            }
        }
    }
}

struct TypingIndicator: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // AI avatar
            Circle()
                .fill(Color.appPrimary.opacity(0.1))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.appPrimary)
                )
            
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.textSecondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                        .opacity(animationPhase == index ? 1.0 : 0.5)
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
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.aiMessageBackground)
            )
            
            Spacer(minLength: 60)
        }
        .onAppear {
            animationPhase = 0
            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

// MARK: - Historical Chat Bubble View
struct HistoricalChatBubbleView: View {
    let chat: Chat
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if chat.question != nil {
                Spacer(minLength: 60)
            } else {
                // AI avatar
                Circle()
                    .fill(Color.appPrimary.opacity(0.1))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.appPrimary)
                    )
            }
            
            VStack(alignment: chat.question != nil ? .trailing : .leading, spacing: 4) {
                Text(chat.question ?? chat.answer ?? "")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(chat.question != nil ? Color.userMessageBackground : Color.aiMessageBackground)
                    )
                    .foregroundColor(chat.question != nil ? .white : .textPrimary)
                    .font(.body)
                
                if let createdAt = chat.createdAt {
                    Text(createdAt, style: .time)
                        .font(.caption2)
                        .foregroundColor(.textTertiary)
                }
            }
            
            if chat.question == nil {
                Spacer(minLength: 60)
            } else {
                // User avatar
                Circle()
                    .fill(Color.appPrimary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    )
            }
        }
        .opacity(0.8) // Slightly faded to distinguish from new messages
    }
}

#Preview {
    ChatView(
        question: "什么是恐龙？",
        targetAge: 5,
        onDismiss: {},
        historicalSession: nil
    )
}