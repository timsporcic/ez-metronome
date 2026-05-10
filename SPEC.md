# Handoff: EZ Metronome (macOS)

## Overview
A simple, native-feeling macOS metronome utility. The window shows a 3-digit LCD-style tempo display flanked by minus/plus nudge buttons, a row of six quick-tempo presets, and a single Start/Stop button at the bottom. While running, the metronome emits an audible click on every beat (with an accented downbeat every 4) and a small dot in the LCD pulses in time with the click.

The intended target is a **native macOS application built in Xcode**, most naturally implemented in **SwiftUI** with **AVAudioEngine** (or `AVAudioPlayer` with pre-rendered click samples) for audio.

## About the Design Files
The files in `reference/` are **design references created in HTML/React** — prototypes showing intended look and behavior, not production code to copy directly. The job is to **recreate the design natively in SwiftUI** (or AppKit) using the platform's standard idioms — system fonts (`.system`), native window chrome, `NSSound` / `AVAudioEngine` for click playback, etc. Use the HTML prototype as the visual source of truth for layout, sizing, color, and interaction behavior.

If the project is brand-new, scaffold a standard macOS App target in Xcode (SwiftUI lifecycle, deployment target macOS 13+ recommended for modern SwiftUI affordances).

## Fidelity
**High-fidelity.** The mocks specify exact pixel sizes, hex colors, font sizes, gradients, and shadow values. A native rebuild should match these visually — though native traffic lights, native window chrome, and the system font rendering should be used in place of the HTML approximations. Spacing and proportions should match exactly.

## Screens / Views

There is a single window: **MetronomeWindow**.

### Layout (window-level)
- Window: fixed-size, non-resizable, **420 pt wide × ~330 pt tall** (final height determined by content + title bar).
- Window style: standard macOS window with traffic lights. The HTML reference draws its own title bar at 38 pt; in a native build, **use the real macOS title bar** (`NSWindow` default with title "EZ Metronome"). Don't recreate the traffic lights manually.
- Body padding: **20 pt top / 22 pt sides / 22 pt bottom**.
- Body background: vertical gradient `#ECEAD8 → #E3E0C8` (warm off-white, slightly green).

### Body sections (top → bottom, 18 pt vertical gap between sections)

#### 1. LCD row
A horizontal row containing: `[ − button ]  [ LCD display, flex ]  [ + button ]`, with **14 pt gap** between elements.

##### Nudge buttons (− and +)
- Circular, **56 × 56 pt**, `border-radius: 50%`.
- Resting fill: vertical gradient `#FBFAF6 → #E3DDD2`.
- Pressed fill: vertical gradient `#D8D3CB → #EBE5DB`.
- Resting shadow stack:
  - `0 2pt 5pt rgba(0,0,0,0.18)` (drop)
  - `inset 0 1pt 0 rgba(255,255,255,0.85)` (top highlight)
  - `inset 0 -1pt 0 rgba(0,0,0,0.08)` (bottom shade)
  - `0 0 0 0.5pt rgba(0,0,0,0.18)` (hairline border)
- Pressed shadow:
  - `inset 0 2pt 4pt rgba(0,0,0,0.22)`
  - `inset 0 -1pt 0 rgba(255,255,255,0.4)`
  - `0 0 0 0.5pt rgba(0,0,0,0.18)`
- Press translates the button down by 0.5 pt.
- Glyph: a thin minus or plus, **28 pt**, weight 300, color `#3A3530`, vertically centered (nudged up 2 pt to optically center the `−`).
- Behavior:
  - Single click: ±1 BPM.
  - Press-and-hold: starts repeating after **380 ms**, then accelerates by multiplying interval by **0.82** each tick, with a floor of **35 ms**.

##### LCD display (flex/center)
- Container: `border-radius: 14 pt`, padding `18 pt 22 pt 16 pt`.
- Background: vertical gradient `#B8C98A → #C9D89A → #B8C98A` (a slightly desaturated green-yellow LCD tint).
- Shadow stack:
  - `inset 0 2pt 6pt rgba(0,0,0,0.35)` (recessed look)
  - `inset 0 -1pt 0 rgba(255,255,255,0.25)`
  - `0 1pt 0 rgba(255,255,255,0.6)` (lower outer highlight)
- Subtle reflective overlay: a top-to-bottom gradient `rgba(255,255,255,0.18) → transparent → transparent → rgba(0,0,0,0.06)` covering the whole LCD.
- Corner labels (top-left "TEMPO", top-right "BPM"): SF Pro / system font, **9 pt**, weight 700, letter-spacing **1.2 pt**, color `rgba(40,55,15,0.55)`. Positioned 6 pt from top, 12 pt from the respective side.
- Beat indicator dot: top-center, 7 × 7 pt circle, 7 pt from top.
  - Idle color: `rgba(40,55,15,0.18)`.
  - Pulsed color (on each beat): `rgba(40,55,15,0.85)`.
  - Pulse duration: **80 ms**, then back to idle.
