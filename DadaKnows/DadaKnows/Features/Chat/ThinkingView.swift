//
//  ThinkingView.swift
//  DadaKnows
//
//  Created by DadaKnows on 2025/11/22.
//

import SwiftUI

struct ThinkingView: View {
    let content: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain")
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
                .symbolEffect(.pulse, options: .repeating)
            
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(content)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Spacer(minLength: 0)
                            .id("bottom")
                    }
                }
                .frame(maxWidth: .infinity) 
                .onChange(of: content) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.backgroundSecondary.opacity(0.5))
        .cornerRadius(8)
        .frame(height: 36)
    }
}

#Preview {
    ThinkingView(content: "Thinking process... Analyzing request... Generating response...")
        .padding()
        .background(Color.backgroundPrimary)
}
