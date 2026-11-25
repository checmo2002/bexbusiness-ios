import UIKit
import AVFoundation

/// Quét mã QR bằng camera sau, trả về chuỗi đọc được.
final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let onResult: (String) -> Void
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var done = false
    private let messageLabel = UILabel()

    init(onResult: @escaping (String) -> Void) {
        self.onResult = onResult
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) không dùng") }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        messageLabel.text = "Hướng camera vào mã QR trên máy tính"
        messageLabel.textColor = .white
        messageLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        let close = UIButton(type: .system)
        close.setTitle("Đóng", for: .normal)
        close.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        close.setTitleColor(.white, for: .normal)
        close.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        close.layer.cornerRadius = 12
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let frame = UIView()
        frame.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        frame.layer.borderWidth = 3
        frame.layer.cornerRadius = 20
        frame.isUserInteractionEnabled = false
        frame.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(frame)
        view.addSubview(messageLabel)
        view.addSubview(close)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            frame.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            frame.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            frame.widthAnchor.constraint(equalToConstant: 250),
            frame.heightAnchor.constraint(equalToConstant: 250),
            messageLabel.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -24),
            messageLabel.bottomAnchor.constraint(equalTo: frame.topAnchor, constant: -24),
            close.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            close.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -24),
            close.widthAnchor.constraint(equalToConstant: 140),
            close.heightAnchor.constraint(equalToConstant: 48),
        ])

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async { ok ? self.setupCamera() : self.denied() }
            }
        default: denied()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let s = session
        DispatchQueue.global(qos: .userInitiated).async { if s.isRunning { s.stopRunning() } }
    }

    private func denied() {
        messageLabel.text = "BexBusiness chưa được dùng camera. Vào Cài đặt → BexBusiness → bật Camera, hoặc nhập địa chỉ bằng tay."
    }

    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            messageLabel.text = "Không mở được camera trên máy này."
            return
        }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        preview = layer

        let s = session
        DispatchQueue.global(qos: .userInitiated).async { s.startRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !done, let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let text = obj.stringValue, !text.isEmpty else { return }
        done = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss(animated: true) { self.onResult(text) }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
