//
//  SplashView.swift
//  DadaKnows
//
//  启动页 - 展示品牌Logo和加载状态
//

import SwiftUI

struct SplashView: View {
    @State private var isLoading = true
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    
    var onLoadingComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            Color.creamYellow
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Logo area
                VStack(spacing: 20) {
                    // Logo placeholder - 可以替换为实际的Logo图片
                    ZStack {
                        Circle()
                            .fill(Color.tenderYellow)
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.vibrantOrange)
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    
                    // App name
                    Text("问问答答")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.darkGray)
                        .opacity(logoOpacity)
                    
                    // Slogan
                    Text("陪娃有你，解答有我")
                        .font(.headline)
                        .foregroundColor(.lightGray)
                        .opacity(logoOpacity * 0.8)
                }
                
                Spacer()
                
                // Loading indicator
                if isLoading {
                    VStack(spacing: 15) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(CircularProgressViewStyle(tint: .vibrantOrange))
                        
                        Text("正在准备答答...")
                            .font(.subheadline)
                            .foregroundColor(.lightGray)
                    }
                    .opacity(logoOpacity)
                }
                
                Spacer().frame(height: 80)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Logo animation
        withAnimation(.easeOut(duration: 0.8)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Simulate loading process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isLoading = false
            }
            
            // Complete loading after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                onLoadingComplete()
            }
        }
    }
}

#Preview {
    SplashView {
        print("Loading complete")
    }
}
