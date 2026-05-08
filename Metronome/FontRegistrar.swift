import CoreText
import Foundation

/// Registers fonts bundled with the app so SwiftUI can use them by PostScript
/// name at runtime.
enum FontRegistrar {
    /// Registers the bundled DSEG seven-segment font for the current process.
    ///
    /// The font is looked up both at the bundle root and inside a `Fonts`
    /// subdirectory to tolerate small resource-layout changes in the Xcode
    /// project. Missing fonts are ignored so the app can still launch.
    static func registerBundledFonts() {
        let url = Bundle.main.url(forResource: "DSEG7Classic-Bold", withExtension: "ttf")
            ?? Bundle.main.url(forResource: "DSEG7Classic-Bold", withExtension: "ttf", subdirectory: "Fonts")

        guard let url else {
            return
        }

        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}
