import SwiftUI
import AVFoundation
import AppKit

/// A live camera QR-code scanner. Calls `onScan` with the first decoded payload.
/// Falls back gracefully (shows nothing useful) if no camera is available.
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
        let onScan: (String) -> Void
        private var didScan = false

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !didScan else { return }
            for obj in metadataObjects {
                if let qr = obj as? AVMetadataMachineReadableCodeObject,
                   qr.type == .qr, let value = qr.stringValue, !value.isEmpty {
                    didScan = true
                    // The delegate queue is .main, so deliver directly. Capture
                    // the handler locally to avoid sending `self` across actors.
                    let handler = onScan
                    handler(value)
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
    private let sessionQueue = DispatchQueue(label: "veil.camera.session")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func start() {
        // Ask for camera permission, then configure on a background queue.
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted, let self else { return }
            self.sessionQueue.async { self.configure() }
        }
    }

    private func configure() {
        session.beginConfiguration()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(coordinator, queue: .main)
            if output.availableMetadataObjectTypes.contains(.qr) {
                output.metadataObjectTypes = [.qr]
            }
        }
        session.commitConfiguration()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let preview = AVCaptureVideoPreviewLayer(session: self.session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = self.bounds
            self.layer?.addSublayer(preview)
            self.preview = preview
        }
        session.startRunning()
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    override func layout() {
        super.layout()
        preview?.frame = bounds
    }
}
