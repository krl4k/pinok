import AppKit
import Observation

/// Фон для живого превью — обои рабочего стола (без каких-либо разрешений).
@MainActor
@Observable
final class PreviewBackdrop {
    static let shared = PreviewBackdrop()

    private(set) var wallpaper: NSImage?

    private init() { loadWallpaper() }

    /// Картинка фона (nil — нарисованный «рабочий стол»).
    var image: NSImage? { wallpaper }

    func loadWallpaper() {
        if let url = NSWorkspace.shared.desktopImageURL(for: NSScreen.active) {
            wallpaper = NSImage(contentsOf: url)
        }
    }
}
