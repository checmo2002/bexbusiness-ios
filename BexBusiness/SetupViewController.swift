import UIKit

/// Nâng cao: kết nối máy chủ riêng của công ty (nhập địa chỉ hoặc quét mã QR).
/// Bình thường app vào thẳng máy chủ BexBusiness chung (bexbusiness.xyz), không qua màn này.
final class SetupViewController: UIViewController, UITextFieldDelegate {
    private let prefill: URL?
    private let field = UITextField()
    private let connectButton = UIButton(type: .system)
    private let scanButton = UIButton(type: .system)
    private let defaultButton = UIButton(type: .system)
    private let errorLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var busy = false

    init(prefill: URL?) {
        self.prefill = prefill
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) không dùng") }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // màn hình này luôn nền tối: cửa sổ (và thanh tiêu đề trên Mac) theo màu tối
        view.window?.backgroundColor = Theme.bg
        view.window?.overrideUserInterfaceStyle = .dark
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bg

        let logo = UIImageView(image: UIImage(named: "Logo"))
        logo.contentMode = .scaleAspectFit
        logo.translatesAutoresizingMaskIntoConstraints = false
        logo.widthAnchor.constraint(equalToConstant: 72).isActive = true
        logo.heightAnchor.constraint(equalToConstant: 72).isActive = true

        let title = UILabel()
        title.attributedText = {
            let s = NSMutableAttributedString(string: "Bex", attributes: [.foregroundColor: Theme.text])
            s.append(NSAttributedString(string: "Business", attributes: [.foregroundColor: Theme.accentText]))
            return s
        }()
        title.font = .systemFont(ofSize: 30, weight: .bold)

        let sub = label("Nâng cao: máy chủ riêng của công ty", size: 15, color: Theme.muted)

        field.placeholder = "vd: may-chu.cong-ty.vn"
        field.attributedPlaceholder = NSAttributedString(string: field.placeholder ?? "", attributes: [.foregroundColor: Theme.muted.withAlphaComponent(0.7)])
        field.text = prefill.flatMap { $0.host.map(ServerStore.isDefaultHost) == true ? nil : $0.absoluteString }
        field.textColor = Theme.text
        field.font = .systemFont(ofSize: 16)
        field.keyboardType = .URL
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .go
        field.clearButtonMode = .whileEditing
        field.delegate = self
        field.backgroundColor = Theme.card
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = Theme.line.cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftViewMode = .always
        field.heightAnchor.constraint(equalToConstant: 50).isActive = true

        style(connectButton, title: "Kết nối", filled: true)
        connectButton.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
        style(scanButton, title: "Quét mã QR", filled: false)
        scanButton.setImage(UIImage(systemName: "qrcode.viewfinder"), for: .normal)
        scanButton.addTarget(self, action: #selector(scanTapped), for: .touchUpInside)
        style(defaultButton, title: "Dùng máy chủ BexBusiness", filled: false)
        defaultButton.setImage(UIImage(systemName: "arrow.uturn.backward"), for: .normal)
        defaultButton.addTarget(self, action: #selector(useDefaultTapped), for: .touchUpInside)

        errorLabel.textColor = Theme.bad
        errorLabel.font = .systemFont(ofSize: 14)
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        errorLabel.isHidden = true

        spinner.color = Theme.muted
        spinner.hidesWhenStopped = true

        #if targetEnvironment(macCatalyst)
        scanButton.isHidden = true // trên Mac không quét QR bằng camera máy tính: dán địa chỉ là nhanh nhất
        #endif
        let hint = label("Hầu hết công ty dùng chung máy chủ BexBusiness (bexbusiness.xyz) và không cần mục này. Chỉ nhập địa chỉ khi quản trị viên công ty bạn đưa máy chủ riêng.",
                         size: 13, color: Theme.muted)

        // logo nằm giữa: bọc trong một view để stack (căn đầy chiều ngang) không kéo giãn ảnh
        let logoWrap = UIView()
        logoWrap.addSubview(logo)
        NSLayoutConstraint.activate([
            logo.centerXAnchor.constraint(equalTo: logoWrap.centerXAnchor),
            logo.topAnchor.constraint(equalTo: logoWrap.topAnchor),
            logo.bottomAnchor.constraint(equalTo: logoWrap.bottomAnchor),
        ])
        title.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [logoWrap, title, sub, field, connectButton, scanButton, spinner, errorLabel, defaultButton, hint])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 14
        stack.setCustomSpacing(10, after: logoWrap)
        stack.setCustomSpacing(6, after: title)
        stack.setCustomSpacing(24, after: sub)
        stack.setCustomSpacing(24, after: errorLabel)
        stack.setCustomSpacing(18, after: defaultButton)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let powered = label("Powered by Beso", size: 12, color: Theme.muted)
        powered.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        view.addSubview(powered)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: g.centerYAnchor, constant: -20),
            powered.centerXAnchor.constraint(equalTo: g.centerXAnchor),
            powered.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -12),
        ])
        pinReadableWidth(stack, in: g)
        view.addGestureRecognizer(UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:))))
    }

    private func label(_ text: String, size: CGFloat, color: UIColor) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: size)
        l.textColor = color
        l.numberOfLines = 0
        l.textAlignment = .center
        return l
    }

    private func style(_ b: UIButton, title: String, filled: Bool) {
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        b.layer.cornerRadius = 12
        b.heightAnchor.constraint(equalToConstant: 50).isActive = true
        keepCustomLook(b)
        if filled {
            b.backgroundColor = Theme.accent
            b.setTitleColor(.white, for: .normal)
        } else {
            b.backgroundColor = Theme.card
            b.setTitleColor(Theme.text, for: .normal)
            b.tintColor = Theme.text
            b.layer.borderWidth = 1
            b.layer.borderColor = Theme.line.cgColor
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        connectTapped()
        return true
    }

    @objc private func scanTapped() {
        let scanner = QRScannerViewController { [weak self] text in
            guard let self else { return }
            self.field.text = text
            self.connectTapped()
        }
        scanner.modalPresentationStyle = .fullScreen
        present(scanner, animated: true)
    }

    @objc private func useDefaultTapped() {
        ServerStore.custom = nil
        AppRouter.show(WebViewController(base: ServerStore.defaultURL), from: self)
    }

    @objc private func connectTapped() {
        guard !busy else { return }
        view.endEditing(true)
        // quét/dán nhầm link mời vào công ty: mở thẳng link đó trên đúng máy chủ
        if let j = ServerStore.joinLink(field.text ?? "") {
            ServerStore.custom = j.server
            AppRouter.show(WebViewController(base: ServerStore.current, startPath: j.path), from: self)
            return
        }
        guard let url = ServerStore.normalize(field.text ?? "") else {
            showError("Nhập địa chỉ máy chủ, ví dụ may-chu.cong-ty.vn")
            return
        }
        if let h = url.host, ServerStore.isDefaultHost(h) { return useDefaultTapped() }
        busy = true
        errorLabel.isHidden = true
        spinner.startAnimating()
        connectButton.isEnabled = false
        Task { @MainActor in
            defer { self.busy = false; self.spinner.stopAnimating(); self.connectButton.isEnabled = true }
            do {
                try await ServerStore.check(url)
                ServerStore.custom = url
                AppRouter.show(WebViewController(base: url), from: self)
            } catch {
                self.showError(error.localizedDescription)
            }
        }
    }

    private func showError(_ text: String) {
        errorLabel.text = text
        errorLabel.isHidden = false
    }
}
