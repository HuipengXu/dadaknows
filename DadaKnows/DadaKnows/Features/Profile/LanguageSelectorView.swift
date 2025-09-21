//
//  LanguageSelectorView.swift
//  DadaKnows
//
//  语言选择视图
//

import SwiftUI

struct LanguageSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    let onLanguageChanged: (String) -> Void
    
	@State private var selectedLanguage: String = {
		let list = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? Locale.preferredLanguages
		let first = list.first ?? "en"
		return normalizeLanguageCode(first)
	}()
    
    private let languages = [
        ("en", NSLocalizedString("english", comment: "")),
        ("zh-Hans", NSLocalizedString("中文（简体）", comment: ""))
    ]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(languages, id: \.0) { languageCode, displayName in
                    Button(action: {
                        selectedLanguage = languageCode
                        onLanguageChanged(languageCode)
                        dismiss()
                    }) {
                        HStack {
                            Text(displayName)
                                .foregroundColor(.textPrimary)
                            
                            Spacer()
                            
                            if selectedLanguage == languageCode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.appPrimary)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(NSLocalizedString("语言设置", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        dismiss()
                    }
                    .foregroundColor(.textSecondary)
                }
            }
        }
    }
}

#Preview {
    LanguageSelectorView { _ in }
}

// MARK: - Helpers
private func normalizeLanguageCode(_ code: String) -> String {
    let lowercased = code.lowercased()
    if lowercased.hasPrefix("zh") { return "zh-Hans" }
    return "en"
}
