import VeilHelperKit
import Foundation

/// Every network change the helper is able to make, as typed calls.
///
/// Each one runs a fixed absolute executable with an argument array — there is
/// no shell anywhere in the helper, so quoting, globbing and `$(…)` simply do
/// not exist as a class of bug.
enum NetworkOps {

    private static let route = "/sbin/route"
    private static let ifconfig = "/sbin/ifconfig"
    private static let networksetup = "/usr/sbin/networksetup"

    struct DefaultRoute {
        var gateway: String
        var interface: String
    }

    // MARK: - Routes

    /// Reads the current default route. Called before anything is changed, so
    /// the physical gateway can be restored later.
    static func defaultRoute() -> DefaultRoute? {
        guard let output = run(route, ["-n", "get", "default"]).stdout else { return nil }
        var gateway: String?
        var interface: String?
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            if key == "gateway" { gateway = value }
            if key == "interface" { interface = value }
        }
        guard let gateway, let interface else { return nil }
        return DefaultRoute(gateway: gateway, interface: interface)
    }

    @discardableResult
    static func addHostRoute(_ ip: String, gateway: String) -> Bool {
        if run(route, ["-n", "add", "-host", ip, gateway]).status == 0 { return true }
        return run(route, ["-n", "change", "-host", ip, gateway]).status == 0
    }

    @discardableResult
    static func deleteHostRoute(_ ip: String) -> Bool {
        run(route, ["-n", "delete", "-host", ip]).status == 0
    }

    /// The two `/1` halves that override the default route without deleting it
    /// — a reversible way to capture all traffic.
    static let splitDefaultNets = ["0.0.0.0/1", "128.0.0.0/1"]

    @discardableResult
    static func addSplitDefaults(gateway: String) -> Bool {
        var ok = true
        for net in splitDefaultNets {
            if run(route, ["-n", "add", "-net", net, gateway]).status != 0 { ok = false }
        }
        return ok
    }

    static func removeSplitDefaults() {
        for net in splitDefaultNets {
            _ = run(route, ["-n", "delete", "-net", net])
        }
    }

    // MARK: - Interface

    static func interfaceExists(_ device: String) -> Bool {
        run(ifconfig, [device]).status == 0
    }

    /// Every tunnel device currently on the machine.
    ///
    /// The core picks its own `utunN`, so "did the tunnel come up" is answered
    /// by watching for a device that was not there a moment ago.
    static func tunnelDevices() -> Set<String> {
        // Read the interface list directly: this is polled while the core
        // starts, and forking `ifconfig` every 50 ms to answer it would cost
        // more than the wait it is shortening.
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return [] }
        defer { freeifaddrs(addresses) }
        var found: Set<String> = []
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let name = String(cString: entry.pointee.ifa_name)
            if name.hasPrefix("utun") { found.insert(name) }
        }
        return found
    }

    @discardableResult
    static func configureInterface(_ device: String, address: String,
                                   peer: String, mtu: Int) -> Bool {
        guard run(ifconfig, [device, address, peer, "up"]).status == 0 else { return false }
        _ = run(ifconfig, [device, "mtu", String(mtu)])
        return true
    }

    // MARK: - DNS

    /// Network services, minus the disabled ones macOS marks with a `*`.
    static func networkServices() -> [String] {
        guard let output = run(networksetup, ["-listallnetworkservices"]).stdout else { return [] }
        return output.split(separator: "\n")
            .dropFirst()                       // header line
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("*") }
    }

    /// Current resolvers for a service, or an empty array when it has none.
    static func dnsServers(for service: String) -> [String] {
        guard let output = run(networksetup, ["-getdnsservers", service]).stdout else { return [] }
        let lines = output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        // When a service has no resolvers of its own, networksetup answers with
        // a sentence rather than a list.
        guard lines.allSatisfy({ HelperValidation.isIPv4($0) || $0.contains(":") }),
              !lines.isEmpty else { return [] }
        return lines.filter { !$0.isEmpty }
    }

    @discardableResult
    static func setDNSServers(_ servers: [String], for service: String) -> Bool {
        let argument = servers.isEmpty ? ["Empty"] : servers
        return run(networksetup, ["-setdnsservers", service] + argument).status == 0
    }

    // MARK: - Process plumbing

    struct Output {
        var status: Int32
        var stdout: String?
    }

    @discardableResult
    static func run(_ executable: String, _ arguments: [String]) -> Output {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return Output(status: -1, stdout: nil)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Output(status: process.terminationStatus,
                      stdout: String(data: data, encoding: .utf8))
    }
}
