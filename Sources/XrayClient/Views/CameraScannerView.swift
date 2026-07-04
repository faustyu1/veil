import SwiftUI
import AVFoundation
import AppKit

/// A live camera QR-code scanner. Calls `onScan` with the decoded payload.
/// Shows a live preview, handles no-camera / no-permission gracefully, and
/// flashes a green overlay on successful decode.
struct CameraScannerView: NSViewRepresentable {
    var onScan: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    func makeNSView(context: Context) -> ScannerNSView {
        let view = ScannerNSView()
        view.coordinator = context.coordinator
        view.start()
        return view
    }

    func updateNSView(_ nsView: ScannerNSView, context: Context) {}

    static func dismantleNSView(_ nsView: ScannerNSView, coordinator: Coordinator) {
        nsView.stop()
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private nonisolated(unsafe) let onScan: (String) -> Void
        private var lastScan: String?
        private var lastScanTime: Date = .distantPast

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            // Delegate is set to .main queue, so we're already on the main thread.
            for obj in metadataObjects {
                if let qr = obj as? AVMetadataMachineReadableCodeObject,
                   qr.type == .qr, let value = qr.stringValue, !value.isEmpty {
                    // Debounce: ignore the same code for 2 seconds.
                    let now = Date()
                    if value == lastScan && now.timeIntervalSince(lastScanTime) < 2 { return }
                    lastScan = value
                    lastScanTime = now
                    onScan(value)
                    return
                }
            }
        }
    }
}

/// Hosts the AVCaptureVideoPreviewLayer and owns the capture session.
final class ScannerNSView: NSView {
    weak var coordinator: CameraScannerView.Coordinator?
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var statusLayer: CATextLayer?
    private var flashLayer: CALayer?

    enum Status: String {
        case starting = "Starting camera…"
        case noCamera = "No camera found"
        case denied = "Camera permission denied\nEnable it in System Settings → Privacy → Camera"
        case running = ""
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        setupStatusLayer()
        setupFlashLayer()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Status overlay

    private func setupStatusLayer() {
        let tl = CATextLayer()
        tl.string = Status.starting.rawValue
        tl.fontSize = 13
        tl.foregroundColor = NSColor.white.cgColor
        tl.alignmentMode = .center
        tl.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        tl.frame = CGRect(x: 0, y: bounds.midY - 10, width: bounds.width, height: 20)
        layer?.addSublayer(tl)
        statusLayer = tl
    }

    private func setupFlashLayer() {
        let fl = CALayer()
        fl.backgroundColor = NSColor(calibratedWhite: 1, alpha: 0.85).cgColor
        fl.opacity = 0
        fl.frame = bounds
        layer?.addSublayer(fl)
        flashLayer = fl
    }

    private func setStatus(_ status: Status) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLayer?.string = status.rawValue
            self?.statusLayer?.isHidden = status == .running
        }
    }

    // MARK: - Camera lifecycle

    func start() {
        setStatus(.starting)
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            guard granted else {
                Task { @MainActor in self.setStatus(.denied) }
                return
            }
            Task { @MainActor in self.configure() }
        }
    }

    private func configure() {
        session.beginConfiguration()

        // Use the highest-quality preset that the session supports.
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video) else {
            session.commitConfiguration()
            setStatus(.noCamera)
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            setStatus(.noCamera)
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            setStatus(.noCamera)
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(coordinator, queue: .main)
        // Set metadata types *after* the output is added to the session.
        let types = output.availableMetadataObjectTypes
        if types.contains(.qr) {
            output.metadataObjectTypes = [.qr]
        } else {
            session.commitConfiguration()
            setStatus(.noCamera)
            return
        }

        session.commitConfiguration()

        // Preview layer — set frame to current bounds (may still be zero,
        // layout() will fix it when SwiftUI assigns the real frame).
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = bounds
        layer?.insertSublayer(preview, below: statusLayer)
        self.preview = preview

        session.startRunning()
        setStatus(.running)
    }

    func stop() {
        session.stopRunning()
    }

    /// Called by the coordinator when a QR is decoded — flashes white.
    func flash() {
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 0
        anim.toValue = 0.85
        anim.duration = 0.1
        anim.autoreverses = true
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        flashLayer?.add(anim, forKey: "flash")
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        preview?.frame = bounds
        statusLayer?.frame = CGRect(x: 0, y: bounds.midY - 10, width: bounds.width, height: 20)
        flashLayer?.frame = bounds
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // SwiftUI may assign the real bounds after configure() ran; update now.
        preview?.frame = bounds
        statusLayer?.frame = CGRect(x: 0, y: bounds.midY - 10, width: bounds.width, height: 20)
        flashLayer?.frame = bounds
    }
}
