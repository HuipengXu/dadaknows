//
//  LoadingView.swift
//  DadaKnows
//
//  通用加载组件
//

import SwiftUI

struct LoadingView: View {
    let message: String
    @State private var rotationAngle: Double = 0
    
    init(message: String = "加载中...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Custom loading animation
            ZStack {
                Circle()
                    .stroke(Color.vibrantOrange.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.vibrantOrange, lineWidth: 4)
                    .frame(width: 50, height: 50)
                    .rotationEffect(Angle(degrees: rotationAngle))
            }
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.lightGray)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

#Preview {
    ZStack {
        Color.creamYellow
        LoadingView()
    }
}
