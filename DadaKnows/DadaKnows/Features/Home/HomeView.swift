//
//  HomeView.swift
//  DadaKnows
//
//  首页 - 核心提问界面
//

import SwiftUI

struct HomeView: View {
    @StateObject private var aiManager = AIManager.shared
    @State private var question = ""
    @State private var selectedAge = 5
    @State private var isAsking = false
    @State private var showChat = false
    
    let ageRanges = [
        (2, "2-3岁"),
        (4, "4-5岁"),
        (6, "6-7岁"),
        (8, "8-9岁"),
        (10, "10-12岁")
    ]
    
    var body: some View {
        ZStack {
            Color.creamYellow
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header area with IP character
                headerSection
                
                // Main content area
                mainContentSection
                
                Spacer()
            }
        }
        .overlay(
            // Voice recording overlay
            VoiceRecordingOverlay()
        )
        .overlay(
            // Network status banner
            NetworkStatusBanner(),
            alignment: .top
        )
        .fullScreenCover(isPresented: $showChat) {
            ChatView(
                question: question,
                targetAge: selectedAge,
                onDismiss: {
                    showChat = false
                    question = ""
                }
            )
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // IP Character area - 答答形象
            ZStack {
                // Background circle
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.tenderYellow.opacity(0.3),
                                Color.tenderYellow.opacity(0.1)
                            ]),
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                
                // IP Character placeholder
                FloatingView(amplitude: 8, frequency: 3.0) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.tenderYellow)
                                .frame(width: 80, height: 80)
                            
                            BounceView(trigger: isAsking) {
                                Image(systemName: "face.smiling")
                                    .font(.system(size: 35))
                                    .foregroundColor(.vibrantOrange)
                            }
                        }
                        
                        Text("答答")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.darkGray)
                        
                        // 离线状态指示器
                        OfflineIndicator()
                    }
                }
            }
            .padding(.top, 40)
        }
    }
    
    private var mainContentSection: some View {
        VStack(spacing: 30) {
            // Question input section
            SlideInView(from: .bottom, delay: 0.3) {
                VStack(spacing: 20) {
                    Text("想问答答什么问题呢？")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.darkGray)
                        .multilineTextAlignment(.center)
                    
                    // Question input field with voice support
                    VStack(spacing: 0) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.9))
                                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
                            
                            HStack {
                                TextField("ask_question_placeholder", text: $question, axis: .vertical)
                                    .lineLimit(3...6)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .font(.system(size: 16))
                                    .foregroundColor(.darkGray)
                                
                                VoiceInputButton(text: $question)
                                    .padding(.trailing, 15)
                            }
                        }
                        .frame(minHeight: 60)
                        .padding(.horizontal, 25)
                    }
                }
            }
            
            // Age selector
            ageSelector
            
            // Ask button
            askButton
        }
        .padding(.top, 30)
    }
    
    private var ageSelector: some View {
        VStack(spacing: 15) {
            Text("为几岁的小朋友回答？")
                .font(.headline)
                .foregroundColor(.darkGray)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(ageRanges, id: \.0) { age, ageText in
                        Button(action: {
                            selectedAge = age
                        }) {
                            VStack(spacing: 8) {
                                // Avatar circle
                                ZStack {
                                    Circle()
                                        .fill(selectedAge == age ? Color.vibrantOrange : Color.skyBlue.opacity(0.6))
                                        .frame(width: 50, height: 50)
                                    
                                    Text("\(age)")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                
                                Text(ageText)
                                    .font(.caption)
                                    .foregroundColor(selectedAge == age ? .vibrantOrange : .lightGray)
                            }
                        }
                        .scaleEffect(selectedAge == age ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: selectedAge)
                    }
                }
                .padding(.horizontal, 25)
            }
        }
    }
    
    private var askButton: some View {
        Button(action: askQuestion) {
            HStack(spacing: 10) {
                if isAsking {
                    ProgressView()
                        .scaleEffect(0.9)
                        .foregroundColor(.white)
                }
                
                Text(isAsking ? "答答正在思考..." : "问问答答")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .background(
                RoundedRectangle(cornerRadius: 27.5)
                    .fill(
                        isFormValid ? Color.vibrantOrange : Color.lightGray.opacity(0.5)
                    )
            )
            .scaleEffect(isAsking ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isAsking)
        }
        .disabled(!isFormValid || isAsking)
        .padding(.horizontal, 25)
        .padding(.top, 10)
    }
    
    private var isFormValid: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func askQuestion() {
        guard isFormValid else { return }
        
        isAsking = true
        
        // Simulate brief thinking animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isAsking = false
            showChat = true
        }
    }
}

#Preview {
    HomeView()
}
