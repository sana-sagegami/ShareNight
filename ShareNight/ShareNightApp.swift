import SwiftUI
import Firebase

/// ShareNightアプリケーションのエントリーポイント
/// Firebase初期化と認証状態管理を担当
@main
struct ShareNightApp: App {
    // アプリ起動時にFirebaseを初期化
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AuthViewModel())
        }
    }
}

/// アプリケーションのルートビュー
/// 認証状態に応じて適切な画面を表示
struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                // 認証済み: ワークスペース参加画面を表示
                WorkspaceJoinView()
            } else {
                // 認証中: ローディング表示
                ProgressView("認証中...")
                    .font(.headline)
            }
        }
        .onAppear {
            // アプリ起動時に匿名認証を実行
            authViewModel.signInAnonymously()
        }
    }
}
