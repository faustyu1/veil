import SwiftUI
@preconcurrency import AVFoundation

/// Live camera QR scanner. Wraps `AVCaptureSession` in a plain UIKit view
/// controller — SwiftUI has no first-party scanner, and this keeps the preview
/// layer's lifecycle tied to the view rather than to view-graph updates.
struct QRScannerView: View {
    @Environment(Loc.self) private var loc
    @Environment(\.dismiss) private var dismiss

    let onScan: (String) -> Void

    @State private var status: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                ScannerRepresentable(onScan: handle, onStatus: { status = $0 })
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.white.opacity(0.8), lineWidth: 3)
                        .frame(width: 240, height: 240)
                    Spacer()
                    if !status.isEmpty {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.6), in: Capsule())
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle(loc("Scan camera"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("Cancel")) { dismiss() }
                }
            }
        }
    }

    private func handle(_ payload: String) {
        onScan(payload)
        dismiss()
    }
}

private struct ScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onStatus: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onScan = onScan
        controller.onStatus = onStatus
        return controller
    }

    func updateUIViewController(_ controller: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController {
    // Captured locally by the delegate callback so we never touch `self`'s
    // SwiftUI closures across actor boundaries.
    var onScan: ((String) -> Void)?
    var onStatus: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !session.isRunning else { return }
        // Starting the session blocks; keep it off the main thread.
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.stopRunning()
        }
    }

    private func configureSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            buildSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.buildSession()
                        let session = self.session
                        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
                    } else {
                        self.onStatus?("Camera access denied")
                    }
                }
            }
        default:
            onStatus?("Camera access denied — enable it in Settings")
        }
    }

    private func buildSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            onStatus?("No camera available")
            return
        }
        session.beginConfiguration()
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            onStatus?("Cannot read QR codes on this device")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
        onStatus?("Point the camera at a QR code")
    }

    fileprivate func handleScan(_ metadataObjects: [AVMetadataObject]) {
        guard !hasScanned,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue, !value.isEmpty else { return }
        hasScanned = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onScan?(value)
    }
}

// The metadata output is configured with `queue: .main`, so the callback really
// does arrive on the main actor — `@preconcurrency` states that fact for a
// delegate protocol that predates concurrency annotations.
extension ScannerViewController: @preconcurrency AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        handleScan(metadataObjects)
    }
}
