//
//  DLogoView.swift
//  DadaKnows
//
//  DadaKnows 品牌标识组件 - 可复用的D字母logo
//

import SwiftUI

struct DLogoView: View {
    let size: CGFloat
    let shadowEnabled: Bool

    init(size: CGFloat = 64, shadowEnabled: Bool = true) {
        self.size = size
        self.shadowEnabled = shadowEnabled
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .fill(Color.appPrimary)
                .frame(width: size, height: size)
                .if(shadowEnabled) { view in
                    view.shadow(color: Color.black.opacity(0.1), radius: size * 0.06, x: 0, y: size * 0.03)
                }

            Text("D")
                .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Convenience Sizes
extension DLogoView {
    static var small: DLogoView {
        DLogoView(size: 32)
    }

    static var medium: DLogoView {
        DLogoView(size: 64)
    }

    static var large: DLogoView {
        DLogoView(size: 100)
    }

    static var extraLarge: DLogoView {
        DLogoView(size: 120)
    }

    /// 创建响应式Logo，根据传入的尺寸自动调整
    static func responsive(size: CGFloat, shadowEnabled: Bool = true) -> DLogoView {
        DLogoView(size: size, shadowEnabled: shadowEnabled)
    }
}

// MARK: - Conditional View Modifier
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        DLogoView.small
        DLogoView.medium
        DLogoView.large
        DLogoView.extraLarge
        DLogoView(size: 80, shadowEnabled: false)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}