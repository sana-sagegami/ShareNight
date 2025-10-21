import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit
import PhotosUI
import SwiftUI

/// スクリーンショットの投稿・ランキング管理を行うViewModel
class ScreenshotViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// スクリーンショットリスト（ランキング順）
    @Published var screenshots: [Screenshot] = []
    
    /// 自分の投稿
    @Published var myScreenshot: Screenshot?
    
    /// アップロード中フラグ
    @Published var isUploading: Bool = false
    
    /// アップロード進捗（0.0〜1.0）
    @Published var uploadProgress: Double = 0.0
    
    /// エラーメッセージ
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    /// Firestoreインスタンス
    private let db = Firestore.firestore()
    
    /// Firebase Storageインスタンス
    private let storage = Storage.storage()
    
    /// ワークスペースID
    private let workspaceId: String
    
    /// 現在のユーザーID
    private let userId: String
    
    /// リアルタイムリスナー
    private var listener: ListenerRegistration?
    
    // MARK: - Constants
    
    /// 最大ファイルサイズ（10MB）
    private let maxFileSize: Int64 = 10 * 1024 * 1024
    
    // MARK: - Initialization
    
    init(workspaceId: String, userId: String) {
        self.workspaceId = workspaceId
        self.userId = userId
        
        // スクリーンショットをリアルタイム監視
        setupScreenshotsListener()
    }
    
    deinit {
        // リスナーを解除してメモリリークを防ぐ
        listener?.remove()
    }
    
    // MARK: - Public Methods
    
    /// スクリーンショットを投稿
    /// - Parameters:
    ///   - image: 投稿する画像
    ///   - nickname: 投稿者のニックネーム
    ///   - comment: 任意コメント（50文字以内）
    ///   - completion: 完了時のコールバック
    func uploadScreenshot(
        image: UIImage,
        nickname: String,
        comment: String?,
        completion: @escaping (Bool) -> Void
    ) {
        // 画像をJPEG形式に変換（圧縮率 0.8）
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "画像の変換に失敗しました"
            completion(false)
            return
        }
        
        // ファイルサイズチェック
        let fileSize = Int64(imageData.count)
        if fileSize > maxFileSize {
            let sizeMB = Double(fileSize) / 1024.0 / 1024.0
            errorMessage = String(format: "ファイルサイズが大きすぎます（%.1fMB / 10MB）", sizeMB)
            completion(false)
            return
        }
        
        // コメント文字数チェック
        if let comment = comment, comment.count > 50 {
            errorMessage = "コメントは50文字以内にしてください"
            completion(false)
            return
        }
        
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
        // Storageへのパス
        let storageRef = storage.reference()
            .child("workspaces")
            .child(workspaceId)
            .child("screenshots")
            .child("\(userId).jpg")
        
        // メタデータ設定
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // アップロード
        let uploadTask = storageRef.putData(imageData, metadata: metadata)
        
        // アップロード進捗を監視
        uploadTask.observe(.progress) { [weak self] snapshot in
            guard let self = self,
                  let progress = snapshot.progress else { return }
            
            self.uploadProgress = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
        }
        
        // アップロード完了を監視
        uploadTask.observe(.success) { [weak self] snapshot in
            guard let self = self else { return }
            
            // ダウンロードURLを取得
            storageRef.downloadURL { url, error in
                if let error = error {
                    self.errorMessage = "URLの取得に失敗しました: \(error.localizedDescription)"
                    self.isUploading = false
                    completion(false)
                    return
                }
                
                guard let downloadURL = url else {
                    self.errorMessage = "URLの取得に失敗しました"
                    self.isUploading = false
                    completion(false)
                    return
                }
                
                // Firestoreにスクリーンショット情報を保存
                self.saveScreenshotToFirestore(
                    imageUrl: downloadURL.absoluteString,
                    nickname: nickname,
                    comment: comment,
                    completion: completion
                )
            }
        }
        
        // アップロード失敗を監視
        uploadTask.observe(.failure) { [weak self] snapshot in
            guard let self = self else { return }
            
            if let error = snapshot.error {
                self.errorMessage = "アップロードに失敗しました: \(error.localizedDescription)"
            } else {
                self.errorMessage = "アップロードに失敗しました"
            }
            
            self.isUploading = false
            completion(false)
        }
    }
    
    /// ランキング順位を更新
    /// - Parameters:
    ///   - screenshots: 新しい順位のスクリーンショットリスト
    ///   - completion: 完了時のコールバック
    func updateRanking(screenshots: [Screenshot], completion: @escaping (Bool) -> Void) {
        let batch = db.batch()
        
        // 各スクリーンショットのrankを更新
        for (index, screenshot) in screenshots.enumerated() {
            guard let screenshotId = screenshot.id else { continue }
            
            let ref = db.collection("workspaces")
                .document(workspaceId)
                .collection("screenshots")
                .document(screenshotId)
            
            batch.updateData(["rank": index + 1], forDocument: ref)
        }
        
        // バッチ実行
        batch.commit { error in
            if let error = error {
                print("ランキング更新エラー: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    /// 自分のスクリーンショットを削除
    /// - Parameter completion: 完了時のコールバック
    func deleteMyScreenshot(completion: @escaping (Bool) -> Void) {
        guard myScreenshot != nil else {
            completion(false)
            return
        }
        
        // Storageから画像を削除
        let storageRef = storage.reference()
            .child("workspaces")
            .child(workspaceId)
            .child("screenshots")
            .child("\(userId).jpg")
        
        storageRef.delete { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("Storage削除エラー: \(error.localizedDescription)")
                // エラーでも続行（Firestoreは削除）
            }
            
            // Firestoreからドキュメントを削除
            self.db.collection("workspaces")
                .document(self.workspaceId)
                .collection("screenshots")
                .document(self.userId)
                .delete { error in
                    if let error = error {
                        print("Firestore削除エラー: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        completion(true)
                    }
                }
        }
    }
    
    // MARK: - Private Methods
    
    /// スクリーンショットリストをリアルタイム監視
    private func setupScreenshotsListener() {
        listener = db.collection("workspaces")
            .document(workspaceId)
            .collection("screenshots")
            .order(by: "rank", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = "スクリーンショットの取得に失敗しました: \(error.localizedDescription)"
                    return
                }
                
                // スクリーンショットリストを更新
                self.screenshots = snapshot?.documents.compactMap { document in
                    try? document.data(as: Screenshot.self)
                } ?? []
                
                // 自分の投稿を取得
                self.myScreenshot = self.screenshots.first { $0.id == self.userId }
            }
    }
    
    /// Firestoreにスクリーンショット情報を保存
    private func saveScreenshotToFirestore(
        imageUrl: String,
        nickname: String,
        comment: String?,
        completion: @escaping (Bool) -> Void
    ) {
        // 新規投稿の順位を決定（既存の最大rank + 1）
        let newRank = (screenshots.map { $0.rank }.max() ?? 0) + 1
        
        let screenshot = Screenshot(
            id: userId,
            imageUrl: imageUrl,
            nickname: nickname,
            rank: newRank,
            comment: comment,
            uploadedAt: Date()
        )
        
        do {
            try db.collection("workspaces")
                .document(workspaceId)
                .collection("screenshots")
                .document(userId)
                .setData(from: screenshot) { [weak self] error in
                    guard let self = self else { return }
                    
                    self.isUploading = false
                    
                    if let error = error {
                        self.errorMessage = "保存に失敗しました: \(error.localizedDescription)"
                        completion(false)
                    } else {
                        completion(true)
                    }
                }
        } catch {
            self.isUploading = false
            self.errorMessage = "保存に失敗しました: \(error.localizedDescription)"
            completion(false)
        }
    }
}
