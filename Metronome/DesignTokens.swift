import SwiftUI

/// Shared visual constants for the fixed-size metronome interface.
///
/// Keeping dimensions, tempo limits, and colors in one namespace makes it safer
/// to tune the visual design without hunting through individual SwiftUI views.
enum Design {
    /// Width of the main app window content area, in points.
    static let windowWidth: CGFloat = 420

    /// Height of the main app window content area, in points.
    static let contentHeight: CGFloat = 262

    /// Horizontal padding applied to the main control stack.
    static let bodyHorizontalPadding: CGFloat = 22

    /// Lowest tempo the app allows.
    static let minBPM = 30

    /// Highest tempo the app allows.
    static let maxBPM = 300

    /// Preset tempos shown in the quick-tempo row.
    static let quickTempos = [60, 80, 100, 120, 140, 160]

    /// Top color for the app body background.
    static let bodyTop = Color(hex: 0xECEAD8)

    /// Bottom color for the app body background.
    static let bodyBottom = Color(hex: 0xE3E0C8)

    /// Primary text color used outside the LCD display.
    static let primaryText = Color(hex: 0x3A3530)

    /// Edge color for the LCD display gradient.
    static let lcdTopBottom = Color(hex: 0xB8C98A)

    /// Center color for the LCD display gradient.
    static let lcdMiddle = Color(hex: 0xC9D89A)

    /// Color of the active seven-segment digits.
    static let lcdLive = Color(red: 20 / 255, green: 35 / 255, blue: 5 / 255).opacity(0.92)

    /// Faint inactive digit color used to simulate an LCD background.
    static let lcdGhost = Color(red: 40 / 255, green: 55 / 255, blue: 15 / 255).opacity(0.10)

    /// Color used for LCD labels and the beat indicator.
    static let lcdMark = Color(red: 40 / 255, green: 55 / 255, blue: 15 / 255)

    /// Top color for idle tempo nudge buttons.
    static let nudgeTop = Color(hex: 0xFBFAF6)

    /// Bottom color for idle tempo nudge buttons.
    static let nudgeBottom = Color(hex: 0xE3DDD2)

    /// Top color for pressed tempo nudge buttons.
    static let nudgePressedTop = Color(hex: 0xD8D3CB)

    /// Bottom color for pressed tempo nudge buttons.
    static let nudgePressedBottom = Color(hex: 0xEBE5DB)

    /// Top color for idle quick-tempo buttons.
    static let quickTop = Color(hex: 0xF6F2EA)

    /// Bottom color for idle quick-tempo buttons.
    static let quickBottom = Color(hex: 0xE3DDD2)

    /// Top color for hovered quick-tempo buttons.
    static let quickHoverTop = Color(hex: 0xFBFAF6)

    /// Bottom color for hovered quick-tempo buttons.
    static let quickHoverBottom = Color(hex: 0xE8E2D6)

    /// Top color for the selected quick-tempo button.
    static let quickActiveTop = Color(hex: 0x4A8EDB)

    /// Bottom color for the selected quick-tempo button.
    static let quickActiveBottom = Color(hex: 0x2F6FC4)

    /// Top color for the idle Start button.
    static let startTop = Color(hex: 0x4EC96A)

    /// Bottom color for the idle Start button.
    static let startBottom = Color(hex: 0x2EA84A)

    /// Top color for the hovered Start button.
    static let startHoverTop = Color(hex: 0x5AD078)

    /// Bottom color for the hovered Start button.
    static let startHoverBottom = Color(hex: 0x34B352)

    /// Top color for the idle Stop button.
    static let stopTop = Color(hex: 0xE85A52)

    /// Bottom color for the idle Stop button.
    static let stopBottom = Color(hex: 0xC33D36)

    /// Top color for the hovered Stop button.
    static let stopHoverTop = Color(hex: 0xED665E)

    /// Bottom color for the hovered Stop button.
    static let stopHoverBottom = Color(hex: 0xCF4640)
}

/// Convenience helpers for constructing SwiftUI colors from design-token hex
/// values.
extension Color {
    /// Creates an opaque color from a `0xRRGGBB` integer.
    ///
    /// - Parameter hex: Red, green, and blue components packed into one value.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Convenience constructors for gradients used throughout the interface.
extension LinearGradient {
    /// Creates a top-to-bottom linear gradient.
    ///
    /// - Parameter colors: Colors to distribute along the vertical axis.
    /// - Returns: A vertical `LinearGradient`.
    static func vertical(_ colors: Color...) -> LinearGradient {
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}
