#if os(macOS)
import XCTest
import Network
@testable import XrayClient

/// A download whose progress never moves is indistinguishable from one that has
/// stalled, and that is exactly what the update window showed: `Zero KB of
/// 73.7 MB` for the whole transfer. The bar is only honest if the downloader
/// reports bytes *while* they arrive, so that is what this measures — against a
/// real socket, because the bug was in how the callbacks are wired to
/// `URLSession`, not in any logic above it.
final class ProgressiveDownloadTests: XCTestCase {

    func testReportsProgressWhileTheFileIsStillArriving() async throws {
        let byteCount = 4 * 1024 * 1024
        guard let port = PortAllocator.free(count: 1, from: 19500).first else {
            return XCTFail("no free port to test on")
        }
        let server = SlowFileServer(byteCount: byteCount, chunkSize: 32 * 1024)
        try server.start(port: UInt16(port))
        defer { server.stop() }

        let recorder = ProgressRecorder()
        let url = URL(string: "http://127.0.0.1:\(port)/payload.bin")!
        let file = try await ProgressiveDownload.download(from: url) { received, total in
            recorder.record(received: received, total: total)
        }
        defer { try? FileManager.default.removeItem(at: file) }

        let downloaded = try Data(contentsOf: file)
        XCTAssertEqual(downloaded.count, byteCount)

        let seen = recorder.samples
        XCTAssertGreaterThan(seen.count, 1,
                             "one sample is the same as none: the bar never moves")
        XCTAssertTrue(seen.contains { $0.received > 0 && $0.received < Int64(byteCount) },
                      "no sample landed mid-transfer, so progress was never reported")
        XCTAssertEqual(seen.last?.received, Int64(byteCount))
        XCTAssertEqual(seen.last?.total, Int64(byteCount),
                       "the expected size comes from the response, not from the caller")
    }
}

/// Collects what the downloader reported. `URLSession` calls back off the main
/// thread, so the samples are guarded.
private final class ProgressRecorder: @unchecked Sendable {
    struct Sample: Equatable {
        var received: Int64
        var total: Int64
    }

    private let lock = NSLock()
    private var storage: [Sample] = []

    var samples: [Sample] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }

    func record(received: Int64, total: Int64) {
        lock.lock(); defer { lock.unlock() }
        storage.append(Sample(received: received, total: total))
    }
}

/// Serves one fixed-size body in chunks, with a pause between them.
///
/// The pauses are the point: a body written in a single burst can be delivered
/// to `URLSession` as a single progress event even when the callbacks work, and
/// then the test would pass against the broken code too.
private final class SlowFileServer: @unchecked Sendable {
    private let byteCount: Int
    private let chunkSize: Int
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "veil.test.slow-file-server")

    init(byteCount: Int, chunkSize: Int) {
        self.byteCount = byteCount
        self.chunkSize = chunkSize
    }

    func start(port: UInt16) throws {
        let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        listener.newConnectionHandler = { [weak self] connection in
            self?.serve(connection)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func serve(_ connection: NWConnection) {
        connection.start(queue: queue)
        // Read the request line and headers, then answer. The content is the
        // same whatever was asked for.
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] _, _, _, _ in
            guard let self else { return }
            let header = """
            HTTP/1.1 200 OK\r
            Content-Length: \(byteCount)\r
            Content-Type: application/octet-stream\r
            Connection: close\r
            \r

            """
            connection.send(content: Data(header.utf8),
                            completion: .contentProcessed { _ in
                self.sendBody(on: connection, remaining: self.byteCount)
            })
        }
    }

    private func sendBody(on connection: NWConnection, remaining: Int) {
        guard remaining > 0 else {
            connection.send(content: nil, isComplete: true,
                            completion: .contentProcessed { _ in connection.cancel() })
            return
        }
        let size = min(chunkSize, remaining)
        let chunk = Data(repeating: 0x56, count: size)
        connection.send(content: chunk, completion: .contentProcessed { [weak self] _ in
            guard let self else { return }
            self.queue.asyncAfter(deadline: .now() + .milliseconds(8)) {
                self.sendBody(on: connection, remaining: remaining - size)
            }
        })
    }
}
#endif
