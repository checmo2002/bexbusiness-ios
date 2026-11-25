import UIKit
import WebKit
import UserNotifications

/// Màn hình chính: giao diện web của máy chủ BexBusiness trong WKWebView.
final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, WKDownloadDelegate {
    private let base: URL
    private var web: WKWebView!
    private let errorView = UIView()
    private let errorDetail = UILabel()
    private let loadingView = UIActivityIndicatorView(style: .large)
    private var titleObservation: NSKeyValueObservation?
    private var lightTheme = false
    private var downloadFiles: [ObjectIdentifier: URL] = [:]
    private var loadedOnce = false

    init(base: URL) {
        self.base = base
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) không dùng") }

    deinit {
        titleObservation?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { lightTheme ? .darkContent : .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bg

        let ucc = WKUserContentController()
        ucc.add(WeakScriptHandler(self), name: "bex")
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let js = "window.bexMobile = Object.freeze({ platform: 'ios', app: 'ios', version: '\(version)' });"
        ucc.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true))

        let cfg = WKWebViewConfiguration()
        cfg.userContentController = ucc
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.websiteDataStore = .default()
        cfg.applicationNameForUserAgent = "BexBusinessiOS/\(version)"

        web = WKWebView(frame: .zero, configuration: cfg)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.isOpaque = false
        web.backgroundColor = Theme.bg
        web.scrollView.backgroundColor = Theme.bg
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.bounces = false
        web.allowsLinkPreview = false
        if #available(iOS 16.4, *) { web.isInspectable = true }
        web.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(web)
        // phía trên chừa thanh trạng thái / tai thỏ; phía dưới tràn tới mép, trang web tự chừa vạch Home (safe-area)
        NSLayoutConstraint.activate([
            web.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            web.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            web.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        loadingView.color = Theme.muted
        loadingView.hidesWhenStopped = true
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingView)
        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        buildErrorView()

        titleObservation = web.observe(\.title, options: [.new]) { [weak self] wv, _ in
            DispatchQueue.main.async { self?.updateBadge(from: wv.title) }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(appBecameActive), name: UIApplication.didBecomeActiveNotification, object: nil)

        loadingView.startAnimating()
        web.load(URLRequest(url: base))
        // xin quyền hiện số tin chưa đọc trên biểu tượng app (hỏi khi đã vào máy chủ, không hỏi ngay lúc mở app)
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge]) { _, _ in }
    }

    // MARK: - Màn hình lỗi kết nối

    private func buildErrorView() {
        errorView.backgroundColor = Theme.bg
        errorView.isHidden = true
        errorView.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "wifi.exclamationmark"))
        icon.tintColor = Theme.muted
        icon.contentMode = .scaleAspectFit
        icon.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let title = UILabel()
        title.text = "Không kết nối được máy chủ"
        title.font = .systemFont(ofSize: 20, weight: .bold)
        title.textColor = Theme.text
        title.textAlignment = .center

        errorDetail.font = .systemFont(ofSize: 14)
        errorDetail.textColor = Theme.muted
        errorDetail.numberOfLines = 0
        errorDetail.textAlignment = .center

        let retry = UIButton(type: .system)
        retry.setTitle("Thử lại", for: .normal)
        retry.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        retry.backgroundColor = Theme.accent
        retry.setTitleColor(.white, for: .normal)
        retry.layer.cornerRadius = 12
        retry.heightAnchor.constraint(equalToConstant: 48).isActive = true
        retry.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        let change = UIButton(type: .system)
        change.setTitle("Đổi máy chủ", for: .normal)
        change.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        change.backgroundColor = Theme.card
        change.setTitleColor(Theme.text, for: .normal)
        change.layer.cornerRadius = 12
        change.layer.borderWidth = 1
        change.layer.borderColor = Theme.line.cgColor
        change.heightAnchor.constraint(equalToConstant: 48).isActive = true
        change.addTarget(self, action: #selector(changeServer), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [icon, title, errorDetail, retry, change])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(24, after: errorDetail)
        stack.translatesAutoresizingMaskIntoConstraints = false
        errorView.addSubview(stack)
        view.addSubview(errorView)
        NSLayoutConstraint.activate([
            errorView.topAnchor.constraint(equalTo: view.topAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: errorView.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: errorView.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: errorView.safeAreaLayoutGuide.trailingAnchor, constant: -28),
        ])
    }

    private func showError(_ error: Error) {
        loadingView.stopAnimating()
        errorDetail.text = "\(base.host ?? base.absoluteString)\n\(error.localizedDescription)\n\nNếu máy chủ dùng địa chỉ trycloudflare.com miễn phí, địa chỉ sẽ đổi mỗi khi máy chủ khởi động lại: quét lại mã QR mới."
        errorView.isHidden = false
    }

    @objc private func retryTapped() {
        errorView.isHidden = true
        loadingView.startAnimating()
        if web.url == nil || !loadedOnce { web.load(URLRequest(url: base)) } else { web.reload() }
    }

    @objc private func changeServer() {
        AppRouter.show(SetupViewController(prefill: base))
    }

    @objc private func appBecameActive() {
        // iOS có thể đã tắt tiến trình web khi app nằm nền lâu: trang trắng thì tải lại
        if loadedOnce && web.url == nil { web.load(URLRequest(url: base)) }
    }

    // MARK: - Số tin chưa đọc trên biểu tượng app (tiêu đề trang dạng "(3) BexBusiness")

    private func updateBadge(from title: String?) {
        var n = 0
        if let t = title, t.hasPrefix("("), let close = t.firstIndex(of: ")") {
            n = Int(t[t.index(after: t.startIndex)..<close]) ?? 0
        }
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(n) { _ in }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = n
        }
    }

    // MARK: - Tin nhắn từ trang web (window.webkit.messageHandlers.bex)

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "theme":
            lightTheme = (body["value"] as? String) == "light"
            let bg = lightTheme ? Theme.bgLight : Theme.bg
            view.backgroundColor = bg
            web.backgroundColor = bg
            web.scrollView.backgroundColor = bg
            setNeedsStatusBarAppearanceUpdate()
        case "changeServer":
            changeServer()
        default:
            break
        }
    }

    // MARK: - Điều hướng

    private func isOwn(_ url: URL) -> Bool {
        if ["about", "blob", "data"].contains(url.scheme ?? "") { return true }
        return url.host == base.host && url.port == base.port
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return decisionHandler(.cancel) }
        if navigationAction.shouldPerformDownload { return decisionHandler(.download) }
        if isOwn(url) {
            // liên kết tải tệp của BexBusiness có ?dl=1
            if let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems, q.contains(where: { $0.name == "dl" && $0.value == "1" }) {
                return decisionHandler(.download)
            }
            return decisionHandler(.allow)
        }
        // trang ngoài (link trong tin nhắn, tra cứu mã số thuế…) mở bằng Safari
        if ["http", "https", "mailto", "tel"].contains(url.scheme ?? "") {
            UIApplication.shared.open(url)
        }
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let h = navigationResponse.response as? HTTPURLResponse,
           let cd = h.value(forHTTPHeaderField: "Content-Disposition"), cd.lowercased().hasPrefix("attachment") {
            return decisionHandler(.download)
        }
        decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadedOnce = true
        loadingView.stopAnimating()
        errorView.isHidden = true
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleLoadError(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleLoadError(error)
    }

    private func handleLoadError(_ error: Error) {
        let e = error as NSError
        // -999: bị huỷ vì điều hướng mới; 102: chuyển sang tải tệp
        if e.domain == NSURLErrorDomain && e.code == NSURLErrorCancelled { return }
        if e.domain == "WebKitErrorDomain" && e.code == 102 { return }
        showError(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    // MARK: - Cửa sổ mới, hộp thoại, micro/camera

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            if isOwn(url) { webView.load(navigationAction.request) } else { UIApplication.shared.open(url) }
        }
        return nil
    }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        // chỉ máy chủ đã chọn mới được dùng micro / camera (iOS vẫn hỏi người dùng lần đầu)
        decisionHandler(origin.host == base.host ? .grant : .deny)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        presentAlert(a) { completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Huỷ", style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: "Đồng ý", style: .default) { _ in completionHandler(true) })
        presentAlert(a) { completionHandler(false) }
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let a = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        a.addTextField { $0.text = defaultText }
        a.addAction(UIAlertAction(title: "Huỷ", style: .cancel) { _ in completionHandler(nil) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(a.textFields?.first?.text) })
        presentAlert(a) { completionHandler(nil) }
    }

    /// Hiện hộp thoại; nếu đang có màn hình khác che (vd. bảng chia sẻ) thì trả lời mặc định để trang không bị treo
    private func presentAlert(_ a: UIAlertController, fallback: @escaping () -> Void) {
        if presentedViewController == nil && view.window != nil { present(a, animated: true) } else { fallback() }
    }

    // MARK: - Tải tệp → bảng chia sẻ (Lưu vào Tệp, gửi Zalo…)

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tai-ve", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = suggestedFilename.isEmpty ? "tep-tai-ve" : suggestedFilename
        let dest = dir.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: dest)
        downloadFiles[ObjectIdentifier(download)] = dest
        completionHandler(dest)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let file = downloadFiles.removeValue(forKey: ObjectIdentifier(download)) else { return }
        let share = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = view
        share.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 80, width: 1, height: 1)
        present(share, animated: true)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloadFiles.removeValue(forKey: ObjectIdentifier(download))
        let a = UIAlertController(title: "Không tải được tệp", message: error.localizedDescription, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}

/// Giữ tham chiếu yếu tới màn hình để WKUserContentController không giữ nó mãi (tránh rò bộ nhớ)
private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
