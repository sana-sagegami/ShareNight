import SwiftUI

/// ワークスペース参加画面（アプリの起動画面）
/// 既存のワークスペースへの参加または新規作成を行う
struct WorkspaceJoinView: View {
    // MARK: - Properties
    
    @StateObject private var viewModel = WorkspaceViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    /// 選択されたワークスペース
    @State private var selectedWorkspace: Workspace?
    
    /// ニックネーム入力モーダルの表示フラグ
    @State private var showNicknameInput = false
    
    /// 入力されたニックネーム
    @State private var nickname = ""
    
    /// ワークスペース作成画面への遷移フラグ
    @State private var showCreateView = false
    
    /// ワークスペース詳細画面への遷移フラグ
    @State private var navigateToWorkspace = false
    
    /// 遷移先のワークスペースID
    @State private var targetWorkspaceId: String?
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // ヘッダー：アプリタイトル
                headerView
                
                // 検索セクション
                searchSection
                
                // 候補リスト
                candidatesSection
                
                Spacer()
                
                // 新規作成ボタン
                createButton
            }
            .padding()
            .navigationTitle("ShareNight")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showNicknameInput) {
                // ニックネーム入力モーダル
                nicknameInputSheet
            }
            .sheet(isPresented: $showCreateView) {
                // ワークスペース作成画面
                WorkspaceCreateView()
            }
            .navigationDestination(isPresented: $navigateToWorkspace) {
                // ワークスペース詳細画面への遷移
                if let workspaceId = targetWorkspaceId,
                   let userId = authViewModel.userId {
                    WorkspaceDetailView(workspaceId: workspaceId, userId: userId)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    /// ヘッダー：アプリタイトルとロゴ
    private var headerView: some View {
        VStack(spacing: 10) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("ShareNight")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("深夜。あなたの隣にも、まだ頑張ってる誰かがいる。")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 20)
    }
    
    /// 検索セクション
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ワークスペースを検索")
                .font(.headline)
            
            // 検索入力欄
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("タイトルを入力して検索", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                
                // クリアボタン
                if !viewModel.searchQuery.isEmpty {
                    Button(action: {
                        viewModel.searchQuery = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    /// 候補リスト
    private var candidatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.searchQuery.isEmpty {
                Text("検索結果")
                    .font(.headline)
                
                if viewModel.filteredWorkspaces.isEmpty {
                    // 候補が0件の場合
                    Text("該当するワークスペースがありません")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                } else {
                    // 候補リスト表示
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.filteredWorkspaces) { workspace in
                                workspaceCard(workspace)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
            }
        }
    }
    
    /// ワークスペースカード
    private func workspaceCard(_ workspace: Workspace) -> some View {
        Button(action: {
            selectedWorkspace = workspace
            showNicknameInput = true
        }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(workspace.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(workspace.dueDateDisplayString())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    /// 新規作成ボタン
    private var createButton: some View {
        Button(action: {
            showCreateView = true
        }) {
            Label("新規ワークスペース作成", systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding(.bottom)
    }
    
    /// ニックネーム入力モーダル
    private var nicknameInputSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("ニックネームを入力")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("このワークスペースで表示される名前です")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // ニックネーム入力欄
                TextField("ニックネーム", text: $nickname)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                // 文字数制限表示
                Text("\(nickname.count) / 20")
                    .font(.caption)
                    .foregroundColor(nickname.count > 20 ? .red : .secondary)
                
                Spacer()
                
                // 参加ボタン
                Button(action: {
                    joinWorkspace()
                }) {
                    Text("参加する")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isNicknameValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!isNicknameValid)
                .padding()
            }
            .padding()
            .navigationBarItems(trailing: Button("キャンセル") {
                showNicknameInput = false
                nickname = ""
            })
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Computed Properties
    
    /// ニックネームが有効かどうか
    private var isNicknameValid: Bool {
        !nickname.isEmpty && nickname.count <= 20
    }
    
    // MARK: - Methods
    
    /// ワークスペースに参加
    private func joinWorkspace() {
        guard let workspace = selectedWorkspace,
              let workspaceId = workspace.id,
              let userId = authViewModel.userId else {
            return
        }
        
        // ViewModelを使って参加処理
        let detailViewModel = WorkspaceDetailViewModel(workspaceId: workspaceId, userId: userId)
        detailViewModel.joinWorkspace(nickname: nickname) { success in
            if success {
                // 参加成功：ワークスペース詳細画面へ遷移
                targetWorkspaceId = workspaceId
                showNicknameInput = false
                nickname = ""
                navigateToWorkspace = true
            } else {
                // 参加失敗：エラー表示
                // TODO: エラーアラート表示
                print("ワークスペースへの参加に失敗しました")
            }
        }
    }
}
