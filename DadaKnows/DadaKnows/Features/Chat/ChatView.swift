//
//  ChatView.swift
//  DadaKnows
//
//  聊天对话界面 - 显示AI回答和用户交互
//

import SwiftUI

struct ChatView: View {
    let question: String
    let targetAge: Int
    let onDismiss: () -> Void
    
    @ObservedObject private var aiManager = AIManager.shared
    @ObservedObject private var dataManager = DataManager.shared
    @ObservedObject private var offlineManager = OfflineManager.shared
    @State private var currentAnswer = ""
    @State private var isStreaming = false
    @State private var hasAnswered = false
    @State private var showRegenerateOption = false
    @State private var savedChat: Chat?
    
    var body: some View {
        ZStack {
            Color.creamYellow
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Chat content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 25) {
                            // Question bubble
                            questionBubble
                            
                            // Answer section
                            if hasAnswered || isStreaming {
                                answerBubble
                            }
                            
                            // Loading indicator
                            if isStreaming && currentAnswer.isEmpty {
                                thinkingIndicator
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .id("chatContent")
                    }
                    .onChange(of: currentAnswer) { oldValue, newValue in
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("chatContent", anchor: .bottom)
                        }
                    }
                }
                
                Spacer()
                
                // Action buttons
                if hasAnswered && !isStreaming {
                    actionButtons
                }
            }
        }
        .overlay(
            // Voice recording overlay
            VoiceRecordingOverlay()
        )
        .onAppear {
            startAnswering()
        }
    }
    
    private var headerSection: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.lightGray)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("答答回答中...")
                    .font(.headline)
                    .foregroundColor(.darkGray)
                
                // 添加离线指示器
                OfflineIndicator()
            }
            
            Spacer()
            
            // Age indicator
            Text("\(targetAge)岁")
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.vibrantOrange)
                .cornerRadius(15)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color.white.opacity(0.9))
    }
    
    private var questionBubble: some View {
        HStack(alignment: .top, spacing: 12) {
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                Text(question)
                    .font(.system(size: 16))
                    .foregroundColor(.darkGray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(18)
                
                Text("刚刚")
                    .font(.caption)
                    .foregroundColor(.lightGray)
            }
            
            // User avatar
            Circle()
                .fill(Color.skyBlue)
                .frame(width: 35, height: 35)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                )
        }
    }
    
    private var answerBubble: some View {
        HStack(alignment: .top, spacing: 12) {
            // AI avatar
            Circle()
                .fill(Color.tenderYellow)
                .frame(width: 35, height: 35)
                .overlay(
                    Image(systemName: "face.smiling")
                        .font(.system(size: 16))
                        .foregroundColor(.vibrantOrange)
                )
            
            VStack(alignment: .leading, spacing: 8) {
                // Answer content
                Text(currentAnswer)
                    .font(.system(size: 16))
                    .foregroundColor(.darkGray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(18)
                    .animation(.none, value: currentAnswer) // Prevent animation on text updates
                
                // Timestamp
                if hasAnswered {
                    Text("刚刚")
                        .font(.caption)
                        .foregroundColor(.lightGray)
                }
            }
            
            Spacer()
        }
    }
    
    private var thinkingIndicator: some View {
        SlideInView(from: .leading, delay: 0.2) {
            HStack(alignment: .top, spacing: 12) {
                PulseView {
                    Circle()
                        .fill(Color.tenderYellow)
                        .frame(width: 35, height: 35)
                        .overlay(
                            Image(systemName: "face.smiling")
                                .font(.system(size: 16))
                                .foregroundColor(.vibrantOrange)
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TypingIndicator()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(18)
                    .shimmer()
                    
                    Text("答答正在思考...")
                        .font(.caption)
                        .foregroundColor(.lightGray)
                }
                
                Spacer()
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 15) {
            // "懂啦!" button
            Button(action: handleUnderstood) {
                HStack(spacing: 8) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 16))
                    Text("懂啦！")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.vibrantOrange)
                .cornerRadius(22)
            }
            
            // "换个说法" button
            Button(action: handleRegenerate) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                    Text("换个说法")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.vibrantOrange)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.9))
                .cornerRadius(22)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.vibrantOrange, lineWidth: 2)
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 25)
    }
    
    private func startAnswering() {
        isStreaming = true
        hasAnswered = false
        currentAnswer = ""
        
        Task {
            do {
                let stream = aiManager.askQuestion(
                    question: question,
                    targetAge: targetAge,
                    language: "zh-CN"
                )
                
                for try await chunk in stream {
                    await MainActor.run {
                        currentAnswer += chunk
                    }
                }
                
                await MainActor.run {
                    isStreaming = false
                    hasAnswered = true
                    
                    // 🔄 新增：自动保存聊天记录到本地和云端
                    Task {
                        await saveChatRecord()
                    }
                }
            } catch {
                await MainActor.run {
                    isStreaming = false
                    currentAnswer = "抱歉，答答现在有点累了，请稍后再试试吧！"
                    hasAnswered = true
                    
                    // 🔄 新增：即使出错也保存记录（用于分析）
                    Task {
                        await saveChatRecord()
                    }
                }
            }
        }
    }
    
    // 🔄 新增方法：保存聊天记录并同步到云端
    private func saveChatRecord() async {
        guard !question.isEmpty && !currentAnswer.isEmpty else { return }
        
        do {
            // 使用增强的DataManager创建聊天记录并自动同步到云端
            let chat = await dataManager.createChatWithSync(
                question: question,
                answer: currentAnswer,
                targetAge: targetAge,
                language: "zh-CN"
            )
            
            await MainActor.run {
                self.savedChat = chat
            }
            
            if Config.isDebug {
                print("✅ 聊天记录已保存并同步: \(question)")
            }
            
        } catch {
            print("❌ 保存聊天记录失败: \(error)")
            
            // 如果云端同步失败，至少保存到本地
            await MainActor.run {
                let localChat = dataManager.createChat(
                    question: question,
                    answer: currentAnswer,
                    targetAge: targetAge,
                    language: "zh-CN"
                )
                self.savedChat = localChat
            }
        }
    }
    
    private func handleUnderstood() {
        // 🔄 更新：添加用户反馈并同步
        if let chat = savedChat {
            dataManager.updateChatFeedback(chat, feedback: "liked")
            
            // 异步同步反馈到云端
            Task {
                await ChatService.shared.syncChatToCloud(chat)
            }
        }
        
        onDismiss()
    }
    
    private func handleRegenerate() {
        // 🔄 更新：标记原回答为需要重新生成
        if let chat = savedChat {
            dataManager.updateChatFeedback(chat, feedback: "regenerated")
            
            // 异步同步反馈到云端
            Task {
                await ChatService.shared.syncChatToCloud(chat)
            }
        }
        
        let previousAnswer = currentAnswer
        currentAnswer = ""
        isStreaming = true
        hasAnswered = false
        
        Task {
            do {
                let stream = aiManager.regenerateAnswer(
                    for: question,
                    targetAge: targetAge,
                    language: "zh-CN",
                    previousAnswer: previousAnswer
                )
                
                for try await chunk in stream {
                    await MainActor.run {
                        currentAnswer += chunk
                    }
                }
                
                await MainActor.run {
                    isStreaming = false
                    hasAnswered = true
                    
                    // 🔄 新增：保存重新生成的回答
                    Task {
                        await saveChatRecord()
                    }
                }
            } catch {
                await MainActor.run {
                    isStreaming = false
                    currentAnswer = "抱歉，答答现在有点累了，请稍后再试试吧！"
                    hasAnswered = true
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct ThinkingDotsView: View {
    @State private var animatingDots = [false, false, false]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.lightGray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animatingDots[index] ? 1.3 : 1.0)
                    .opacity(animatingDots[index] ? 0.4 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animatingDots[index]
                    )
            }
        }
        .onAppear {
            for i in 0..<3 {
                withAnimation {
                    animatingDots[i] = true
                }
            }
        }
    }
}

#Preview {
    ChatView(
        question: "为什么天空是蓝色的？",
        targetAge: 5,
        onDismiss: {}
    )
}
