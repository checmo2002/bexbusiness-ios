// BexBusiness cho iPhone, iPad và Mac (Powered by Beso)
// Vỏ app gốc bọc giao diện web của máy chủ BexBusiness: chọn máy chủ, quét mã QR, micro/camera cho phòng họp,
// tải tệp, thông báo tin mới, số tin chưa đọc trên biểu tượng app. Trên Mac chạy bằng Mac Catalyst.
import UIKit
import UserNotifications

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let c = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        c.delegateClass = SceneDelegate.self
        return c
    }

    // MARK: - Thông báo (do trang web tạo qua window.Notification, xem WebViewController)

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // trang web chỉ gửi khi cửa sổ đang ẩn hoặc bị che, nên vẫn hiện dù app đang mở
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        NotificationCenter.default.post(name: .bexNotificationClicked, object: nil, userInfo: response.notification.request.content.userInfo)
        completionHandler()
    }

    // MARK: - Menu trên Mac, phím tắt trên iPad có bàn phím (giữ ⌘ để xem)

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == .main else { return }
        builder.remove(menu: .format)

        let page = UIMenu(title: "", options: .displayInline, children: [
            UIKeyCommand(title: "Tải lại trang", action: #selector(WebViewController.reloadPage), input: "r", modifierFlags: .command),
        ])
        builder.insertChild(page, atStartOfMenu: .view)

        let server = UIMenu(title: "", options: .displayInline, children: [
            UIKeyCommand(title: "Đổi máy chủ…", action: #selector(WebViewController.changeServerCommand), input: "k", modifierFlags: [.command, .shift]),
        ])
        builder.insertChild(server, atEndOfMenu: .file)
    }
}

extension Notification.Name {
    static let bexNotificationClicked = Notification.Name("bex.notificationClicked")
}

/// Mỗi cửa sổ là một scene. iPad (Split View, Stage Manager) và Mac mở được nhiều cửa sổ cùng lúc.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        windowScene.title = "BexBusiness"
        #if targetEnvironment(macCatalyst)
        // thanh tiêu đề gọn: không chữ, không thanh công cụ, không đường kẻ, cùng màu nền với app
        if let tb = windowScene.titlebar {
            tb.titleVisibility = .hidden
            tb.toolbar = nil
            tb.separatorStyle = .none
        }
        windowScene.sizeRestrictions?.minimumSize = CGSize(width: 420, height: 560)
        #endif
        let w = UIWindow(windowScene: windowScene)
        Theme.apply(to: w)
        let path = connectionOptions.urlContexts.first.flatMap { AppRouter.path(fromAppURL: $0.url) }
        w.rootViewController = AppRouter.initialController(path: path)
        w.makeKeyAndVisible()
        window = w
    }

    /// Mở app bằng link bexbusiness://join/<mã> (nút "Mở trong app" trên trang mời)
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let path = URLContexts.first.flatMap({ AppRouter.path(fromAppURL: $0.url) }), let w = window else { return }
        if let web = w.rootViewController as? WebViewController { web.open(path: path) }
        else { w.rootViewController = AppRouter.initialController(path: path) }
    }
}

// MARK: - Màu sắc dùng chung (khớp giao diện web)
enum Theme {
    static let bg = UIColor(red: 0x0E / 255, green: 0x10 / 255, blue: 0x14 / 255, alpha: 1)
    static let bgLight = UIColor(red: 0xF4 / 255, green: 0xF6 / 255, blue: 0xF9 / 255, alpha: 1)
    static let card = UIColor(red: 0x1A / 255, green: 0x1E / 255, blue: 0x26 / 255, alpha: 1)
    static let line = UIColor(red: 0x27 / 255, green: 0x2C / 255, blue: 0x37 / 255, alpha: 1)
    static let text = UIColor(red: 0xE8 / 255, green: 0xEA / 255, blue: 0xEE / 255, alpha: 1)
    static let muted = UIColor(red: 0xA3 / 255, green: 0xAB / 255, blue: 0xB9 / 255, alpha: 1)
    static let accent = UIColor(red: 0x0F / 255, green: 0x7B / 255, blue: 0x7A / 255, alpha: 1)  // xanh cổ vịt BexBusiness
    static let accentText = UIColor(red: 0x5C / 255, green: 0xCF / 255, blue: 0xC6 / 255, alpha: 1)  // chữ nhấn trên nền tối
    static let bad = UIColor(red: 0xFF / 255, green: 0x70 / 255, blue: 0x70 / 255, alpha: 1)

    /// Giao diện sáng/tối trang web chọn lần trước, nhớ lại để lúc mở app không bị nháy màu
    static var webLight: Bool {
        get { UserDefaults.standard.bool(forKey: "bex.lightTheme") }
        set { UserDefaults.standard.set(newValue, forKey: "bex.lightTheme") }
    }
    static var webBg: UIColor { webLight ? bgLight : bg }

    /// Màu cửa sổ theo giao diện trang (trên Mac là cả thanh tiêu đề)
    static func apply(to w: UIWindow?) {
        guard let w else { return }
        w.backgroundColor = webBg
        w.overrideUserInterfaceStyle = webLight ? .light : .dark
    }
}

// MARK: - Địa chỉ máy chủ đã lưu
enum ServerStore {
    private static let key = "bex.serverURL"

    /// Máy chủ BexBusiness dùng chung cho mọi doanh nghiệp (từ máy chủ 1.4.2)
    static let defaultURL = URL(string: "https://bexbusiness.xyz")!

