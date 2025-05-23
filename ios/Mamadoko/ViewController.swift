import UIKit
import WebKit
import AVFoundation
import AudioToolbox
import GoogleMobileAds
import StoreKit

// 音声プレーヤーを管理するクラス
class SoundManager {
    static let shared = SoundManager()
    
    // 音声プレーヤー
    private var correctSound: AVAudioPlayer?
    private var wrongSound: AVAudioPlayer?
    
    // 振動フィードバック
    private let correctFeedback = UINotificationFeedbackGenerator()
    private let wrongFeedback = UINotificationFeedbackGenerator()
    
    // 音声ファイルのURL
    private var correctSoundURL: URL? {
        Bundle.main.url(forResource: "correct02", withExtension: "mp3")
    }
    
    private var wrongSoundURL: URL? {
        Bundle.main.url(forResource: "wrong", withExtension: "mp3")
    }
    
    public init() {
        // オーディオセッションの設定
        setupAudioSession()
        
        // プレーヤーの初期化
        loadSounds()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            print("オーディオセッション設定成功")
        } catch {
            print("オーディオセッション設定エラー: \(error)")
        }
    }
    
    private func loadSounds() {
        // 正解音のロード
        if let url = correctSoundURL {
            do {
                // MP3形式として読み込む
                let soundData = try Data(contentsOf: url)
                correctSound = try AVAudioPlayer(data: soundData)
                correctSound?.prepareToPlay()
                correctSound?.volume = 1.0
                correctSound?.numberOfLoops = 0
                print("正解音ロード成功: \(url.path)")
            } catch {
                print("正解音ロードエラー: \(error)")
            }
        } else {
            print("正解音のURLが取得できません")
        }
        
        // 不正解音のロード - 同じ方法で読み込む
        if let url = wrongSoundURL {
            do {
                let soundData = try Data(contentsOf: url)
                wrongSound = try AVAudioPlayer(data: soundData)
                wrongSound?.prepareToPlay()
                wrongSound?.volume = 1.0
                wrongSound?.numberOfLoops = 0
                print("不正解音ロード成功: \(url.path)")
            } catch {
                print("不正解音ロードエラー: \(error)")
            }
        } else {
            print("不正解音のURLが取得できません")
        }
    }
    
    func playCorrect() {
        print("正解音を再生します")
        
        // 音声セッションを再アクティブ化
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("オーディオセッション再アクティブ化エラー: \(error)")
        }
        
        // プレーヤーが初期化されていない場合は再ロード
        if correctSound == nil {
            loadSounds()
        }
        
        // 音声再生
        correctSound?.currentTime = 0
        let success = correctSound?.play() ?? false
        print("正解音再生: \(success ? "成功" : "失敗")")
        
        // 振動フィードバック
        correctFeedback.notificationOccurred(.success)
    }
    
    func playWrong() {
        print("不正解音を再生します")
        
        // 音声セッションを再アクティブ化
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("オーディオセッション再アクティブ化エラー: \(error)")
        }
        
        // プレーヤーが初期化されていない場合は再ロード
        if wrongSound == nil {
            loadSounds()
        }
        
        // 音声再生
        wrongSound?.currentTime = 0
        let success = wrongSound?.play() ?? false
        print("不正解音再生: \(success ? "成功" : "失敗")")
        
        // 振動フィードバック
        wrongFeedback.notificationOccurred(.error)
    }
}

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    
    var webView: WKWebView!
    // Add delegates for sound messages
    let soundManager = SoundManager.shared
    
    // ゲーム管理
    let gameManager = GameManager.shared
    
    // 広告管理
    let adManager = AdManager.shared
    
    // アラート表示用
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // soundManagerは既にプロパティとして初期化済み
        
        // GameManagerの初期設定
        gameManager.loadProducts()
        gameManager.purchaseCompletionHandler = { [weak self] success, message in
            if let message = message {
                DispatchQueue.main.async {
                    self?.showAlert(title: success ? "購入完了" : "購入エラー", message: message)
                    // 購入状態を画面に反映
                    self?.updateRemainingPlaysDisplay()
                }
            }
        }
        
        // WebViewの設定
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []
        
        // JavaScriptコンソールのログを受け取るための設定
        let contentController = WKUserContentController()
        webConfiguration.userContentController = contentController
        
        // ビューポートの設定を追加
        let jScript = "var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'); document.getElementsByTagName('head')[0].appendChild(meta);"
        let userScript = WKUserScript(source: jScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        contentController.addUserScript(userScript)
        
        // エラーキャッチ用のスクリプトを追加
        let errorScript = """
        window.onerror = function(message, source, lineno, colno, error) {
            window.webkit.messageHandlers.jsError.postMessage(
                'JavaScript error: ' + message + ' at ' + source + ':' + lineno + ':' + colno + ' ' + (error ? error.stack : '')
            );
            return true;
        };
        console.error = function() {
            window.webkit.messageHandlers.jsError.postMessage('Console error: ' + Array.prototype.slice.call(arguments).join(' '));
        };
        """
        let errorUserScript = WKUserScript(source: errorScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        contentController.addUserScript(errorUserScript)
        
        // メッセージハンドラを追加
        contentController.add(self, name: "jsError")
        contentController.add(self, name: "playCorrect")
        contentController.add(self, name: "playWrong")
        contentController.add(self, name: "gameStart")
        contentController.add(self, name: "gameEnd")
        contentController.add(self, name: "pageLoaded")
        contentController.add(self, name: "purchase")
        contentController.add(self, name: "restore")
        
        // WebViewの作成
        webView = WKWebView(frame: self.view.frame, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        self.view.addSubview(webView)
        
        // 制約の設定
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            webView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
            webView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
            webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        
        // 背景色の設定（少し濃い水色）
        let bgColor = UIColor(red: 220/255, green: 240/255, blue: 255/255, alpha: 1.0)
        webView.backgroundColor = bgColor
        self.view.backgroundColor = bgColor
        
        // ローカルHTMLファイルの読み込み
        if let htmlPath = Bundle.main.path(forResource: "index", ofType: "html") {
            let htmlUrl = URL(fileURLWithPath: htmlPath)
            let dirUrl = Bundle.main.bundleURL
            webView.loadFileURL(htmlUrl, allowingReadAccessTo: dirUrl)
            print("HTML読み込み: \(htmlUrl)")
            print("アクセス許可ディレクトリ: \(dirUrl)")
        } else {
            print("HTMLファイルが見つかりません")
        }
    }
    
    // 残りプレイ回数表示を更新
    private func updateRemainingPlaysDisplay() {
        let count = gameManager.getRemainingFreePlayCount()
        let isAdFree = gameManager.isAdFree()
        
        // JavaScriptを実行して残りプレイ回数を表示
        let js = "window.updateRemainingPlays(\(count), \(isAdFree));"
        webView.evaluateJavaScript(js) { (result, error) in
            if let error = error {
                print("残りプレイ回数表示更新エラー: \(error)")
            }
        }
    }
    
    // JavaScriptアラートなどのUIを表示するための処理
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_) in
            completionHandler()
        }))
        present(alert, animated: true)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_) in
            completionHandler(true)
        }))
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler: { (_) in
            completionHandler(false)
        }))
        present(alert, animated: true)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.text = defaultText
        }
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_) in
            completionHandler(alert.textFields?.first?.text)
        }))
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler: { (_) in
            completionHandler(nil)
        }))
        present(alert, animated: true)
    }
    
    // Webビューのナビゲーション関連のデバッグ
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("Webビュー読み込み開始")
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("Webビュー読み込み完了")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("Webビュー読み込み失敗: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("Webビュー仮読み込み失敗: \(error.localizedDescription)")
    }
    
    // JavaScriptからのメッセージを受け取るメソッド
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "jsError":
            print("JavaScript Error: \(message.body)")
            
        case "playCorrect":
            print("正解音再生リクエストを受信")
            soundManager.playCorrect()
            
        case "playWrong":
            print("不正解音再生リクエストを受信")
            soundManager.playWrong()
            
        case "gameStart":
            print("ゲーム開始通知を受信")
            // プレイ可能かチェック
            if gameManager.canPlay() {
                // プレイ回数を記録
                gameManager.recordPlay()
                
                // 広告表示が必要かチェック
                if gameManager.shouldShowAd() {
                    // 広告表示
                    adManager.showInterstitialAd(from: self) { [weak self] in
                        // 広告表示後の処理
                        print("広告表示完了")
                    }
                }
            } else {
                // プレイ不可の場合は購入画面を表示
                showAlert(title: "プレイ制限", message: "無料プレイ回数を使い切りました。広告を見るか、広告非表示機能を購入してください。")
            }
            
        case "gameEnd":
            print("ゲーム終了通知を受信")
            // スコア情報があれば取得
            if let data = message.body as? [String: Any], let score = data["score"] as? Int {
                print("ゲーム終了スコア: \(score)")
            }
            
            // 残りプレイ回数を更新
            updateRemainingPlaysDisplay()
            
        case "pageLoaded":
            print("ページロード完了通知を受信")
            // 残りプレイ回数を表示
            updateRemainingPlaysDisplay()
            
        case "purchase":
            print("購入リクエストを受信")
            // 広告非表示購入処理を実行
            gameManager.purchaseRemoveAds()
            
        case "restore":
            print("購入復元リクエストを受信")
            // 購入復元処理を実行
            gameManager.restorePurchases()
            
        default:
            print("未知のメッセージハンドラ: \(message.name)")
        }
    }
}