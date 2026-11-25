// BexBusiness cho iPhone (Powered by Beso)
// Vỏ app gốc bọc giao diện web của máy chủ BexBusiness: chọn máy chủ, quét mã QR, micro/camera cho phòng họp,
// tải tệp, số tin chưa đọc trên biểu tượng app.
import UIKit
import UserNotifications

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.backgroundColor = Theme.bg
        w.overrideUserInterfaceStyle = .dark
        w.rootViewController = AppRouter.initialController()
        w.makeKeyAndVisible()
        window = w
        // xin quyền hiện số tin chưa đọc trên biểu tượng app
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge]) { _, _ in }
        return true
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
    static let accent = UIColor(red: 0x3D / 255, green: 0x8B / 255, blue: 0xFF / 255, alpha: 1)
    static let bad = UIColor(red: 0xFF / 255, green: 0x70 / 255, blue: 0x70 / 255, alpha: 1)
}

// MARK: - Địa chỉ máy chủ đã lưu
enum ServerStore {
    private static let key = "bex.serverURL"

    static var url: URL? {
        get { UserDefaults.standard.string(forKey: key).flatMap(URL.init(string:)) }
        set { UserDefaults.standard.set(newValue?.absoluteString, forKey: key) }
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
    static func initialController() -> UIViewController {
        if let u = ServerStore.url { return WebViewController(base: u) }
        return SetupViewController(prefill: nil)
    }

    static func show(_ vc: UIViewController) {
        guard let w = (UIApplication.shared.delegate as? AppDelegate)?.window else { return }
        UIView.transition(with: w, duration: 0.25, options: .transitionCrossDissolve, animations: {
            w.rootViewController = vc
        })
    }
}
