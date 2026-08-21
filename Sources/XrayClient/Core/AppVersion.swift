import Foundation

/// The app's marketing version, read from the bundle so it always matches the
/// released build. The `VERSION` file at the repository root is the single
/// source that feeds it: `Scripts/set-version.sh` writes that number into the
/// macOS bundle's Info.plist and the Xcode project's `MARKETING_VERSION`.
enum AppVersion {

    /// e.g. `1.3.0`. Falls back to `0.0.0-dev` when running outside a bundle
    /// (a bare `swift run`, or a unit test host).
    static let current: String = {
        let value = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        guard let value, !value.isEmpty else { return "0.0.0-dev" }
        return value
    }()
}
