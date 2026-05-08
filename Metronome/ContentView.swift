import AppKit
import SwiftUI

/// Main SwiftUI interface for the fixed-size metronome window.
///
/// The view is intentionally stateless beyond its observed model. All tempo,
/// playback, beat pulse, and option changes flow through `MetronomeModel`.
struct ContentView: View {
    /// Shared model that drives UI state and user actions.
    @ObservedObject var model: MetronomeModel

    /// Builds the metronome controls: tempo nudges, LCD display, quick tempos,
    /// start/stop button, and keyboard shortcuts.
    var body: some View {
        ZStack {
            LinearGradient.vertical(Design.bodyTop, Design.bodyBottom)

            VStack(spacing: 18) {
                HStack(spacing: 14) {
                    NudgeButton(symbol: "−", accessibilityLabel: "Decrease tempo") {
                        model.decrementBPM()
                    }

                    LCDDisplay(value: model.bpm, beatPulse: model.beatPulse)

                    NudgeButton(symbol: "+", accessibilityLabel: "Increase tempo") {
                        model.incrementBPM()
                    }
                }
                .frame(height: 100)

                HStack(spacing: 7) {
                    ForEach(Design.quickTempos, id: \.self) { tempo in
                        QuickTempoButton(value: tempo, active: model.bpm == tempo) {
                            model.setBPM(tempo)
                        }
                    }
                }
                .frame(height: 36)

                StartStopButton(running: model.isRunning) {
                    model.toggleRunning()
                }
                .frame(height: 48)
            }
            .padding(.top, 20)
            .padding(.horizontal, Design.bodyHorizontalPadding)
            .padding(.bottom, 22)
        }
        .frame(width: Design.windowWidth, height: Design.contentHeight)
        .background(
            KeyboardEventView(
                onSpace: { model.toggleRunning() },
                onUp: { model.incrementBPM() },
                onDown: { model.decrementBPM() }
            )
        )
    }
}

/// LCD-style tempo display with a small beat indicator.
private struct LCDDisplay: View {
    /// Tempo value shown in the display.
    let value: Int

    /// Whether the beat indicator should appear lit for the current frame.
    let beatPulse: Bool

    /// Draws the layered LCD background, static labels, beat indicator, and
    /// seven-segment-style tempo value.
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient.vertical(Design.lcdTopBottom, Design.lcdMiddle, Design.lcdTopBottom))
                .shadow(color: .white.opacity(0.60), radius: 0, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.black.opacity(0.14), lineWidth: 0.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.black.opacity(0.22), lineWidth: 2)
                        .blur(radius: 3)
                        .mask(RoundedRectangle(cornerRadius: 14, style: .continuous))
                )

            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.18), location: 0),
                    .init(color: .white.opacity(0), location: 0.35),
                    .init(color: .white.opacity(0), location: 0.65),
                    .init(color: .black.opacity(0.06), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack {
                lcdLabel("TEMPO")
                Spacer()
                lcdLabel("BPM")
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            Circle()
                .fill(Design.lcdMark.opacity(beatPulse ? 0.85 : 0.18))
                .frame(width: 7, height: 7)
                .padding(.top, 7)
                .animation(.easeOut(duration: 0.06), value: beatPulse)

            VStack {
                Spacer().frame(height: 28)
                ZStack(alignment: .trailing) {
                    Text("888")
                        .foregroundStyle(Design.lcdGhost)
                    Text(String(value))
                        .foregroundStyle(Design.lcdLive)
                        .shadow(color: .white.opacity(0.15), radius: 0, x: 0, y: 1)
                }
                .font(.custom("DSEG7Classic-Bold", size: 56))
                .lineSpacing(0)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 4)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
        }
    }

    /// Creates one of the small fixed LCD captions.
    ///
    /// - Parameter text: Caption text to render.
    /// - Returns: Styled caption text.
    private func lcdLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(Design.lcdMark.opacity(0.55))
    }
}

