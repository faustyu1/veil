import Foundation
import Observation

/// TCP-connect latency tester. Measures time to establish a TCP connection to
/// each server's address:port — a good proxy for reachability + RTT without
/// needing the full proxy handshake.
@MainActor
@Observable
final class PingTester {
    /// Latency in milliseconds per server id. nil value = unreachable/timeout.
    private(set) var results: [UUID: Int?] = [:]
    /// Server ids currently being tested.
    private(set) var testing: Set<UUID> = []

    /// Test a batch of servers concurrently (bounded), updating results live.
    /// When `tunActive` is true, host-routes are added first so probes bypass
    /// the tunnel and measure real RTT (then cleaned up afterwards).
    func test(_ servers: [ProxyConfig], tunActive: Bool = false, timeout: TimeInterval = 3.0) {
        for s in servers { testing.insert(s.id) }
        let targets = servers.map { ($0.id, $0.address, $0.port) }

        Task.detached(priority: .userInitiated) {
            // Resolve hostnames to IPs and pin them off the tunnel for the test.
            var pinnedIPs: [String] = []
            if tunActive {
                for (_, host, _) in targets {
                    pinnedIPs.append(contentsOf: TunManager.resolveIPs(host: host))
                }
                await MainActor.run { TunManager.pingRouteAdd(pinnedIPs) }
                // Give the routing table a moment to settle.
                try? await Task.sleep(nanoseconds: 200_000_000)
            }

            await withTaskGroup(of: (UUID, Int?).self) { group in
                let maxConcurrent = 16
                var iterator = targets.makeIterator()

                func addNext(_ group: inout TaskGroup<(UUID, Int?)>) {
                    guard let (id, host, port) = iterator.next() else { return }
                    group.addTask {
                        let ms = await PingTester.tcpLatency(host: host, port: port, timeout: timeout)
                        return (id, ms)
                    }
                }

                for _ in 0..<maxConcurrent { addNext(&group) }
                while let (id, ms) = await group.next() {
                    await MainActor.run {
                        self.results[id] = .some(ms)
                        self.testing.remove(id)
                    }
                    addNext(&group)
                }
            }

            if tunActive {
                await MainActor.run { TunManager.pingRouteDel() }
            }
        }
    }

    func latency(for id: UUID) -> Int?? {
        results[id]
    }

    func isTesting(_ id: UUID) -> Bool { testing.contains(id) }

    func clear() {
        results.removeAll()
        testing.removeAll()
    }

    // MARK: - Low-level TCP connect timing

    /// Returns latency in ms, or nil on failure/timeout. Runs off the main actor.
    nonisolated static func tcpLatency(host: String, port: Int, timeout: TimeInterval) async -> Int? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let ms = blockingTCPLatency(host: host, port: port, timeout: timeout)
                continuation.resume(returning: ms)
            }
        }
    }

    private nonisolated static func blockingTCPLatency(host: String, port: Int, timeout: TimeInterval) -> Int? {
        var hints = addrinfo(ai_flags: 0, ai_family: AF_UNSPEC, ai_socktype: SOCK_STREAM,
                             ai_protocol: IPPROTO_TCP, ai_addrlen: 0,
                             ai_canonname: nil, ai_addr: nil, ai_next: nil)
        var info: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, String(port), &hints, &info) == 0, let addr = info else {
            return nil
        }
        defer { freeaddrinfo(info) }

        let fd = socket(addr.pointee.ai_family, addr.pointee.ai_socktype, addr.pointee.ai_protocol)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        // Non-blocking connect with select() for a precise timeout.
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        let start = DispatchTime.now()
        let res = connect(fd, addr.pointee.ai_addr, addr.pointee.ai_addrlen)
        if res == 0 {
            return elapsedMs(from: start)
        }
        if errno != EINPROGRESS { return nil }

        var writeSet = fd_set()
        fdZero(&writeSet)
        fdSet(fd, &writeSet)
        var tv = timeval(tv_sec: Int(timeout), tv_usec: Int32((timeout - floor(timeout)) * 1_000_000))

        let sel = select(fd + 1, nil, &writeSet, nil, &tv)
        guard sel > 0 else { return nil } // timeout or error

        // Confirm the connection actually succeeded.
        var soError: Int32 = 0
        var len = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(fd, SOL_SOCKET, SO_ERROR, &soError, &len)
        guard soError == 0 else { return nil }

        return elapsedMs(from: start)
    }

    private nonisolated static func elapsedMs(from start: DispatchTime) -> Int {
        let ns = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
        // Round to nearest ms, but never report 0 for a successful connect.
        return max(1, Int((Double(ns) / 1_000_000.0).rounded()))
    }
}

// MARK: - fd_set helpers (Darwin doesn't expose FD_SET/FD_ZERO to Swift)

private func fdZero(_ set: inout fd_set) {
    set.fds_bits = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

private func fdSet(_ fd: Int32, _ set: inout fd_set) {
    let intOffset = Int(fd) / 32
    let bitOffset = Int(fd) % 32
    let mask = Int32(1 << bitOffset)
    withUnsafeMutablePointer(to: &set.fds_bits) { ptr in
        ptr.withMemoryRebound(to: Int32.self, capacity: 32) { bits in
            bits[intOffset] |= mask
        }
    }
}
