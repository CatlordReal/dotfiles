import AppKit

final class WallpaperFade {
    enum FadeError: LocalizedError {
        case unreadableImage(URL)

        var errorDescription: String? {
            switch self {
            case let .unreadableImage(url):
                return "Could not read wallpaper image at \(url.path)."
            }
        }
    }

    private var panels: [WallpaperFadePanel] = []
    private var fadingPanels: [WallpaperFadePanel] = []
    private var readinessTimer: Timer?

    /// Covers every current display with the old wallpaper without activating the app.
    func prepare(oldURL: URL) throws {
        cancel()

        guard let image = NSImage(contentsOf: oldURL), image.size.width > 0, image.size.height > 0 else {
            throw FadeError.unreadableImage(oldURL)
        }
        guard let decoded = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw FadeError.unreadableImage(oldURL)
        }
        image.size = NSSize(width: decoded.width, height: decoded.height)

        let level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        panels = NSScreen.screens.map { screen in
            let panel = WallpaperFadePanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            panel.level = level
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            panel.animationBehavior = .none
            panel.backgroundColor = .black
            panel.isOpaque = true
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = true
            panel.isReleasedWhenClosed = false

            let imageView = WallpaperFillView(frame: NSRect(origin: .zero, size: screen.frame.size), image: image)
            imageView.autoresizingMask = [.width, .height]
            panel.contentView = imageView
            panel.alphaValue = 1
            imageView.displayIfNeeded()
            panel.displayIfNeeded()
            panel.orderFrontRegardless()
            return panel
        }
    }

    func finish(whenReady target: URL) {
        let deadline = Date().addingTimeInterval(2)
        readinessTimer?.invalidate()
        readinessTimer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            let ready = NSScreen.screens.allSatisfy { NSWorkspace.shared.desktopImageURL(for: $0) == target }
            if ready {
                self.readinessTimer?.invalidate()
                self.readinessTimer = nil
                // Let WallpaperAgent's accepted image reach the next compositor turn.
                DispatchQueue.main.async { self.finish() }
            } else if Date() >= deadline { self.cancel() }
        }
        RunLoop.main.add(readinessTimer!, forMode: .common)
    }

    /// Reveals the newly applied wallpaper, then removes all overlay panels.
    func finish() {
        guard !panels.isEmpty else { return }
        let finishing = panels
        panels.removeAll()
        fadingPanels.append(contentsOf: finishing)

        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            close(finishing)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            finishing.forEach { $0.animator().alphaValue = 0 }
        } completionHandler: { [weak self] in
            DispatchQueue.main.async {
                self?.close(finishing)
            }
        }
    }

    /// Removes prepared or fading panels immediately.
    func cancel() {
        readinessTimer?.invalidate()
        readinessTimer = nil
        close(panels + fadingPanels)
        panels.removeAll()
        fadingPanels.removeAll()
    }

    private func close(_ closing: [WallpaperFadePanel]) {
        closing.forEach { $0.close() }
        let identities = Set(closing.map(ObjectIdentifier.init))
        fadingPanels.removeAll { identities.contains(ObjectIdentifier($0)) }
    }
}

private final class WallpaperFadePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class WallpaperFillView: NSView {
    private let image: NSImage

    init(frame: NSRect, image: NSImage) {
        self.image = image
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()

        let scale = max(bounds.width / image.size.width, bounds.height / image.size.height)
        let destination = NSRect(
            x: (bounds.width - image.size.width * scale) / 2,
            y: (bounds.height - image.size.height * scale) / 2,
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        image.draw(
            in: destination,
            from: .zero,
            operation: .copy,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }
}
