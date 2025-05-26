import Foundation
import StoreKit

// ゲーム管理クラス
class GameManager: NSObject {
    static let shared = GameManager()
    
    // ユーザーデフォルト用のキー
    private struct Keys {
        static let freePlayCount = "freePlayCount"
        static let isAdFree = "isAdFree"
        static let lastPlayDate = "lastPlayDate"
    }
    
    // 無料プレイ回数
    private let maxFreePlayCount = 30
    
    // 時間制限プレイ回数
    private let hourlyPlayLimit = 2
    
    // 時間制限用のキー
    private struct TimeKeys {
        static let hourlyPlayCount = "hourlyPlayCount"
        static let lastHourlyReset = "lastHourlyReset"
    }
    
    // 実績用のキー
    private struct AchievementKeys {
        static let totalStagesCleared = "totalStagesCleared"
        static let highestAchievement = "highestAchievement"
    }
    
    // 課金アイテムID
    private let unlimitedPlayProductID = "com.daiokawa.mamadoko.unlimited"
    
    // 課金管理
    private var purchasedProducts = Set<String>()
    private var productsRequest: SKProductsRequest?
    private var removeAdsProduct: SKProduct?
    
    // 購入完了ハンドラー
    var purchaseCompletionHandler: ((Bool, String?) -> Void)?
    
    override init() {
        super.init()
        
        // 購入済みアイテムの復元
        if UserDefaults.standard.bool(forKey: Keys.isAdFree) {
            purchasedProducts.insert(unlimitedPlayProductID)
        }
        
        // トランザクションオブザーバーの設定
        SKPaymentQueue.default().add(self)
        
        // 時間制限のリセットチェック
        checkHourlyReset()
    }
    
    // 残りの無料プレイ回数を取得
    func getRemainingFreePlayCount() -> Int {
        let usedCount = UserDefaults.standard.integer(forKey: Keys.freePlayCount)
        return max(0, maxFreePlayCount - usedCount)
    }
    
    // 今日の残りプレイ回数を取得（時間制限）
    func getRemainingHourlyPlays() -> Int {
        checkHourlyReset()
        let usedCount = UserDefaults.standard.integer(forKey: TimeKeys.hourlyPlayCount)
        return max(0, hourlyPlayLimit - usedCount)
    }
    
    // 時間制限のリセットチェック
    private func checkHourlyReset() {
        let lastReset = UserDefaults.standard.object(forKey: TimeKeys.lastHourlyReset) as? Date ?? Date.distantPast
        let now = Date()
        
        // 1時間経過していたらリセット
        if now.timeIntervalSince(lastReset) >= 3600 {
            UserDefaults.standard.set(0, forKey: TimeKeys.hourlyPlayCount)
            UserDefaults.standard.set(now, forKey: TimeKeys.lastHourlyReset)
        }
    }
    
    // プレイ回数を記録
    func recordPlay() {
        // 無制限プレイ購入済みの場合は記録しない
        if hasUnlimitedPlay() { return }
        
        // 無料プレイ期間中
        if getRemainingFreePlayCount() > 0 {
            var count = UserDefaults.standard.integer(forKey: Keys.freePlayCount)
            count += 1
            UserDefaults.standard.set(count, forKey: Keys.freePlayCount)
        } else {
            // 時間制限プレイ
            checkHourlyReset()
            var hourlyCount = UserDefaults.standard.integer(forKey: TimeKeys.hourlyPlayCount)
            hourlyCount += 1
            UserDefaults.standard.set(hourlyCount, forKey: TimeKeys.hourlyPlayCount)
        }
        
        // 最終プレイ日時を記録
        UserDefaults.standard.set(Date(), forKey: Keys.lastPlayDate)
    }
    
    // 実績記録
    func recordStageCleared() {
        var total = UserDefaults.standard.integer(forKey: AchievementKeys.totalStagesCleared)
        total += 1
        UserDefaults.standard.set(total, forKey: AchievementKeys.totalStagesCleared)
        
        // 実績レベルを更新
        updateAchievementLevel(total)
    }
    
