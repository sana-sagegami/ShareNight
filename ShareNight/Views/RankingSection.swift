import SwiftUI
import PhotosUI

/// ランキングセクションのビュー
/// スクリーンショット投稿とランキング表示を行う
struct RankingSection: View {
    // MARK: - Properties
    
    @ObservedObject var viewModel: ScreenshotViewModel
    
    /// 自分のニックネーム
    let myNickname: String
    
    /// 画像選択用
    @State private var selectedItem: PhotosPickerItem?
    
    /// 選択された画像
    @State private var selectedImage: UIImage?
    
    /// コメント入力
    @State private var comment: String = ""
    
    /// 投稿モーダル表示フラグ
    @State private var showUploadSheet = false
    
    /// ランキング詳細画面への遷移
    @State private var selectedScreenshot: Screenshot?
    
    /// ドラッグ中のアイテム
    @State private var draggingItem: Screenshot?
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 16) {
            // セクションヘッダー
            sectionHeader
            
            if viewModel.myScreenshot == nil {
                // 未投稿：投稿ボタン表示
                uploadButton
            } else {
                // 投稿済み：自分の投稿表示
                myScreenshotCard
            }
            
            // ランキングリスト
            if !viewModel.screenshots.isEmpty {
                rankingList
            } else {
                emptyView
            }
        }
        .sheet(isPresented: $showUploadSheet) {
            // 投稿モーダル
            uploadSheet
        }
        .sheet(item: $selectedScreenshot) { screenshot in
            // ランキング詳細画面
            ScreenshotDetailView(
                screenshot: screenshot,
                viewModel: viewModel
            )
        }
        .onChange(of: selectedItem) { _, newValue in
            // 画像選択時の処理
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = uiImage
                    showUploadSheet = true
                }
            }
        }
    }
    
    // MARK: - View Components
    
    /// セクションヘッダー
    private var sectionHeader: some View {
        HStack {
            Text("みんなの頑張り")
                .font(.headline)
            
            Spacer()
            
            Text("\(viewModel.screenshots.count)件")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    /// 投稿ボタン
    private var uploadButton: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                
                Text("スクリーンショットを投稿")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(10)
        }
    }
    
    /// 自分の投稿カード
    private var myScreenshotCard: some View {
        Group {
            if let myScreenshot = viewModel.myScreenshot {
                VStack(alignment: .leading, spacing: 8) {
                    Text("あなたの投稿")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    screenshotCard(myScreenshot, rank: getCurrentRank(of: myScreenshot))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                    
                    // 削除ボタン
                    Button(action: {
                        deleteMyScreenshot()
                    }) {
                        Label("投稿を削除", systemImage: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    /// ランキングリスト
    private var rankingList: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.screenshots) { screenshot in
                let rank = getCurrentRank(of: screenshot)
                
                screenshotCard(screenshot, rank: rank)
                    .onDrag {
                        // ドラッグ開始
                        self.draggingItem = screenshot
                        return NSItemProvider(object: screenshot.id! as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: ScreenshotDropDelegate(
                            screenshot: screenshot,
                            screenshots: $viewModel.screenshots,
                            draggingItem: $draggingItem,
                            onReorder: { newOrder in
                                updateRanking(newOrder: newOrder)
                            }
                        )
                    )
                    .opacity(draggingItem?.id == screenshot.id ? 0.5 : 1.0)
            }
        }
    }
    
    /// 空の状態ビュー
    private var emptyView: some View {
        Text("まだ投稿がありません")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding()
            .frame(maxWidth: .infinity)
    }
    
    /// スクリーンショットカード
    private func screenshotCard(_ screenshot: Screenshot, rank: Int) -> some View {
        Button(action: {
            selectedScreenshot = screenshot
        }) {
            HStack(spacing: 12) {
                // 順位バッジ
                Text("#\(rank)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(rankColor(rank))
                    .clipShape(Circle())
                
                // サムネイル画像
                AsyncImage(url: URL(string: screenshot.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // 情報
                VStack(alignment: .leading, spacing: 4) {
                    Text(screenshot.nickname)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let comment = screenshot.comment {
                        Text(comment)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // ドラッグアイコン
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    /// 投稿モーダル
    private var uploadSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let image = selectedImage {
                    // 選択された画像のプレビュー
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // コメント入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text("コメント（任意）")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("コメントを入力...", text: $comment)
                            .textFieldStyle(.roundedBorder)
                        
                        Text("\(comment.count) / 50")
                            .font(.caption2)
                            .foregroundColor(comment.count > 50 ? .red : .secondary)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // アップロード進捗
                    if viewModel.isUploading {
                        VStack(spacing: 8) {
                            ProgressView(value: viewModel.uploadProgress)
                                .progressViewStyle(.linear)
                            
                            Text(String(format: "%.0f%%", viewModel.uploadProgress * 100))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    // 投稿ボタン
                    Button(action: {
                        uploadScreenshot(image: image)
                    }) {
                        Text(viewModel.isUploading ? "アップロード中..." : "投稿する")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isUploadValid ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!isUploadValid || viewModel.isUploading)
                    .padding()
                }
            }
            .padding()
            .navigationTitle("スクリーンショット投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        showUploadSheet = false
                        resetUploadState()
                    }
                    .disabled(viewModel.isUploading)
                }
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Computed Properties
    
    /// アップロードが有効かどうか
    private var isUploadValid: Bool {
        selectedImage != nil &&
        (comment.isEmpty || comment.count <= 50)
    }
    
    // MARK: - Methods
    
    /// 現在のランキング順位を取得
    private func getCurrentRank(of screenshot: Screenshot) -> Int {
        if let index = viewModel.screenshots.firstIndex(where: { $0.id == screenshot.id }) {
            return index + 1
        }
        return 0
    }
    
    /// 順位に応じた色を取得
    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
    
    /// スクリーンショットをアップロード
    private func uploadScreenshot(image: UIImage) {
        viewModel.uploadScreenshot(
            image: image,
            nickname: myNickname,
            comment: comment.isEmpty ? nil : comment
        ) { success in
            if success {
                showUploadSheet = false
                resetUploadState()
            }
        }
    }
    
    /// アップロード状態をリセット
    private func resetUploadState() {
        selectedItem = nil
        selectedImage = nil
        comment = ""
    }
    
    /// 自分のスクリーンショットを削除
    private func deleteMyScreenshot() {
        viewModel.deleteMyScreenshot { success in
            if success {
                // 削除成功
                print("スクリーンショットを削除しました")
            } else {
                // 削除失敗
                print("削除に失敗しました")
            }
        }
    }
    
    /// ランキングを更新
    private func updateRanking(newOrder: [Screenshot]) {
        viewModel.updateRanking(screenshots: newOrder) { success in
            if !success {
                print("ランキングの更新に失敗しました")
            }
        }
    }
}

// MARK: - ScreenshotDropDelegate

/// ドラッグ&ドロップの処理を管理するDelegate
struct ScreenshotDropDelegate: DropDelegate {
    let screenshot: Screenshot
    @Binding var screenshots: [Screenshot]
    @Binding var draggingItem: Screenshot?
    let onReorder: ([Screenshot]) -> Void
    
    /// ドロップ可能かどうか
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              draggingItem.id != screenshot.id,
              let fromIndex = screenshots.firstIndex(where: { $0.id == draggingItem.id }),
              let toIndex = screenshots.firstIndex(where: { $0.id == screenshot.id }) else {
            return
        }
        
        // 順序を入れ替え（アニメーション付き）
        withAnimation {
            screenshots.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
    
    /// ドロップ実行時
    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        
        // 新しい順序をFirestoreに保存
        onReorder(screenshots)
        
        return true
    }
}
