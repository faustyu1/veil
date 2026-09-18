import SwiftUI
import AppKit

/// Sets the title of the `NSWindow` a view is hosted in.
///
/// A scene's title is evaluated once, when the scene is built — which happens
/// before the app has applied the user's language, so `Window(loc("Routing"))`
/// always ended up in English. `.navigationTitle` only wins inside a
/// `NavigationStack`, and that stack costs a large title on a row of its own.
/// Reaching for the window directly keeps the titlebar on one line and still
/// says the right thing in the right language.
private struct WindowTitleSetter: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        apply(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        apply(from: nsView)
    }

    private func apply(from view: NSView) {
        let title = title
        // The view has no window on the first layout pass.
        DispatchQueue.main.async {
            view.window?.title = title
        }
    }
}

extension View {
    /// Names the window this view lives in, in the current language.
    func windowTitle(_ title: String) -> some View {
        background(WindowTitleSetter(title: title).frame(width: 0, height: 0))
    }
}
