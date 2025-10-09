//
//  CustomButton.swift
//  DadaKnows
//
//  自定义按钮组件
//

import SwiftUI

struct CustomButton: View {
    let title: String
    let action: () -> Void
    let style: ButtonStyle
    let isLoading: Bool
    let isDisabled: Bool
    
    enum ButtonStyle {
        case primary
        case secondary
        case outline
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .vibrantOrange
            case .secondary: return .white.opacity(0.9)
            case .outline: return .clear
            }
        }
        
        var textColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .darkGray
            case .outline: return .vibrantOrange
            }
        }
        
        var borderColor: Color? {
            switch self {
            case .outline: return .vibrantOrange
            default: return nil
            }
        }
    }
    
    init(
        title: String,
        style: ButtonStyle = .primary,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(style.textColor)
                }
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(style.textColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(style.backgroundColor)
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(style.borderColor ?? Color.clear, lineWidth: 2)
            )
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .disabled(isDisabled || isLoading)
        .scaleEffect(isDisabled ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isDisabled)
    }
}

#Preview {
    VStack(spacing: 20) {
        CustomButton(title: "Primary Button") {
            print("Primary tapped")
        }
        
        CustomButton(title: "Loading", isLoading: true) {
            print("Loading tapped")
        }
        
        CustomButton(title: "Secondary", style: .secondary) {
            print("Secondary tapped")
        }
        
        CustomButton(title: "Outline", style: .outline) {
            print("Outline tapped")
        }
        
        CustomButton(title: "Disabled", isDisabled: true) {
            print("Disabled tapped")
        }
    }
    .padding()
    .background(Color.backgroundPrimary)
}
