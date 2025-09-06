//
//  ContentView.swift
//  DadaKnows
//
//  Created by xuhuipeng on 2025/9/5.
//
//  备用内容视图 - 当前应用使用 MainTabView 作为主界面
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "questionmark.bubble.fill")
                .font(.system(size: 60))
                .foregroundColor(.vibrantOrange)
            
            Text("问问答答")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primaryText)
            
            Text("陪娃有你，解答有我")
                .font(.headline)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }
}

#Preview {
    ContentView()
}
