import Combine
import Foundation

/// Main-actor state model for the metronome UI and audio engine.
///
/// `MetronomeModel` is the single source of truth for user-editable tempo,
/// play/stop state, transient beat animation state, and the accent option. The
/// SwiftUI view observes this object, while the audio engine reads values
/// through provider closures so tempo and accent changes take effect while
/// playback is running.
@MainActor
final class MetronomeModel: ObservableObject {
    /// Current tempo in beats per minute.
    ///
    /// Assignments are clamped to `Design.minBPM...Design.maxBPM`. Use
    /// `setBPM(_:)`, `incrementBPM()`, or `decrementBPM()` when changing tempo
    /// from UI controls so all callers share the same range behavior.
    @Published var bpm: Int = 120 {
        didSet {
            let clamped = Self.clamp(bpm)
            if bpm != clamped {
                bpm = clamped
            }
        }
    }

    /// Indicates whether the metronome is actively scheduling audio clicks.
    @Published private(set) var isRunning = false

    /// Short-lived UI pulse flipped on each scheduled beat.
    ///
    /// `ContentView` uses this to light the display dot. It resets shortly after
    /// each beat in `flashBeat()`.
    @Published private(set) var beatPulse = false

    /// Controls whether the first beat of each four-beat group uses the higher
    /// pitched downbeat click.
    @Published var accentFirstBeat = true

    /// Audio scheduler responsible for generating and playing click buffers.
    private let audioEngine = MetronomeAudioEngine()

    /// Task that clears `beatPulse` after the visible flash duration.
    private var pulseResetTask: Task<Void, Never>?

    deinit {
        pulseResetTask?.cancel()
    }

    /// Raises the tempo by one BPM, respecting the configured maximum.
    func incrementBPM() {
        bpm = Self.clamp(bpm + 1)
    }

    /// Lowers the tempo by one BPM, respecting the configured minimum.
    func decrementBPM() {
        bpm = Self.clamp(bpm - 1)
    }

    /// Sets the tempo to an explicit value after clamping it into range.
    ///
    /// - Parameter value: Requested tempo in beats per minute.
    func setBPM(_ value: Int) {
        bpm = Self.clamp(value)
    }

    /// Starts playback when stopped, or stops playback when running.
    func toggleRunning() {
        isRunning ? stop() : start()
    }

    /// Starts the metronome and begins scheduling clicks.
    ///
    /// The engine receives closures instead of fixed values so BPM and accent
    /// changes are picked up between scheduled beats without restarting audio.
    func start() {
        guard !isRunning else { return }

        isRunning = true
        beatPulse = false

        audioEngine.start(
            bpmProvider: { [weak self] in self?.bpm ?? 120 },
            accentProvider: { [weak self] in self?.accentFirstBeat ?? true },
            onBeat: { [weak self] in self?.flashBeat() }
        )
    }

    /// Stops playback, cancels pending UI pulse reset work, and clears the
    /// visible beat indicator.
    func stop() {
        guard isRunning else { return }

        isRunning = false
        audioEngine.stop()
        pulseResetTask?.cancel()
        pulseResetTask = nil
        beatPulse = false
    }

    /// Turns on the visible beat pulse briefly for the current beat.
    ///
    /// A new beat cancels the previous reset task so fast tempos do not leave
    /// older tasks racing to turn the pulse off.
    private func flashBeat() {
        guard isRunning else { return }

        beatPulse = true
        pulseResetTask?.cancel()
        pulseResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }
            self?.beatPulse = false
        }
    }

    /// Clamps a tempo to the supported BPM range.
    ///
    /// - Parameter value: Requested tempo in beats per minute.
    /// - Returns: `value` limited to `Design.minBPM...Design.maxBPM`.
    private static func clamp(_ value: Int) -> Int {
        min(Design.maxBPM, max(Design.minBPM, value))
    }
}
