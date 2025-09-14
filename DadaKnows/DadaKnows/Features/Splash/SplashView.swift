//
//  SplashView.swift
//  DadaKnows
//
//  启动页 - 展示品牌Logo和加载状态
//

import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var showProgressView = false
    
    var onLoadingComplete: () -> Void
    
    var body: some View {
        ZStack {
            // iOS native background
            Color.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo area - iOS native style
                VStack(spacing: 24) {
                    // App icon - iOS native style
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.appPrimary)
                            .frame(width: 120, height: 120)
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    
                    // App name - iOS native typography
                    Text("问问答答")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                        .opacity(logoOpacity)
                    
                    // Slogan - iOS native secondary text
                    Text("陪娃有你，解答有我")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.textSecondary)
                        .opacity(logoOpacity * 0.8)
                }
                
                Spacer()
                
                // Loading indicator - iOS native style
                VStack(spacing: 16) {
                    if showProgressView {
                        ProgressView()
                            .scaleEffect(1.0)
                            .progressViewStyle(CircularProgressViewStyle(tint: .appPrimary))
                            .transition(.opacity.combined(with: .scale))
                    }
                    
                    Text("正在准备...")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .opacity(showProgressView ? 1.0 : 0.0)
                }
                .animation(.easeInOut(duration: 0.3), value: showProgressView)
                
                Spacer().frame(height: 100)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Logo animation with iOS native timing
        withAnimation(.easeOut(duration: 0.6)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Show progress indicator after logo appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showProgressView = true
            }
        }
        
        // Complete loading with iOS native timing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            onLoadingComplete()
        }
    }
}

#Preview {
    SplashView {
        print("Loading complete")
    }
}
