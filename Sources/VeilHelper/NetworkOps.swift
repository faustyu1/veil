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
    private static let pfctl = "/sbin/pfctl"
    private static let pfAnchor = "com.apple/veil"

    struct DefaultRoute {
        var gateway: String
        var interface: String
    }

    // MARK: - Routes

    /// Reads the current default route. Called before anything is changed, so
    /// the physical gateway can be restored later.
    static func defaultRoute(ipv6: Bool = false) -> DefaultRoute? {
        let family = ipv6 ? ["-inet6"] : []
        guard let output = run(route, ["-n", "get"] + family + ["default"]).stdout else { return nil }
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
        let family = HelperValidation.isIPv6(ip) ? ["-inet6"] : []
        if run(route, ["-n", "add"] + family + ["-host", ip, gateway]).status == 0 { return true }
        return run(route, ["-n", "change"] + family + ["-host", ip, gateway]).status == 0
    }

    @discardableResult
    static func deleteHostRoute(_ ip: String) -> Bool {
        let family = HelperValidation.isIPv6(ip) ? ["-inet6"] : []
        return run(route, ["-n", "delete"] + family + ["-host", ip]).status == 0
    }

    /// The two `/1` halves that override the default route without deleting it
    /// — a reversible way to capture all traffic.
    static let splitDefaultNets = TunnelRoutePolicy.ordinaryIPv4
    static let strictTunnelNets = TunnelRoutePolicy.strictTunnelIPv4
    static let ipv6ProtectionNets = TunnelRoutePolicy.protectedIPv6

    @discardableResult
    static func addSplitDefaults(gateway: String, strict: Bool) -> Bool {
        let nets = strict ? strictTunnelNets : splitDefaultNets
        var ok = true
        for net in nets {
            if run(route, ["-n", "add", "-net", net, gateway]).status != 0,
               run(route, ["-n", "change", "-net", net, gateway]).status != 0 { ok = false }
        }
        return ok
    }

    static func addStrictFallbacks() -> Bool {
        addRejectRoutes(splitDefaultNets, ipv6: false)
    }

    static func addIPv6Protection() -> Bool {
        addRejectRoutes(ipv6ProtectionNets, ipv6: true)
    }

    static func hasStrictFallbacks() -> Bool {
        hasRejectRoutes(splitDefaultNets, ipv6: false)
    }

    static func hasIPv6Protection() -> Bool {
        hasRejectRoutes(ipv6ProtectionNets, ipv6: true)
    }

    private static func addRejectRoutes(_ nets: [String], ipv6: Bool) -> Bool {
        let family = ipv6 ? ["-inet6"] : []
        let gateway = ipv6 ? "::1" : "127.0.0.1"
        var ok = true
        for net in nets {
            let result = run(route, ["-n", "add"] + family + ["-net", net, gateway, "-reject"])
            if result.status != 0 {
                let check = run(route, ["-n", "get"] + family + [net])
                let output = check.stdout ?? ""
                if check.status != 0 || !output.contains("REJECT") || !output.contains(gateway) {
                    ok = false
                }
            }
        }
        return ok
    }

    private static func hasRejectRoutes(_ nets: [String], ipv6: Bool) -> Bool {
        let family = ipv6 ? ["-inet6"] : []
        let gateway = ipv6 ? "::1" : "127.0.0.1"
        return nets.allSatisfy { net in
            let check = run(route, ["-n", "get"] + family + [net])
            let output = check.stdout ?? ""
            return check.status == 0 && output.contains("REJECT") && output.contains(gateway)
        }
    }

    static func removeSplitDefaults() {
        for net in splitDefaultNets + strictTunnelNets {
            _ = run(route, ["-n", "delete", "-net", net])
        }
    }

    static func removeActiveTunnelRoutes(strict: Bool) {
        for net in strict ? strictTunnelNets : splitDefaultNets {
            _ = run(route, ["-n", "delete", "-net", net])
        }
    }

    static func removeIPv6Protection() {
        for net in ipv6ProtectionNets {
            _ = run(route, ["-n", "delete", "-inet6", "-net", net])
        }
    }

    // MARK: - Packet-filter kill switch

    static func enableKillSwitch(physicalInterface: String, tunnelInterface: String,
                                 endpointIPs: [String]) -> String? {
        guard let rules = KillSwitchRules.render(physicalInterface: physicalInterface,
                                                 tunnelInterface: tunnelInterface,
                                                 endpointIPs: endpointIPs) else { return nil }
        guard pfAnchorIsAttached() else { return nil }
        let enabled = run(pfctl, ["-E"])
        guard enabled.status == 0, let output = enabled.stdout,
              let token = pfToken(from: output) else { return nil }
        guard run(pfctl, ["-a", pfAnchor, "-f", "-"], stdin: rules).status == 0 else {
            _ = run(pfctl, ["-X", token])
            return nil
        }
        return token
    }

    static func updateKillSwitch(physicalInterface: String, tunnelInterface: String,
                                 endpointIPs: [String]) -> Bool {
        guard let rules = KillSwitchRules.render(physicalInterface: physicalInterface,
                                                 tunnelInterface: tunnelInterface,
                                                 endpointIPs: endpointIPs) else { return false }
        return run(pfctl, ["-a", pfAnchor, "-f", "-"], stdin: rules).status == 0
    }

    static func disableKillSwitch(token: String?) {
        _ = run(pfctl, ["-a", pfAnchor, "-F", "rules"])
        if let token, token.allSatisfy({ $0.isNumber }) {
            _ = run(pfctl, ["-X", token])
        }
    }

    static func killSwitchIsLoaded() -> Bool {
        let result = run(pfctl, ["-a", pfAnchor, "-sr"])
        let info = run(pfctl, ["-s", "info"])
        return pfAnchorIsAttached()
            && result.status == 0
            && (result.stdout ?? "").contains("block drop out quick all")
            && (info.stdout ?? "").localizedCaseInsensitiveContains("status: enabled")
    }

    private static func pfAnchorIsAttached() -> Bool {
        let mainRules = run(pfctl, ["-sr"])
        let text = mainRules.stdout ?? ""
        return mainRules.status == 0
            && (text.contains(#"anchor "com.apple/*""#)
                || text.contains(#"anchor "com.apple/veil""#))
    }

    private static func pfToken(from output: String) -> String? {
        for line in output.split(separator: "\n")
            where String(line).localizedCaseInsensitiveContains("token") {
            let candidate = line.split(whereSeparator: { !$0.isNumber }).last.map(String.init)
            if let candidate, !candidate.isEmpty { return candidate }
        }
        return nil
    }

    // MARK: - Interface

    static func interfaceExists(_ device: String) -> Bool {
        run(ifconfig, [device]).status == 0
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
    static func run(_ executable: String, _ arguments: [String], stdin: String? = nil) -> Output {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let inputPipe = stdin.map { _ in Pipe() }
        process.standardInput = inputPipe
        do {
            try process.run()
        } catch {
            return Output(status: -1, stdout: nil)
        }
        if let stdin, let inputPipe {
            inputPipe.fileHandleForWriting.write(Data(stdin.utf8))
            try? inputPipe.fileHandleForWriting.close()
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Output(status: process.terminationStatus,
                      stdout: String(data: data, encoding: .utf8))
    }
}