    // 実績レベルを更新
    private func updateAchievementLevel(_ stagesCleared: Int) {
        let newLevel: String
        
        switch stagesCleared {
        case 85...:
            newLevel = "diamond"
        case 55...84:
            newLevel = "platinum"
        case 40...54:
            newLevel = "golden"
        case 30...39:
            newLevel = "silver"
        case 10...29:
            newLevel = "bronze"
        default:
            newLevel = "none"
        }
        
        UserDefaults.standard.set(newLevel, forKey: AchievementKeys.highestAchievement)
    }
    
    // 現在の実績レベルを取得
    func getCurrentAchievementLevel() -> String {
        return UserDefaults.standard.string(forKey: AchievementKeys.highestAchievement) ?? "none"
    }
    
    // クリアしたステージ数を取得
    func getTotalStagesCleared() -> Int {
        return UserDefaults.standard.integer(forKey: AchievementKeys.totalStagesCleared)
    }
    
    // 無制限プレイ購入済みかどうか
    func hasUnlimitedPlay() -> Bool {
        return purchasedProducts.contains(unlimitedPlayProductID)
    }
    
    // プレイ可能かどうか
    func canPlay() -> Bool {
        return hasUnlimitedPlay() || getRemainingFreePlayCount() > 0 || getRemainingHourlyPlays() > 0
    }
    
    // 無制限プレイアイテムのロード
    func loadProducts() {
        let productIDs = Set([unlimitedPlayProductID])
        productsRequest = SKProductsRequest(productIdentifiers: productIDs)
        productsRequest?.delegate = self
        productsRequest?.start()
    }
    
    // 無制限プレイアイテムの購入
    func purchaseUnlimitedPlay() {
        guard let product = removeAdsProduct else {
            purchaseCompletionHandler?(false, "製品情報を読み込めませんでした。再度お試しください。")
            return
        }
        
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    // 購入の復元
    func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    // 購入済みとして設定
    private func markProductAsPurchased(_ productID: String) {
        purchasedProducts.insert(productID)
        
        if productID == unlimitedPlayProductID {
            UserDefaults.standard.set(true, forKey: Keys.isAdFree)
        }
    }
}

// MARK: - SKProductsRequestDelegate
extension GameManager: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let products = response.products
        
        for product in products {
            if product.productIdentifier == unlimitedPlayProductID {
                removeAdsProduct = product
                break
            }
        }
        
        if products.isEmpty {
            print("No products found")
        }
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        print("Product request failed: \(error.localizedDescription)")
    }
}

// MARK: - SKPaymentTransactionObserver
extension GameManager: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                // 購入成功
                completeTransaction(transaction)
            case .failed:
                // 購入失敗
                failedTransaction(transaction)
            case .restored:
                // 購入復元
                restoreTransaction(transaction)
            case .deferred, .purchasing:
                // 保留中、購入中は何もしない
                break
            @unknown default:
                break
            }
        }
    }
    
    private func completeTransaction(_ transaction: SKPaymentTransaction) {
        markProductAsPurchased(transaction.payment.productIdentifier)
        SKPaymentQueue.default().finishTransaction(transaction)
        purchaseCompletionHandler?(true, "購入が完了しました！")
    }
    
    private func restoreTransaction(_ transaction: SKPaymentTransaction) {
        guard let productID = transaction.original?.payment.productIdentifier else { return }
        markProductAsPurchased(productID)
        SKPaymentQueue.default().finishTransaction(transaction)
        purchaseCompletionHandler?(true, "購入を復元しました！")
    }
    
    private func failedTransaction(_ transaction: SKPaymentTransaction) {
        if let error = transaction.error as? SKError, error.code != .paymentCancelled {
            purchaseCompletionHandler?(false, "購入に失敗しました: \(error.localizedDescription)")
        } else {
            purchaseCompletionHandler?(false, "購入がキャンセルされました")
        }
        
        SKPaymentQueue.default().finishTransaction(transaction)
    }
}