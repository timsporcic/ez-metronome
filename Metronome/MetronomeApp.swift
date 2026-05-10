import AppKit
import SwiftUI

/// Native macOS entry point for EZ Metronome.
///
/// The app uses an explicit AppKit lifecycle instead of SwiftUI's `App`
/// protocol so the main menu can stay stable while the metronome updates
/// SwiftUI state on every beat.
@main
@MainActor
private enum MetronomeMain {
    /// Configures the shared `NSApplication`, installs the delegate, and starts
    /// the AppKit run loop.
    static func main() {
        let app = NSApplication.shared
        let delegate = MetronomeAppDelegate()

        app.setActivationPolicy(.regular)
        app.delegate = delegate
        delegate.start()
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}

/// Owns the application-level objects that must live for the entire process.
///
/// The delegate creates one shared `MetronomeModel`, installs the static menu
/// bar, and hosts the SwiftUI content in a fixed-size `NSWindow`.
@MainActor
private final class MetronomeAppDelegate: NSObject, NSApplicationDelegate {
    /// Shared source of truth for tempo, run state, beat pulse, and options.
    private let model = MetronomeModel()

    /// Strong reference to the main application window.
    private var window: NSWindow?

    /// Builds and owns menu item targets for the custom app menu.
    private lazy var menuController = MetronomeMenuController(model: model)

    /// Prevents duplicate setup when `start()` is called manually and by AppKit.
    private var hasStarted = false

    /// Completes app startup if AppKit reaches the launch callback before
    /// manual startup has already run.
    ///
    /// - Parameter notification: The launch notification from `NSApplication`.
    func applicationDidFinishLaunching(_ notification: Notification) {
        start()
    }

    /// Performs one-time application setup.
    ///
    /// Call this before `NSApplication.run()` so the menu and window are present
    /// as soon as the app activates. The method is idempotent because AppKit may
    /// also call `applicationDidFinishLaunching(_:)`.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        FontRegistrar.registerBundledFonts()

        menuController.install()
        createWindow()
        NSApplication.shared.activate()
    }

    /// Requests process termination when the user closes the only window.
    ///
    /// - Parameter sender: The running application.
    /// - Returns: `true` so closing the main window exits the app.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Creates the fixed-size main window and embeds `ContentView`.
    private func createWindow() {
        let contentSize = NSSize(width: Design.windowWidth, height: Design.contentHeight)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        let fixedFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size

        window.title = "EZ Metronome"
        window.contentViewController = NSHostingController(rootView: ContentView(model: model))
        window.setContentSize(contentSize)
        window.minSize = fixedFrameSize
        window.maxSize = fixedFrameSize
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }
}

/// Builds the intentionally small macOS menu bar.
///
/// Keep this separate from SwiftUI view state. Rebuilding `NSApplication.mainMenu`
/// from a SwiftUI render path can cause the menu to flicker or temporarily show
/// default AppKit menus while the metronome is playing.
@MainActor
private final class MetronomeMenuController: NSObject {
    /// Model used by menu commands that change application options.
    private let model: MetronomeModel

    /// Menu item whose checkmark mirrors `MetronomeModel.accentFirstBeat`.
    private weak var accentItem: NSMenuItem?

    /// Creates a menu controller bound to the app model.
    ///
    /// - Parameter model: Shared model that backs menu commands.
    init(model: MetronomeModel) {
        self.model = model
    }

    /// Replaces the default AppKit menu with the custom Application, Options,
    /// and Help menus used by EZ Metronome.
    func install() {
        let mainMenu = NSMenu(title: "MainMenu")
        mainMenu.addItem(applicationMenuItem())
        mainMenu.addItem(optionsMenuItem())
        mainMenu.addItem(helpMenuItem())
        NSApplication.shared.mainMenu = mainMenu
    }

    /// Creates the application menu containing app visibility and Exit commands.
    ///
    /// - Returns: A top-level menu item with an application submenu.
    private func applicationMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "EZ Metronome")
        let hideItem = NSMenuItem(
            title: "Hide the Metronome",
            action: #selector(hideMetronome),
            keyEquivalent: "h"
        )
        let exitItem = NSMenuItem(title: "Exit", action: #selector(exitApplication), keyEquivalent: "q")

        hideItem.target = self
        menu.addItem(hideItem)
        menu.addItem(.separator())
        exitItem.target = self
        menu.addItem(exitItem)
        item.submenu = menu
        return item
    }

    /// Creates the Options menu and stores the accent menu item for later
    /// checkmark updates.
    ///
    /// - Returns: A top-level menu item with an Options submenu.
    private func optionsMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Options")
        let accentItem = NSMenuItem(
            title: "Accent First Beat",
            action: #selector(toggleAccentFirstBeat),
            keyEquivalent: ""
        )

        accentItem.target = self
        accentItem.state = model.accentFirstBeat ? .on : .off
        menu.addItem(accentItem)
        item.submenu = menu
        self.accentItem = accentItem
        return item
    }

    /// Creates the Help menu containing the app information dialog command.
    ///
    /// - Returns: A top-level menu item with a Help submenu.
    private func helpMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Help")
        let infoItem = NSMenuItem(
            title: "Application Information",
            action: #selector(showApplicationInformation),
            keyEquivalent: ""
        )

        infoItem.target = self
        menu.addItem(infoItem)
        item.submenu = menu
        return item
    }

    /// Handles the application menu's Exit command.
    @objc private func exitApplication() {
        NSApplication.shared.terminate(nil)
    }

    /// Handles the application menu's Hide command.
    @objc private func hideMetronome() {
        NSApplication.shared.hide(nil)
    }

    /// Toggles whether beat one in each four-beat group uses the accented click.
    @objc private func toggleAccentFirstBeat() {
        model.accentFirstBeat.toggle()
        accentItem?.state = model.accentFirstBeat ? .on : .off
    }

    /// Presents a minimal app information dialog with the marketing version and
    /// build number from the app bundle.
    @objc private func showApplicationInformation() {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        let alert = NSAlert()

        NSApplication.shared.activate()
        alert.messageText = "EZ Metronome"
        alert.informativeText = "Version \(version) (\(build))"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
