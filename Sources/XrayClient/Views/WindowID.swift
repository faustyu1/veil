import Foundation

/// Identifiers for the app's auxiliary windows, in one place so a scene and the
/// `openWindow` call that shows it can never drift apart.
enum WindowID {
    static let main = "main"
    static let about = "about"
    static let update = "update"
    static let routing = "routing"
    static let settings = "settings"
}
