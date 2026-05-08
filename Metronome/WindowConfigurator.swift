import AppKit
import SwiftUI

/// SwiftUI bridge for configuring an AppKit window from a view hierarchy.
///
/// The current app lifecycle creates and configures the window directly in
/// `MetronomeAppDelegate`. This representable is kept as a reusable helper if a
/// future version returns to a SwiftUI `App` lifecycle.
struct WindowConfigurator: NSViewRepresentable {
    /// Creates an invisible view and configures its window after attachment.
    ///
    /// - Parameter context: SwiftUI representable context.
    /// - Returns: A placeholder AppKit view.
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    /// Reapplies window constraints when SwiftUI updates the representable.
    ///
    /// - Parameters:
    ///   - nsView: Existing placeholder AppKit view.
    ///   - context: SwiftUI representable context.
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    /// Applies title, content size, fixed frame limits, and zoom-button state.
    ///
    /// - Parameter window: Window to configure, if the placeholder view has
    ///   already been attached to one.
    private func configure(window: NSWindow?) {
        guard let window else { return }

        let contentSize = NSSize(width: Design.windowWidth, height: Design.contentHeight)
        let fixedFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size

        window.title = "EZ Metronome"
        window.setContentSize(contentSize)
        window.minSize = fixedFrameSize
        window.maxSize = fixedFrameSize
        window.styleMask.remove(.resizable)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
    }
}