- Digits:
  - **DSEG7-Classic Bold** (a real seven-segment LCD font, BSD-licensed, https://github.com/keshikan/DSEG). Bundle the `.ttf` in the app and register it via `CTFontManagerRegisterFontsForURL`.
  - **56 pt**, right-aligned, `padding-right: 4 pt`, line-height 1, no letter spacing.
  - Live color: `rgba(20,35,5,0.92)`, with a faint `text-shadow: 0 1pt 0 rgba(255,255,255,0.15)`.
  - **Ghost layer**: in the same position, render the literal string `"888"` with color `rgba(40,55,15,0.10)`. The live digits sit above the ghost. (This produces the classic "all segments faintly lit" look behind the active number.)
- Width must accommodate `"888"` at 56 pt + 4 pt right padding (≈ 192 pt before padding). With the LCD's 22 pt horizontal padding, the LCD container is about **236 pt wide**.

#### 2. Quick-tempo grid
- A `Grid` with **6 equal columns** and **7 pt** gap.
- Values, left-to-right: **60, 80, 100, 120, 140, 160**.
- Each button:
  - Height: **36 pt**.
  - `border-radius: 9 pt`.
  - **Inactive fill**: vertical gradient `#F6F2EA → #E3DDD2`.
  - **Inactive hover fill**: vertical gradient `#FBFAF6 → #E8E2D6`.
  - **Active fill** (selected — i.e. current BPM equals this preset): vertical gradient `#4A8EDB → #2F6FC4`.
  - Inactive shadow:
    - `inset 0 1pt 0 rgba(255,255,255,0.85)`
    - `inset 0 -1pt 0 rgba(0,0,0,0.06)`
    - `0 1pt 1.5pt rgba(0,0,0,0.10)`
    - `0 0 0 0.5pt rgba(0,0,0,0.16)`
  - Active shadow:
    - `inset 0 1pt 0 rgba(255,255,255,0.35)`
    - `inset 0 -1pt 0 rgba(0,0,0,0.18)`
    - `0 1pt 2pt rgba(0,0,0,0.18)`
    - `0 0 0 0.5pt rgba(0,0,0,0.25)`
  - Label: SF Pro / system font, **14 pt**, weight 600, letter-spacing 0.2 pt.
  - Inactive label color: `#3A3530`. Active label color: white.

#### 3. Start / Stop button
- Full-width, height **48 pt**, `border-radius: 11 pt`.
- **Start (idle) fill**: vertical gradient `#4EC96A → #2EA84A` (green).
- **Start hover fill**: `#5AD078 → #34B352`.
- **Stop (running) fill**: `#E85A52 → #C33D36` (red).
- **Stop hover fill**: `#ED665E → #CF4640`.
- Shadow (any state, idle):
  - `inset 0 1pt 0 rgba(255,255,255,0.45)`
  - `inset 0 -1pt 0 rgba(0,0,0,0.22)`
  - `0 2pt 5pt rgba(0,0,0,0.22)`
  - `0 0 0 0.5pt rgba(0,0,0,0.30)`
- Pressed shadow: `inset 0 2pt 5pt rgba(0,0,0,0.30), 0 0 0 0.5pt rgba(0,0,0,0.30)`.
- Label: SF Pro / system, **17 pt**, weight 700, letter-spacing 0.5 pt, color white, with `text-shadow: 0 -1pt 0 rgba(0,0,0,0.18)`.
- **Icon (left of label, 9 pt gap from label)**:
  - Idle (Start): a right-pointing white triangle, base 14 pt, height 11 pt.
  - Running (Stop): a 10 × 10 pt white rounded square (`border-radius: 1.5 pt`).
- Background-color transition: 120 ms ease-out when state changes.

## Interactions & Behavior

### State
- `bpm: Int` (clamped to **30…300**, default **120**).
- `isRunning: Bool` (default **false**).
- Internal: a beat counter (resets to 0 on each Start) used to determine downbeat (every 4th beat).

### Tempo controls
- **+ / − click**: `bpm = clamp(bpm ± 1, 30, 300)`.
- **+ / − press-and-hold**: after 380 ms, start repeating; each subsequent interval = `max(35, prev * 0.82)`.
- **Quick tempo button**: sets `bpm` to that exact value. The matching button visually activates (blue fill).
- **Keyboard**:
  - `Space`: toggles `isRunning`.
  - `↑`: +1 BPM.
  - `↓`: −1 BPM.

### Audio engine
- Schedule clicks using AVFoundation. Two simple recommended approaches:
  1. **AVAudioEngine + sampler**: scheduleBuffer at precise host times. Use `mach_absolute_time` or `AVAudioTime` for sample-accurate scheduling. Required if you want low-jitter timing.
  2. **AVAudioPlayer with pre-rendered samples** triggered from a dispatch source timer. Easier but more jitter.
- Per beat: one click. Every 4th beat is the **accented downbeat** (higher pitch / louder).
- The HTML prototype generates clicks via Web Audio with these characteristics — match in native:
  - **Downbeat tick**: square wave, **1500 Hz**, ~50 ms envelope (linear ramp to 0.25 amplitude over 1 ms, then exponential decay to 0.0001 over 50 ms).
  - **Off-beat tick**: same envelope, **1000 Hz**.
- Beat interval (seconds) = `60.0 / Double(bpm)`.
- On each beat fired, also pulse the LCD beat-indicator dot (set to active for 80 ms, then back to idle).

### Start/Stop button
- Click toggles `isRunning`.
- On `false → true`: reset beat counter to 0, start the audio engine if not started, schedule the first click ~60 ms in the future, then repeat.
- On `true → false`: stop scheduling, optionally fade out the engine. The LCD beat dot returns to idle.

### Tempo changes while running
- Updating `bpm` while running takes effect on the **next scheduled beat** (don't restart the counter; just use the new interval going forward).

## State Management
SwiftUI `@StateObject` view model is the natural choice:

```swift
@MainActor
final class MetronomeModel: ObservableObject {
    @Published var bpm: Int = 120 { didSet { bpm = max(30, min(300, bpm)) } }
    @Published var isRunning: Bool = false
    @Published var beatPulse: Bool = false   // for the LCD dot
    // private: AVAudioEngine, scheduling timer, beat counter
}
```

The view binds Start/Stop and the quick-tempo buttons to mutate `bpm` and `isRunning`. The engine observes `isRunning` to start/stop and reads the latest `bpm` on each scheduled tick.

## Design Tokens

### Colors
| Token | Hex / value |
|---|---|
| Window body gradient (top) | `#ECEAD8` |
| Window body gradient (bottom) | `#E3E0C8` |
| Title bar gradient (top) | `#F4F2E2` |
| Title bar gradient (bottom) | `#E6E2CC` |
| Title bar separator | `rgba(0,0,0,0.18)` |
| Primary text | `#3A3530` |
| LCD bg gradient (top/bottom) | `#B8C98A` |
| LCD bg gradient (mid) | `#C9D89A` |
| LCD digit (live) | `rgba(20,35,5,0.92)` |
| LCD digit (ghost) | `rgba(40,55,15,0.10)` |
| LCD label / dot idle | `rgba(40,55,15,0.55)` / `0.18` |
| LCD dot active | `rgba(40,55,15,0.85)` |
| Nudge button gradient (top/bottom) | `#FBFAF6` / `#E3DDD2` |
| Nudge button pressed (top/bottom) | `#D8D3CB` / `#EBE5DB` |
| Quick btn idle (top/bottom) | `#F6F2EA` / `#E3DDD2` |
| Quick btn hover (top/bottom) | `#FBFAF6` / `#E8E2D6` |
| Quick btn active (top/bottom) | `#4A8EDB` / `#2F6FC4` |
| Start (top/bottom) | `#4EC96A` / `#2EA84A` |
| Start hover | `#5AD078` / `#34B352` |
| Stop (top/bottom) | `#E85A52` / `#C33D36` |
| Stop hover | `#ED665E` / `#CF4640` |

### Spacing
- Body padding: 20 / 22 / 22 pt.
- Section gap (vertical): 18 pt.
- LCD row gap: 14 pt.
- Quick-tempo grid gap: 7 pt.
- Start button top margin: 18 pt.

### Typography
- All non-LCD text: SF Pro / system font.
  - LCD corner labels: 9 pt / 700 / +1.2 letter-spacing.
  - Quick-tempo buttons: 14 pt / 600 / +0.2 letter-spacing.
  - Start/Stop button: 17 pt / 700 / +0.5 letter-spacing.
  - Window title: 13 pt / 600.
- LCD digits: **DSEG7-Classic-Bold**, 56 pt.

### Border radius
- Window: native (use system).
- LCD: 14 pt.
- Nudge buttons: 50% (circle).
- Quick-tempo buttons: 9 pt.
- Start/Stop button: 11 pt.

### Tempo limits
- Min: 30 BPM, Max: 300 BPM.
- Quick presets: 60, 80, 100, 120, 140, 160.
- Default: 120 BPM.

## Assets
- **DSEG7-Classic Bold** font: download from https://github.com/keshikan/DSEG (BSD-3-Clause). Bundle `DSEG7Classic-Bold.ttf` in the app, declare it in `Info.plist` under `ATSApplicationFontsPath`, and load via `CTFontCreateWithName`.
- No images, no icons — the play triangle and stop square are drawn with `Path` / `Shape` in SwiftUI (or simple views).
- Click sounds are synthesised at runtime; no audio files required. (If preferred, render two `.aiff` samples — `click_high.aiff` for downbeat, `click_low.aiff` for off-beat — and play with `AVAudioPlayer`.)

## Files in this bundle
- `SPEC.md` — this document.
- `screenshots/01-stopped.png` — idle state, BPM 120.
- `screenshots/02-running.png` — running state (Stop red).
- `screenshots/03-quicktempo-160.png` — preset 160 selected.
- `reference/Metronome.html` — HTML prototype shell.
- `reference/metronome.jsx` — React component source with all the styling and audio logic.

To run the prototype locally for visual reference, open `reference/Metronome.html` in any modern browser.

## License

EZ Metronome is licensed under the GNU General Public License v3.0 or later. See `LICENSE` for the full license text.

This means you may use, study, modify, and redistribute the project under the GPL terms. If you distribute modified versions or derivative works, they must remain under the same license and include the corresponding source code.
