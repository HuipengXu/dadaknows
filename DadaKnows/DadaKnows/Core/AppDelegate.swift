import SwiftUI
import GoogleSignIn
import Supabase

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        configureGoogleSignIn()
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Handle Google Sign-In
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        
        // Handle Supabase authentication
        if url.scheme == "dadaknows" && url.host == "auth" {
            Task {
                await handleSupabaseAuth(url: url)
            }
        }
        
        return true
    }
    
    private func configureGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("⚠️ GoogleService-Info.plist not found or CLIENT_ID missing")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }
    
    private func handleSupabaseAuth(url: URL) async {
        do {
            try await SupabaseClient.shared.supabase.auth.session(from: url)
            await MainActor.run {
                AppState.shared.signIn()
            }
            print("✅ 邮箱验证成功，用户已登录")
        } catch {
            print("❌ 处理邮箱验证失败: \(error.localizedDescription)")
        }
    }
}
