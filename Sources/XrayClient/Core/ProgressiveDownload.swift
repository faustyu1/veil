// macOS-only: used by the updater to fetch a release archive.
#if os(macOS)
import Foundation

/// Downloads a file and says how far it has got while it is still arriving.
///
/// The obvious spelling — `URLSession.download(from:delegate:)` with a
/// per-task delegate — compiles, runs, and never calls back: the task-specific
/// delegate does not receive `didWriteData` for the async download API, so the
/// progress bar sat at zero for the whole transfer. A session that owns its
/// delegate does deliver them, which is why the session is built here rather
/// than shared.
enum ProgressiveDownload {

    /// Downloads `url` to a temporary file the caller owns, reporting bytes
    /// received and the total the server declared as they arrive.
    ///
    /// The returned file is not cleaned up by anything else; the caller either
    /// moves it or deletes it.
    static func download(
        from url: URL,
        onProgress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws -> URL {
        let collector = Collector(onProgress: onProgress)
        // `delegateQueue: nil` gives the session a serial queue of its own, so
        // the callbacks never contend with the main actor.
        let session = URLSession(configuration: .default,
                                 delegate: collector, delegateQueue: nil)
        // The session holds its delegate strongly until it is invalidated,
        // which is the retain cycle every URLSession delegate has to break.
        defer { session.finishTasksAndInvalidate() }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                collector.begin(continuation)
                let task = session.downloadTask(with: url)
                collector.adopt(task)
                task.resume()
            }
        } onCancel: {
            collector.cancel()
        }
    }

    enum Failure: LocalizedError {
        case http(Int)
        case noFile

        var errorDescription: String? {
            switch self {
            case .http(let code): return "Download failed (\(code))"
            case .noFile:         return "The download produced no file"
            }
        }
    }
}

/// Bridges one download task's delegate callbacks to one continuation.
///
/// `URLSession` calls this off the main actor and may call more than one
/// terminal method for the same task, so the continuation is resumed exactly
/// once under a lock.
private final class Collector: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Int64, Int64) -> Void
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL, Error>?
    private var task: URLSessionTask?

    init(onProgress: @escaping @Sendable (Int64, Int64) -> Void) {
        self.onProgress = onProgress
    }

    func begin(_ continuation: CheckedContinuation<URL, Error>) {
        lock.lock(); defer { lock.unlock() }
        self.continuation = continuation
    }

    func adopt(_ task: URLSessionTask) {
        lock.lock(); defer { lock.unlock() }
        self.task = task
    }

    func cancel() {
        lock.lock()
        let task = self.task
        lock.unlock()
        task?.cancel()
    }

    private func finish(_ result: Result<URL, Error>) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        guard let pending else { return }
        switch result {
        case .success(let url): pending.resume(returning: url)
        case .failure(let error): pending.resume(throwing: error)
        }
    }

    // MARK: URLSessionDownloadDelegate

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        onProgress(totalBytesWritten, max(0, totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        if let http = downloadTask.response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            return finish(.failure(ProgressiveDownload.Failure.http(http.statusCode)))
        }
        // The file at `location` is deleted as soon as this returns, so the
        // move happens here rather than anywhere more convenient.
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("veil-download-\(UUID().uuidString)")
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            finish(.success(destination))
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let error {
            finish(.failure(error))
        } else {
            // A success has already resumed the continuation; this only fires
            // when the body never reached `didFinishDownloadingTo`.
            finish(.failure(ProgressiveDownload.Failure.noFile))
        }
    }
}
#endif