    /// Máy chủ riêng của công ty (mục Nâng cao). nil = dùng máy chủ BexBusiness chung.
    static var custom: URL? {
        get {
            guard let u = UserDefaults.standard.string(forKey: key).flatMap(URL.init(string:)), let host = u.host else { return nil }
            // địa chỉ tạm trycloudflare.com đã chết khi máy chủ khởi động lại; trùng máy chủ chung thì coi như mặc định
            if host.hasSuffix("trycloudflare.com") || isDefaultHost(host) { return nil }
            return u
        }
        set {
            if let n = newValue, let h = n.host, !isDefaultHost(h) { UserDefaults.standard.set(n.absoluteString, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
    }

    static var current: URL { custom ?? defaultURL }

    static func isDefaultHost(_ host: String) -> Bool {
        let h = host.lowercased()
        return h == defaultURL.host || h == "www." + (defaultURL.host ?? "")
    }

    /// Link mời vào công ty: https://<máy chủ>/join/<mã> → (gốc máy chủ, đường dẫn /join/<mã>)
    static func joinLink(_ raw: String) -> (server: URL, path: String)? {
        guard let u = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)), let host = u.host,
              ["http", "https"].contains(u.scheme?.lowercased() ?? ""), u.path.hasPrefix("/join/"), u.path.count > 6 else { return nil }
        var o = URLComponents()
        o.scheme = u.scheme?.lowercased()
        o.host = isDefaultHost(host) ? defaultURL.host : host
        o.port = u.port
        guard let server = o.url else { return nil }
        return (server, u.path)
    }

    /// Chuẩn hoá chữ người dùng nhập / mã QR thành gốc máy chủ: https://ten-may-chu[:cổng]
    static func normalize(_ raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") { s = "https://" + s }
        guard let c = URLComponents(string: s), let host = c.host, !host.isEmpty,
              let scheme = c.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return nil }
        var o = URLComponents()
        o.scheme = scheme
        o.host = host
        o.port = c.port
        return o.url
    }

    enum CheckError: LocalizedError {
        case notBex, http(Int), network(String)
        var errorDescription: String? {
            switch self {
            case .notBex: return "Địa chỉ này không phải máy chủ BexBusiness."
            case .http(let code): return "Máy chủ trả lỗi \(code). Kiểm tra lại địa chỉ."
            case .network(let m): return "Không kết nối được: \(m)"
            }
        }
    }

    /// Gọi /api/state để chắc đây đúng là máy chủ BexBusiness
    static func check(_ base: URL) async throws {
        var req = URLRequest(url: base.appendingPathComponent("api/state"))
        req.timeoutInterval = 10
        req.cachePolicy = .reloadIgnoringLocalCacheData
        let data: Data
        let resp: URLResponse
        do { (data, resp) = try await URLSession.shared.data(for: req) } catch { throw CheckError.network(error.localizedDescription) }
        if let h = resp as? HTTPURLResponse, h.statusCode != 200 { throw CheckError.http(h.statusCode) }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any], obj["platformReady"] != nil else { throw CheckError.notBex }
    }
}

// MARK: - Chuyển màn hình gốc
enum AppRouter {
    /// Mở app là vào thẳng máy chủ (mặc định bexbusiness.xyz), không hỏi máy chủ nữa
    static func initialController(path: String? = nil) -> UIViewController {
        WebViewController(base: ServerStore.current, startPath: path)
    }

    /// bexbusiness://join/<mã> → "/join/<mã>". Chỉ nhận các đường dẫn của app.
    static func path(fromAppURL url: URL) -> String? {
        guard url.scheme?.lowercased() == "bexbusiness" else { return nil }
        let p = "/" + (url.host ?? "") + url.path
        return (p.hasPrefix("/join/") || p == "/app" || p.hasPrefix("/app/")) ? p : nil
    }

    /// Thay màn hình của đúng cửa sổ đang chứa `current` (khi mở nhiều cửa sổ trên iPad/Mac)
    static func show(_ vc: UIViewController, from current: UIViewController) {
        let fallback = UIApplication.shared.connectedScenes.compactMap { ($0.delegate as? SceneDelegate)?.window }.first
        guard let w = current.view.window ?? fallback else { return }
        UIView.transition(with: w, duration: 0.25, options: .transitionCrossDissolve, animations: {
            w.rootViewController = vc
        })
    }
}

/// Màn hình gọn giữa iPad/Mac: không kéo giãn hết bề ngang
func pinReadableWidth(_ v: UIView, in g: UILayoutGuide, max: CGFloat = 420, margin: CGFloat = 24) {
    let fill = v.widthAnchor.constraint(equalTo: g.widthAnchor, constant: -2 * margin)
    fill.priority = .defaultHigh
    NSLayoutConstraint.activate([
        v.centerXAnchor.constraint(equalTo: g.centerXAnchor),
        v.widthAnchor.constraint(lessThanOrEqualToConstant: max),
        v.leadingAnchor.constraint(greaterThanOrEqualTo: g.leadingAnchor, constant: margin),
        fill,
    ])
}

/// Nút tự vẽ màu: trên Mac giữ kiểu iPad thay vì nút macOS mặc định
func keepCustomLook(_ b: UIButton) {
    if #available(iOS 15.0, *) { b.preferredBehavioralStyle = .pad }
}
