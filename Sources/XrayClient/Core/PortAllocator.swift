// macOS-only.
#if os(macOS)
import Foundation

/// Finds free loopback TCP ports.
///
/// The bridge processes that front Xray-only nodes each need a port of their
/// own, and those ports end up written into a configuration the core is about
/// to load — so "ask the kernel for port 0" is no help here: the number has to
/// be known before anything binds it.
enum PortAllocator {

    /// `count` free ports at or above `base`, in ascending order.
    ///
    /// There is an unavoidable race between testing a port and the core
    /// binding it. It is narrow, and the alternative — handing sockets to a
    /// subprocess — is not worth the machinery for a fallback transport.
    static func free(count: Int, from base: Int, avoiding taken: Set<Int> = []) -> [Int] {
        var found: [Int] = []
        var candidate = max(1024, base)
        while found.count < count && candidate < 65535 {
            if !taken.contains(candidate) && !found.contains(candidate)
                && isAvailable(candidate) {
                found.append(candidate)
            }
            candidate += 1
        }
        return found
    }

    /// True when nothing is listening on the loopback at this port.
    static func isAvailable(_ port: Int) -> Bool {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }

        var reuse: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuse,
                   socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bound = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return bound == 0
    }
}
#endif