/// Circular tempo adjustment button.
///
/// Holding the button repeats the action at an accelerating interval; releasing
/// the button performs one final action so quick taps still change by one BPM.
private struct NudgeButton: View {
    /// Symbol rendered in the button, usually plus or minus.
    let symbol: String

    /// Accessibility label that describes the button action.
    let accessibilityLabel: String

    /// Action to perform for each nudge.
    let action: () -> Void

    /// Tracks the pressed visual state while the pointer is down.
    @State private var isPressed = false

    /// Repeating task used while the button is held.
    @State private var holdTask: Task<Void, Never>?

    /// Draws the circular button and attaches press-and-hold gesture handling.
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient.vertical(
                        isPressed ? Design.nudgePressedTop : Design.nudgeTop,
                        isPressed ? Design.nudgePressedBottom : Design.nudgeBottom
                    )
                )
                .shadow(color: .black.opacity(isPressed ? 0 : 0.18), radius: 5, x: 0, y: 2)
                .overlay(Circle().stroke(.white.opacity(isPressed ? 0.40 : 0.85), lineWidth: 1).offset(y: -0.5))
                .overlay(Circle().stroke(.black.opacity(0.18), lineWidth: 0.5))
                .overlay(
                    Circle()
                        .stroke(.black.opacity(isPressed ? 0.22 : 0.08), lineWidth: isPressed ? 4 : 1)
                        .blur(radius: isPressed ? 2 : 0)
                        .mask(Circle())
                )

            Text(symbol)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Design.primaryText)
                .offset(y: symbol == "−" ? -2 : -1)
        }
        .frame(width: 56, height: 56)
        .offset(y: isPressed ? 0.5 : 0)
        .contentShape(Circle())
        .accessibilityLabel(accessibilityLabel)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    isPressed = true
                    startHold()
                }
                .onEnded { _ in
                    isPressed = false
                    stopHold()
                    action()
                }
        )
        .onDisappear(perform: stopHold)
    }

    /// Starts the accelerating repeat loop for press-and-hold tempo changes.
    private func startHold() {
        guard holdTask == nil else { return }

        holdTask = Task { @MainActor in
            var delay = 380_000_000.0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(delay))
                guard !Task.isCancelled else { break }
                action()
                delay = max(35_000_000.0, delay * 0.82)
            }
        }
    }

    /// Cancels the press-and-hold repeat loop.
    private func stopHold() {
        holdTask?.cancel()
        holdTask = nil
    }
}

/// Small preset tempo button used in the quick-tempo row.
private struct QuickTempoButton: View {
    /// Tempo value assigned when the button is pressed.
    let value: Int

    /// Whether this button matches the current tempo.
    let active: Bool

    /// Action to run when the button is pressed.
    let action: () -> Void

    /// Tracks hover state for the button's subtle highlight.
    @State private var isHovering = false

