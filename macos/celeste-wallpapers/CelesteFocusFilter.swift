import AppIntents
import Foundation

@available(macOS 13.0, *)
struct CelesteFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Celeste Wallpapers"
    static let description = IntentDescription("Use Celeste wallpapers and cursors while this Focus is active.")

    @Parameter(title: "Use Celeste Mode", default: false)
    var enabled: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: enabled ? "Celeste Mode" : "macOS Wallpaper")
    }

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: "com.kianconti.CelesteWallpapers")?.set(enabled, forKey: "focusFilterEnabled")
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.kianconti.CelesteWallpapers.command"),
            object: enabled ? "focus-on" : "focus-off",
            userInfo: nil,
            deliverImmediately: true
        )
        return .result()
    }
}
