import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // アプリの初期化処理
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
        
        // 背景色を設定（少し濃い水色）
        window?.backgroundColor = UIColor(red: 220/255, green: 240/255, blue: 255/255, alpha: 1.0)
        
        return true
    }
}