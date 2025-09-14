//
//  HomeView.swift
//  DadaKnows
//
//  iOS原生风格的首页 - 核心提问界面
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
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Main content in scroll view
                    ScrollView {
                        VStack(spacing: 32) {
                            // Welcome section
                            welcomeSection
                            
                            // Question input section
                            questionInputSection
                            
                            // Age selector section
                            ageSelectionSection
                            
                            // Ask button
                            askButtonSection
                            
                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
                .background(Color.backgroundPrimary)
            }
        }
        .fullScreenCover(isPresented: $showChat) {
            ChatView(
                question: question,
                targetAge: selectedAge,
                onDismiss: {
                    showChat = false
                    question = ""
                },
                historicalSession: nil
            )
        }
    }
    
    // MARK: - Welcome Section
    private var welcomeSection: some View {
        VStack(spacing: 16) {
            // App icon or character
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.appPrimary)
            }
            
            VStack(spacing: 8) {
                Text("你好，我是答答")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Text("有什么想问的吗？")
                    .font(.body)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Question Input Section
    private var questionInputSection: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 12) {
                TextField("输入你的问题...", text: $question, axis: .vertical)
                    .font(.body)
                    .lineLimit(5...8)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                
                // Voice input button in the bottom right of text field
                VStack {
                    Spacer()
                    VoiceInputButton(text: $question)
                        .padding(.trailing, 10)
                        .padding(.bottom, 10)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.fillSecondary)
                    .stroke(Color.separator.opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .padding(20)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Age Selection Section
    private var ageSelectionSection: some View {
        VStack(spacing: 16) {
            Text("宝贝多大啦")
                .font(.headline)
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // iOS native picker style
            Picker("选择年龄", selection: $selectedAge) {
                ForEach(ageRanges, id: \.0) { age, ageText in
                    Text(ageText).tag(age)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(20)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Ask Button Section
    private var askButtonSection: some View {
        Button(action: askQuestion) {
            HStack(spacing: 12) {
                if isAsking {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                Text(isAsking ? "正在思考..." : "问问答答")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(isFormValid ? .white : .textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isFormValid ? Color.appPrimary : Color.fillSecondary)
                    .stroke(isFormValid ? Color.clear : Color.separator.opacity(0.5), lineWidth: 0.5)
            )
        }
        .disabled(!isFormValid || isAsking)
        .buttonStyle(.plain)
        .opacity(isFormValid ? 1.0 : 0.8)
        .animation(.easeInOut(duration: 0.2), value: isAsking)
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
