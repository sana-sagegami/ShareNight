import SwiftUI

/// ワークスペース詳細画面（メイン画面）
/// 進捗管理、ランキング、コメントを統合表示
struct WorkspaceDetailView: View {
    // MARK: - Properties
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: WorkspaceDetailViewModel
    @StateObject private var screenshotViewModel: ScreenshotViewModel
    
    /// コメント入力テキスト
    @State private var commentText = ""
    
    /// コメント投稿中フラグ
    @State private var isPostingComment = false
    
    // MARK: - Initialization
    
    init(workspaceId: String, userId: String) {
        _viewModel = StateObject(wrappedValue: WorkspaceDetailViewModel(
            workspaceId: workspaceId,
            userId: userId
        ))
        _screenshotViewModel = StateObject(wrappedValue: ScreenshotViewModel(
            workspaceId: workspaceId,
            userId: userId
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ヘッダーエリア
                headerSection
                
                // 進捗エリア
                progressSection
                
                // ランキングセクション（Phase 2）
                if let nickname = viewModel.myParticipant?.nickname {
                    RankingSection(
                        viewModel: screenshotViewModel,
                        myNickname: nickname
                    )
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                }
                
                // コメントセクション
                commentSection
            }
            .padding()
        }
        .navigationTitle(viewModel.workspace?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("退出") {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - View Components
    
    /// ヘッダーセクション（提出日表示）
    private var headerSection: some View {
        Group {
            if let workspace = viewModel.workspace {
                VStack(spacing: 8) {
                    // 提出日表示
                    if workspace.isDueDateToday {
                        // 提出日当日：警告表示
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(workspace.dueDateDisplayString())
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .cornerRadius(10)
                    } else {
                        // 通常時
                        Text(workspace.dueDateDisplayString())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                }
            }
        }
    }
    
    /// 進捗セクション
    private var progressSection: some View {
        VStack(spacing: 16) {
            // セクションタイトル
            HStack {
                Text("進捗状況")
                    .font(.headline)
                Spacer()
            }
            
            // 自分の進捗ステータス切り替えボタン
            myStatusButtons
            
            // 仲間の進捗集計表示
            progressSummaryView
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
    
    /// 自分の進捗ステータスボタン
    private var myStatusButtons: some View {
        HStack(spacing: 12) {
            ForEach(ParticipantStatus.allCases, id: \.self) { status in
                Button(action: {
                    viewModel.updateStatus(to: status)
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: status.icon)
                            .font(.title3)
                        
                        Text(status.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        viewModel.myParticipant?.status == status
                        ? Color.blue
                        : Color(.systemGray5)
                    )
                    .foregroundColor(
                        viewModel.myParticipant?.status == status
                        ? .white
                        : .primary
                    )
                    .cornerRadius(10)
                }
            }
        }
    }
    
    /// 進捗サマリー表示
    private var progressSummaryView: some View {
        HStack(spacing: 20) {
            // 未着手
            summaryItem(
                icon: ParticipantStatus.notStarted.icon,
                label: ParticipantStatus.notStarted.displayName,
                count: viewModel.progressSummary.notStartedCount,
                color: .gray
            )
            
            // 作業中
            summaryItem(
                icon: ParticipantStatus.inProgress.icon,
                label: ParticipantStatus.inProgress.displayName,
                count: viewModel.progressSummary.inProgressCount,
                color: .blue
            )
            
            // 完了
            summaryItem(
                icon: ParticipantStatus.completed.icon,
                label: ParticipantStatus.completed.displayName,
                count: viewModel.progressSummary.completedCount,
                color: .green
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
    
    /// 進捗サマリーの各項目
    private func summaryItem(icon: String, label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(count)人")
                .font(.headline)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    /// コメントセクション
    private var commentSection: some View {
        VStack(spacing: 16) {
            // セクションタイトル
            HStack {
                Text("コメント")
                    .font(.headline)
                
                Spacer()
                
                Text("\(viewModel.comments.count)件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // コメント入力欄
            commentInputView
            
            // コメントリスト
            if viewModel.comments.isEmpty {
                Text("まだコメントがありません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.comments) { comment in
                        commentCard(comment)
                    }
                }
            }
        }
    }
    
    /// コメント入力ビュー
    private var commentInputView: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // テキストフィールド
                TextField("コメントを入力...", text: $commentText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                // 投稿ボタン
                Button(action: {
                    postComment()
                }) {
                    if isPostingComment {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 44, height: 44)
                .background(isCommentValid ? Color.blue : Color.gray)
                .cornerRadius(10)
                .disabled(!isCommentValid || isPostingComment)
            }
            
            // 文字数カウント
            HStack {
                Spacer()
                Text("\(commentText.count) / 500")
                    .font(.caption2)
                    .foregroundColor(commentText.count > 500 ? .red : .secondary)
            }
        }
    }
    
    /// コメントカード
    private func commentCard(_ comment: Comment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // ヘッダー：ニックネームと投稿日時
            HStack {
                Text(comment.nickname)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(comment.relativeTimeString())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // コメント本文
            Text(comment.text)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Computed Properties
    
    /// コメントが有効かどうか
    private var isCommentValid: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        commentText.count <= 500
    }
    
    // MARK: - Methods
    
    /// コメントを投稿
    private func postComment() {
        isPostingComment = true
        
        viewModel.postComment(text: commentText) { success in
            isPostingComment = false
            
            if success {
                // 投稿成功：入力欄をクリア
                commentText = ""
                
                // キーボードを閉じる
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            } else {
                // 投稿失敗：エラー表示
                // TODO: エラーアラート表示
                print("コメントの投稿に失敗しました")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WorkspaceDetailView(
            workspaceId: "preview_workspace_id",
            userId: "preview_user_id"
        )
    }
}
