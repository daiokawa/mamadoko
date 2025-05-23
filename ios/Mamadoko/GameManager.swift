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
    
    // 広告表示間隔（プレイ回数）
    private let adInterval = 3
    
    // 課金アイテムID
    private let removeAdsProductID = "com.daiokawa.mamadoko.removeads"
    
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
            purchasedProducts.insert(removeAdsProductID)
        }
        
        // トランザクションオブザーバーの設定
        SKPaymentQueue.default().add(self)
    }
    
    // 残りの無料プレイ回数を取得
    func getRemainingFreePlayCount() -> Int {
        let usedCount = UserDefaults.standard.integer(forKey: Keys.freePlayCount)
        return max(0, maxFreePlayCount - usedCount)
    }
    
    // プレイ回数を記録
    func recordPlay() {
        // 広告非表示購入済みの場合は記録しない
        if isAdFree() { return }
        
        var count = UserDefaults.standard.integer(forKey: Keys.freePlayCount)
        count += 1
        UserDefaults.standard.set(count, forKey: Keys.freePlayCount)
        
        // 最終プレイ日時を記録
        UserDefaults.standard.set(Date(), forKey: Keys.lastPlayDate)
    }
    
    // 広告表示が必要かどうか
    func shouldShowAd() -> Bool {
        // 広告非表示購入済みの場合
        if isAdFree() { return false }
        
        // 無料プレイ期間中
        if getRemainingFreePlayCount() > 0 { return false }
        
        // 無料プレイ終了後、一定回数ごとに広告表示
        let count = UserDefaults.standard.integer(forKey: Keys.freePlayCount) - maxFreePlayCount
        return count > 0 && count % adInterval == 0
    }
    
    // 広告非表示購入済みかどうか
    func isAdFree() -> Bool {
        return purchasedProducts.contains(removeAdsProductID)
    }
    
    // プレイ可能かどうか
    func canPlay() -> Bool {
        return isAdFree() || getRemainingFreePlayCount() > 0 || shouldShowAd()
    }
    
    // 広告非表示アイテムのロード
    func loadProducts() {
        let productIDs = Set([removeAdsProductID])
        productsRequest = SKProductsRequest(productIdentifiers: productIDs)
        productsRequest?.delegate = self
        productsRequest?.start()
    }
    
    // 広告非表示アイテムの購入
    func purchaseRemoveAds() {
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
        
        if productID == removeAdsProductID {
            UserDefaults.standard.set(true, forKey: Keys.isAdFree)
        }
    }
}

// MARK: - SKProductsRequestDelegate
extension GameManager: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let products = response.products
        
        for product in products {
            if product.productIdentifier == removeAdsProductID {
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