    /// Draws the preset tempo button with active and hover styling.
    var body: some View {
        Button(action: action) {
            Text(String(value))
                .font(.system(size: 14, weight: .semibold))
                .tracking(0.2)
                .foregroundStyle(active ? .white : Design.primaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(quickGradient)
                .shadow(color: .black.opacity(active ? 0.18 : 0.10), radius: active ? 2 : 1.5, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(.white.opacity(active ? 0.35 : 0.85), lineWidth: 1)
                        .offset(y: -0.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(.black.opacity(active ? 0.25 : 0.16), lineWidth: 0.5)
                )
        )
        .frame(maxWidth: .infinity)
        .onHover { isHovering = $0 }
    }

    /// Gradient selected from active, hover, and idle states.
    private var quickGradient: LinearGradient {
        if active {
            return .vertical(Design.quickActiveTop, Design.quickActiveBottom)
        }

        return isHovering
            ? .vertical(Design.quickHoverTop, Design.quickHoverBottom)
            : .vertical(Design.quickTop, Design.quickBottom)
    }
}

/// Large transport button that starts or stops the metronome.
private struct StartStopButton: View {
    /// Whether playback is currently running.
    let running: Bool

    /// Action to run when the button is pressed.
    let action: () -> Void

    /// Tracks hover state for brighter button styling.
    @State private var isHovering = false

    /// Tracks pressed state for inset button styling.
    @State private var isPressed = false

    /// Draws the start/stop control with the appropriate icon and color.
    var body: some View {
        HStack(spacing: 9) {
            if running {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(.white)
                    .frame(width: 10, height: 10)
            } else {
                PlayTriangle()
                    .fill(.white)
                    .frame(width: 14, height: 14)
                    .offset(x: 1)
            }

            Text(running ? "Stop" : "Start")
                .font(.system(size: 17, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: -1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(buttonGradient)
                .shadow(color: .black.opacity(isPressed ? 0 : 0.22), radius: 5, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(.white.opacity(isPressed ? 0 : 0.45), lineWidth: 1)
                        .offset(y: -0.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(.black.opacity(0.30), lineWidth: 0.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(.black.opacity(isPressed ? 0.30 : 0.22), lineWidth: isPressed ? 5 : 1)
                        .blur(radius: isPressed ? 2 : 0)
                        .mask(RoundedRectangle(cornerRadius: 11, style: .continuous))
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in
                    isPressed = false
                    action()
                }
        )
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: running)
    }

    /// Gradient selected from running, hover, and idle states.
    private var buttonGradient: LinearGradient {
        if running {
            return isHovering
                ? .vertical(Design.stopHoverTop, Design.stopHoverBottom)
                : .vertical(Design.stopTop, Design.stopBottom)
        }

        return isHovering
            ? .vertical(Design.startHoverTop, Design.startHoverBottom)
            : .vertical(Design.startTop, Design.startBottom)
    }
}

/// Simple play icon used inside `StartStopButton`.
private struct PlayTriangle: Shape {
    /// Builds a right-facing triangle that fills the provided rectangle.
    ///
    /// - Parameter rect: Drawing bounds supplied by SwiftUI.
    /// - Returns: Path for the play icon.
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 1, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + 1, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Invisible AppKit view used to capture keyboard shortcuts from SwiftUI.
///
/// SwiftUI keyboard shortcut handling can be awkward in a custom AppKit-hosted
/// window. This representable installs an `NSView` that becomes first responder
/// and forwards space/up/down key presses to closures.
private struct KeyboardEventView: NSViewRepresentable {
    /// Called when the space bar is pressed.
    let onSpace: () -> Void

    /// Called when the up-arrow key is pressed.
    let onUp: () -> Void

    /// Called when the down-arrow key is pressed.
    let onDown: () -> Void

    /// Creates the key-capture view and assigns the initial callbacks.
    ///
    /// - Parameter context: SwiftUI representable context.
    /// - Returns: AppKit view that can become first responder.
    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onSpace = onSpace
        view.onUp = onUp
        view.onDown = onDown
        return view
    }

    /// Refreshes callbacks and asks the window to make the capture view first
    /// responder after SwiftUI updates.
    ///
    /// - Parameters:
    ///   - nsView: Existing key-capture view.
    ///   - context: SwiftUI representable context.
    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.onSpace = onSpace
        nsView.onUp = onUp
        nsView.onDown = onDown

        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    /// First-responder view that maps macOS key codes to metronome actions.
    final class KeyCaptureView: NSView {
        /// Callback for space-bar presses.
        var onSpace: () -> Void = {}

        /// Callback for up-arrow presses.
        var onUp: () -> Void = {}

        /// Callback for down-arrow presses.
        var onDown: () -> Void = {}

        /// Allows the view to become first responder and receive key events.
        override var acceptsFirstResponder: Bool { true }

        /// Reclaims first-responder status after the view is attached to a
        /// window.
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async {
                self.window?.makeFirstResponder(self)
            }
        }

        /// Handles supported shortcut keys and forwards all others to AppKit.
        ///
        /// - Parameter event: Key-down event from AppKit.
        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 49:
                onSpace()
            case 126:
                onUp()
            case 125:
                onDown()
            default:
                super.keyDown(with: event)
            }
        }
    }
}
