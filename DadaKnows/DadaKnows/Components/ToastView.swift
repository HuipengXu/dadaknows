//
//  ToastView.swift
//  DadaKnows
//
//  Created by Assistant on 2025/11/21.
//

import SwiftUI

enum ToastType {
    case success
    case error
    case info
    
    var color: Color {
        switch self {
        case .success: return Color.green
        case .error: return Color.red
        case .info: return Color.blue
        }
    }
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

struct ToastView: View {
    let type: ToastType
    let message: String
    let onCancel: () -> Void
    
    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: type.icon)
                    .foregroundColor(.white)
                    .font(.system(size: 20))
                    .padding(.top, 2)
                
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: 16))
                }
            }
            .padding()
            .background(type.color.opacity(0.95))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 16)
            .padding(.top, 8) // Safe area padding handled by parent or geometry
            
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .zIndex(1000)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var message: String?
    let type: ToastType
    let duration: TimeInterval
    
    @State private var workItem: DispatchWorkItem?
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
                .zIndex(0)
            
            if let msg = message {
                ToastView(type: type, message: msg) {
                    dismissToast()
                }
                .onAppear {
                    if duration > 0 {
                        scheduleDismiss()
                    }
                }
                .onChange(of: message) {
                    if message != nil && duration > 0 {
                        scheduleDismiss()
                    }
                }
            }
        }
    }
    
    private func scheduleDismiss() {
        workItem?.cancel()
        
        let task = DispatchWorkItem {
            dismissToast()
        }
        
        workItem = task
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
    }
    
    private func dismissToast() {
        withAnimation(.spring()) {
            message = nil
        }
        workItem?.cancel()
        workItem = nil
    }
}

extension View {
    func toast(message: Binding<String?>, type: ToastType = .info, duration: TimeInterval = 3.0) -> some View {
        self.modifier(ToastModifier(message: message, type: type, duration: duration))
    }
}

#Preview {
    VStack {
        Text("Toast Preview")
    }
    .toast(message: .constant("这是一个测试消息，可能会很长很长，需要换行显示。"), type: .error, duration: 0)
}
