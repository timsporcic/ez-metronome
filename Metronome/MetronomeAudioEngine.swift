import AVFoundation

/// Low-latency audio scheduler for the metronome click sounds.
///
/// The engine generates short PCM buffers in memory and schedules them on an
/// `AVAudioPlayerNode` slightly ahead of playback time. Scheduling ahead keeps
/// audio timing steady while still allowing tempo and accent changes to be read
/// between beats from provider closures.
@MainActor
final class MetronomeAudioEngine {
    /// AVFoundation graph that owns the player node and output path.
    private let engine = AVAudioEngine()

    /// Player node used for sample-accurate buffer scheduling.
    private let player = AVAudioPlayerNode()

    /// Sample rate used for generated click buffers and scheduling math.
    private let sampleRate = 44_100.0

    /// Amount of future audio, in seconds, to keep scheduled.
    private let lookAheadSeconds = 0.12

    /// Timer interval, in seconds, used to top up the scheduled beat queue.
    private let schedulerInterval = 0.025

    /// Short startup delay that gives the player a render time before beat one.
    private let firstBeatDelay = 0.06

    /// Mono output format shared by all generated buffers.
    private let outputFormat: AVAudioFormat

    /// Higher-pitched click used when the first beat is accented.
    private let downbeatBuffer: AVAudioPCMBuffer

    /// Standard click used for unaccented beats.
    private let beatBuffer: AVAudioPCMBuffer

    /// Initial silent buffer used to prime the player before scheduling clicks.
    private let silenceBuffer: AVAudioPCMBuffer

    /// Timer that periodically schedules additional beats.
    private var scheduler: Timer?

    /// Absolute player sample time for the next beat to schedule.
    private var nextSampleTime: AVAudioFramePosition?

    /// Zero-based beat count used to determine four-beat downbeats.
    private var beatIndex = 0

    /// Tracks whether the AVAudioEngine graph has been attached and connected.
    private var isConfigured = false

    /// Generates the click buffers and prepares the output format.
    init() {
        outputFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        downbeatBuffer = Self.makeClickBuffer(frequency: 1_500, format: outputFormat)
        beatBuffer = Self.makeClickBuffer(frequency: 1_000, format: outputFormat)
        silenceBuffer = Self.makeSilenceBuffer(duration: firstBeatDelay, format: outputFormat)
    }

    /// Starts audio playback and schedules the first batch of metronome beats.
    ///
    /// - Parameters:
    ///   - bpmProvider: Closure that returns the current tempo. It is evaluated
    ///     while scheduling each beat, so tempo changes apply during playback.
    ///   - accentProvider: Closure that returns whether beat one should use the
    ///     downbeat buffer.
    ///   - onBeat: Main-actor callback invoked when each scheduled beat should
    ///     be reflected in the UI.
    func start(
        bpmProvider: @escaping () -> Int,
        accentProvider: @escaping () -> Bool,
        onBeat: @escaping () -> Void
    ) {
        configureIfNeeded()
        stopScheduler()

        beatIndex = 0
        nextSampleTime = nil

        do {
            if !engine.isRunning {
                try engine.start()
            }
        } catch {
            return
        }

        player.stop()
        player.scheduleBuffer(silenceBuffer, at: nil, options: [])
        player.play()

        scheduler = Timer.scheduledTimer(withTimeInterval: schedulerInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.schedulePendingBeats(
                    bpmProvider: bpmProvider,
                    accentProvider: accentProvider,
                    onBeat: onBeat
                )
            }
        }

        scheduler?.tolerance = 0.005
        schedulePendingBeats(bpmProvider: bpmProvider, accentProvider: accentProvider, onBeat: onBeat)
    }

    /// Stops scheduling and playback, then resets scheduler position.
    func stop() {
        stopScheduler()
        nextSampleTime = nil
        beatIndex = 0
        player.stop()
    }

    /// Attaches and connects the player node the first time audio starts.
    private func configureIfNeeded() {
        guard !isConfigured else { return }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: outputFormat)
        isConfigured = true
    }

    /// Invalidates the scheduling timer.
    private func stopScheduler() {
        scheduler?.invalidate()
        scheduler = nil
    }

    /// Schedules all beats needed to fill the current look-ahead window.
    ///
    /// The player node accepts absolute sample times. This method translates the
    /// current BPM into sample intervals, picks the correct click buffer, and
    /// schedules a matching UI pulse for the same future offset.
    ///
    /// - Parameters:
    ///   - bpmProvider: Supplies the latest tempo value.
    ///   - accentProvider: Supplies the latest accent option.
    ///   - onBeat: Main-actor callback for the visual beat pulse.
    private func schedulePendingBeats(
        bpmProvider: () -> Int,
        accentProvider: () -> Bool,
        onBeat: @escaping () -> Void
    ) {
        guard player.isPlaying,
              let renderTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: renderTime)
        else {
            return
        }

        let currentSample = playerTime.sampleTime
        let lookAheadSamples = AVAudioFramePosition(lookAheadSeconds * sampleRate)

        if nextSampleTime == nil {
            nextSampleTime = currentSample + AVAudioFramePosition(firstBeatDelay * sampleRate)
        }

        while let scheduledSample = nextSampleTime, scheduledSample < currentSample + lookAheadSamples {
            let isDownbeat = accentProvider() && beatIndex % 4 == 0
            let buffer = isDownbeat ? downbeatBuffer : beatBuffer
            let when = AVAudioTime(sampleTime: scheduledSample, atRate: sampleRate)

            player.scheduleBuffer(buffer, at: when, options: [])

            let pulseDelay = max(0, Double(scheduledSample - currentSample) / sampleRate)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(pulseDelay * 1_000_000_000))
                onBeat()
            }

            let clampedBPM = min(Design.maxBPM, max(Design.minBPM, bpmProvider()))
            let intervalSamples = AVAudioFramePosition((60.0 / Double(clampedBPM)) * sampleRate)
            nextSampleTime = scheduledSample + intervalSamples
            beatIndex += 1
        }
    }

    /// Creates a short decaying square-wave click.
    ///
    /// - Parameters:
    ///   - frequency: Frequency, in hertz, for the click tone.
    ///   - format: Audio format for the returned buffer.
    /// - Returns: A PCM buffer containing the generated click.
    private static func makeClickBuffer(frequency: Double, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let duration = 0.06
        let decayEnd = 0.05
        let attackEnd = 0.001
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let samples = buffer.floatChannelData?[0] else {
            return buffer
        }

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / format.sampleRate
            let amplitude: Double

            if time < attackEnd {
                amplitude = 0.25 * (time / attackEnd)
            } else if time <= decayEnd {
                let progress = (time - attackEnd) / (decayEnd - attackEnd)
                amplitude = 0.25 * pow(0.0001 / 0.25, progress)
            } else {
                amplitude = 0
            }

            let phase = sin(2 * Double.pi * frequency * time)
            samples[frame] = Float((phase >= 0 ? 1 : -1) * amplitude)
        }

        return buffer
    }

    /// Creates a silent PCM buffer used to prime the player.
    ///
    /// - Parameters:
    ///   - duration: Length of the buffer in seconds.
    ///   - format: Audio format for the returned buffer.
    /// - Returns: A PCM buffer containing silence.
    private static func makeSilenceBuffer(duration: Double, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        return buffer
    }
}
