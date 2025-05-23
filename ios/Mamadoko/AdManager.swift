import UIKit
import GoogleMobileAds

class AdManager: NSObject {
    static let shared = AdManager()
    
    // テスト用広告ユニットID（リリース時に実際のIDに置き換え）
    private let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910" // テスト用ID
    
    private var interstitialAd: GADInterstitialAd?
    
    // 広告表示完了ハンドラー
    var adCompletionHandler: (() -> Void)?
    
    override init() {
        super.init()
        loadInterstitialAd()
    }
    
    // インタースティシャル広告のロード
    func loadInterstitialAd() {
        let request = GADRequest()
        GADInterstitialAd.load(
            withAdUnitID: interstitialAdUnitID,
            request: request
        ) { [weak self] ad, error in
            if let error = error {
                print("インタースティシャル広告の読み込みに失敗しました: \(error.localizedDescription)")
                return
            }
            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
        }
    }
    
    // 広告表示
    func showInterstitialAd(from viewController: UIViewController, completion: @escaping () -> Void) {
        adCompletionHandler = completion
        
        if let ad = interstitialAd {
            ad.present(fromRootViewController: viewController)
        } else {
            print("広告の準備ができていません。スキップします。")
            completion()
            // 次回のために再ロード
            loadInterstitialAd()
        }
    }
}

// MARK: - GADFullScreenContentDelegate
extension AdManager: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("広告が閉じられました")
        // 広告が閉じられたら次の広告をロード
        loadInterstitialAd()
        // 完了ハンドラーを呼び出し
        adCompletionHandler?()
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("広告の表示に失敗しました: \(error.localizedDescription)")
        // 広告表示に失敗した場合も完了ハンドラーを呼び出す
        adCompletionHandler?()
        // 次回のために再ロード
        loadInterstitialAd()
    }
}