import UIKit
import WebKit
import UserNotifications
import QuickLook

/// Màn hình chính: giao diện web của máy chủ BexBusiness trong WKWebView.
final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler,
                                WKScriptMessageHandlerWithReply, WKDownloadDelegate, QLPreviewControllerDataSource {
    private let base: URL
    var web: WKWebView!
    // thanh Tab gốc (NativeTabBar.swift)
    let tabBar = UITabBar()
    var navState = NavState()
    var nativeTabsOn = false
    var webBottomToView: NSLayoutConstraint!
    var webBottomToTabBar: NSLayoutConstraint!
    private let errorView = UIView()
    private let errorDetail = UILabel()
    private let loadingView = UIActivityIndicatorView(style: .large)
    private var titleObservation: NSKeyValueObservation?
    private var lightTheme = Theme.webLight
    private var downloadFiles: [ObjectIdentifier: URL] = [:]
    /// tải về để xem trong trình xem tài liệu (thay vì bảng chia sẻ)
    private var previewDownloads: Set<ObjectIdentifier> = []
    private var previewFile: URL?
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
        view.backgroundColor = Theme.webBg

        let ucc = WKUserContentController()
        ucc.add(WeakScriptHandler(self), name: "bex")
        ucc.addScriptMessageHandler(WeakReplyHandler(self), contentWorld: .page, name: "bexNotify")
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let js = "window.bexMobile = Object.freeze({ platform: 'ios', app: 'ios', device: '\(Self.deviceKind)', version: '\(version)' });"
        ucc.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: Self.notificationShim, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: Self.lockZoom, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: NativeTabs.script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        #if !targetEnvironment(macCatalyst)
        if UIDevice.current.userInterfaceIdiom == .phone {
            ucc.addUserScript(WKUserScript(source: NativeTabs.earlyScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        #endif

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
        web.backgroundColor = Theme.webBg
        web.scrollView.backgroundColor = Theme.webBg
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.bounces = false
        web.allowsLinkPreview = false
        if #available(iOS 16.4, *) { web.isInspectable = true }
        web.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(web)
        buildTabBar()
        // phía trên chừa thanh trạng thái / tai thỏ; phía dưới tràn tới mép, trang web tự chừa vạch Home (safe-area).
        // Khi dùng thanh Tab gốc thì trang dừng ở mép trên thanh Tab.
        webBottomToView = web.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        webBottomToTabBar = web.bottomAnchor.constraint(equalTo: tabBar.topAnchor)
        NSLayoutConstraint.activate([
            web.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            web.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webBottomToView,
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
        NotificationCenter.default.addObserver(self, selector: #selector(notificationClicked(_:)), name: .bexNotificationClicked, object: nil)

        loadingView.startAnimating()
        web.load(URLRequest(url: base))
        // xin quyền thông báo + số tin chưa đọc trên biểu tượng app (hỏi khi đã vào máy chủ, không hỏi ngay lúc mở app).
        // Hỏi đủ cả 3 trong một lần: iOS/macOS chỉ hiện hộp hỏi một lần duy nhất.
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { _, _ in }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Theme.apply(to: view.window)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateTabBar() // xoay máy / đổi cỡ cửa sổ iPad: bật tắt thanh Tab gốc theo bề ngang
    }

    static var deviceKind: String {
        #if targetEnvironment(macCatalyst)
        return "mac"
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        #endif
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
        keepCustomLook(retry)
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
        keepCustomLook(change)
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
        ])
        pinReadableWidth(stack, in: errorView.safeAreaLayoutGuide, margin: 28)
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
        AppRouter.show(SetupViewController(prefill: base), from: self)
    }

    // MARK: - Lệnh menu / phím tắt (khai báo trong AppDelegate.buildMenu)

    @objc func changeServerCommand() { changeServer() }

    @objc func reloadPage() {
        errorView.isHidden = true
        if web.url == nil || !loadedOnce { web.load(URLRequest(url: base)) } else { web.reload() }
    }

    /// App đứng yên như app gốc: không chụm hai ngón / chạm đúp để phóng cả trang, không tự phóng khi gõ chữ.
    /// Ảnh, PDF, video mở bằng trình xem tài liệu riêng (xem openPreview), ở đó mới phóng to được.
    static let lockZoom = """
    (function () {
      var c = 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover';
      var m = document.querySelector('meta[name=viewport]');
      if (!m) { m = document.createElement('meta'); m.name = 'viewport'; (document.head || document.documentElement).appendChild(m); }
      m.setAttribute('content', c);
      // Thanh điều hướng dưới (điện thoại) chỉ vuốt ngang, không bị kéo lên/xuống rồi kẹt lệch.
      // Tạm vá phía app; phiên Web sẽ sửa gốc khi làm lại thanh dưới (claude/yeu-cau-cho-web.md).
      var st = document.createElement('style');
      st.id = 'bex-app-fix';
      st.textContent = 'html,body{overscroll-behavior:none}' +
        '@media (max-width:760px){.rail{touch-action:pan-x;overscroll-behavior:contain;overflow-y:hidden}' +
        '.rail .rail-scroll,.rail .co-group,.rail .co-depts{touch-action:pan-x}}';
      (document.head || document.documentElement).appendChild(st);
    })();
    """

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
        // tên cửa sổ trên Mac (menu Cửa sổ, Mission Control) và trình chuyển app trên iPad
        view.window?.windowScene?.title = title?.isEmpty == false ? title : "BexBusiness"
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
            Theme.webLight = lightTheme
            let bg = Theme.webBg
            view.backgroundColor = bg
            web.backgroundColor = bg
            web.scrollView.backgroundColor = bg
            Theme.apply(to: view.window)
            setNeedsStatusBarAppearanceUpdate()
        case "changeServer":
            changeServer()
        case "nav":
            navState = NavState(body)
            updateTabBar(syncPage: true)
        case "preview":
            // trang web nhờ app mở tệp bằng trình xem tài liệu: {type:'preview', url}
            if let s = body["url"] as? String, let u = URL(string: s, relativeTo: web.url ?? base)?.absoluteURL, isOwn(u) { openPreview(u) }
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
        // "Xem" tệp (PDF…) mở tab mới: dùng trình xem tài liệu thay vì đè lên app (không có nút quay lại)
        if let url = navigationAction.request.url {
            if isOwn(url) { openPreview(url) } else { UIApplication.shared.open(url) }
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

    // MARK: - Trình xem tài liệu (ảnh, PDF, video, Word/Excel): chụm hai ngón để phóng, có nút chia sẻ

    private func openPreview(_ url: URL) {
        loadingView.startAnimating()
        web.startDownload(using: URLRequest(url: url)) { [weak self] d in
            d.delegate = self
            self?.previewDownloads.insert(ObjectIdentifier(d))
        }
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { previewFile == nil ? 0 : 1 }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        (previewFile ?? base) as NSURL
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
        if previewDownloads.remove(ObjectIdentifier(download)) != nil {
            loadingView.stopAnimating()
            previewFile = file
            let ql = QLPreviewController()
            ql.dataSource = self
            present(ql, animated: true)
            return
        }
        #if targetEnvironment(macCatalyst)
        // Mac: hộp thoại "Lưu" quen thuộc thay cho bảng chia sẻ
        present(UIDocumentPickerViewController(forExporting: [file], asCopy: true), animated: true)
        #else
        let share = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = view
        share.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 80, width: 1, height: 1)
        present(share, animated: true)
        #endif
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloadFiles.removeValue(forKey: ObjectIdentifier(download))
        previewDownloads.remove(ObjectIdentifier(download))
        loadingView.stopAnimating()
        let a = UIAlertController(title: "Không mở được tệp", message: error.localizedDescription, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}

// MARK: - Thông báo gốc thay cho window.Notification (WKWebView không có sẵn)

extension WebViewController {
    /// Trang web dùng `new Notification(title, {body, tag})`, `Notification.permission`, `Notification.requestPermission()`.
    /// Lớp này chuyển sang thông báo của iOS/macOS. Trên Mac app chạy nền nên thông báo đến bình thường;
    /// trên iPhone/iPad chỉ đến khi app còn mở hoặc vừa ra nền (muốn có khi app đóng cần APNs).
    static let notificationShim = #"""
    (function () {
      var h = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.bexNotify;
      if (!h) return;
      var perm = 'default', live = {};
      function N(title, opts) {
        opts = opts || {};
        this.title = String(title == null ? '' : title); this.body = String(opts.body || ''); this.tag = String(opts.tag || '');
        this.onclick = null; this.onclose = null; this.onshow = null; this.onerror = null;
        this._id = Math.random().toString(36).slice(2) + Date.now().toString(36);
        live[this._id] = this;
        if (perm === 'granted') h.postMessage({ type: 'show', id: this._id, title: this.title, body: this.body, tag: this.tag });
      }
      N.prototype.close = function () { delete live[this._id]; h.postMessage({ type: 'close', id: this._id, tag: this.tag }); };
      N.prototype.addEventListener = function (t, f) { if (t === 'click') this.onclick = f; };
      N.prototype.removeEventListener = function () {};
      Object.defineProperty(N, 'permission', { get: function () { return perm; } });
      N.requestPermission = function (cb) {
        return h.postMessage({ type: 'request' }).then(function (p) { perm = p || 'denied'; if (cb) cb(perm); return perm; });
      };
      N._bexClick = function (id) { var n = live[id]; if (!n) return false; if (typeof n.onclick === 'function') n.onclick({ target: n }); return true; };
      h.postMessage({ type: 'status' }).then(function (p) { perm = p || 'default'; });
      Object.defineProperty(window, 'Notification', { value: N, writable: true, configurable: true });
    })();
    """#

    private static func permString(_ s: UNAuthorizationStatus) -> String {
        switch s {
        case .notDetermined: return "default"
        case .denied: return "denied"
        default: return "granted"
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        let reply: (Any?) -> Void = { v in DispatchQueue.main.async { replyHandler(v, nil) } }
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return reply(nil) }
        let center = UNUserNotificationCenter.current()
        switch type {
        case "status":
            center.getNotificationSettings { reply(Self.permString($0.authorizationStatus)) }
        case "request":
            center.getNotificationSettings { s in
                guard s.authorizationStatus == .notDetermined else { return reply(Self.permString(s.authorizationStatus)) }
                center.requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in reply(ok ? "granted" : "denied") }
            }
        case "show":
            let id = body["id"] as? String ?? UUID().uuidString
            let tag = body["tag"] as? String ?? ""
            let c = UNMutableNotificationContent()
            c.title = (body["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "BexBusiness"
            c.body = body["body"] as? String ?? ""
            c.sound = .default
            if !tag.isEmpty { c.threadIdentifier = tag }
            c.userInfo = ["bexId": id, "scene": view.window?.windowScene?.session.persistentIdentifier ?? ""]
            // cùng tag thì thay thông báo cũ, giống trình duyệt
            center.add(UNNotificationRequest(identifier: tag.isEmpty ? id : "tag:" + tag, content: c, trigger: nil))
            reply(true)
        case "close":
            let tag = body["tag"] as? String ?? ""
            let ident = tag.isEmpty ? (body["id"] as? String ?? "") : "tag:" + tag
            center.removeDeliveredNotifications(withIdentifiers: [ident])
            reply(true)
        default:
            reply(nil)
        }
    }

    /// Bấm vào thông báo: đưa đúng cửa sổ lên trước và chạy onclick của trang (mở kênh/tin nhắn)
    @objc fileprivate func notificationClicked(_ n: Notification) {
        guard let id = n.userInfo?["bexId"] as? String else { return }
        let scene = n.userInfo?["scene"] as? String ?? ""
        if UIApplication.shared.supportsMultipleScenes, let session = view.window?.windowScene?.session,
           session.persistentIdentifier == scene {
            UIApplication.shared.requestSceneSessionActivation(session, userActivity: nil, options: nil, errorHandler: nil)
        }
        let safe = String(id.filter { $0.isLetter || $0.isNumber })
        web.evaluateJavaScript("window.Notification && Notification._bexClick ? Notification._bexClick('\(safe)') : false", completionHandler: nil)
    }
}

private final class WeakReplyHandler: NSObject, WKScriptMessageHandlerWithReply {
    weak var target: WKScriptMessageHandlerWithReply?
    init(_ target: WKScriptMessageHandlerWithReply) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        if let t = target { t.userContentController(userContentController, didReceive: message, replyHandler: replyHandler) }
        else { replyHandler(nil, nil) }
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
