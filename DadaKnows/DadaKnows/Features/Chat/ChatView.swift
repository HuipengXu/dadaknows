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
    
    @StateObject private var aiManager = AIManager.shared
    @State private var currentAnswer = ""
    @State private var isStreaming = false
    @State private var hasAnswered = false
    @State private var showRegenerateOption = false
    
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
                    .onChange(of: currentAnswer) { _ in
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
            
            Text("答答回答中...")
                .font(.headline)
                .foregroundColor(.darkGray)
            
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
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.tenderYellow)
                .frame(width: 35, height: 35)
                .overlay(
                    Image(systemName: "face.smiling")
                        .font(.system(size: 16))
                        .foregroundColor(.vibrantOrange)
                )
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ThinkingDotsView()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.9))
                .cornerRadius(18)
                
                Text("答答正在思考...")
                    .font(.caption)
                    .foregroundColor(.lightGray)
            }
            
            Spacer()
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
    
    private func handleUnderstood() {
        // TODO: Save chat to local storage
        // TODO: Update user statistics
        onDismiss()
    }
    
    private func handleRegenerate() {
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
            ForEach(0..<3) { index in
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
                animatingDots[i] = true
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
