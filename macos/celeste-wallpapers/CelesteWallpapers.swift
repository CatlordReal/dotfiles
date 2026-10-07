import AppKit
import Darwin

struct WallpaperFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Native wallpaper providers contain more state than NSWorkspace's still-image URL.
/// Keep an exact recovery copy, but restore only desktop fields, never screen savers.
final class NativeWallpaper {
    let fileManager = FileManager.default
    let root: URL
    let index: URL
    var backup: URL { root.appendingPathComponent("native-wallpaper.plist") }
    var marker: URL { root.appendingPathComponent("slideshow-active") }
    init(root: URL) {
        self.root = root
        index = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")
    }
    func read(_ url: URL) throws -> [String: Any] {
        guard let value = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any],
              value["Displays"] is [String: Any], value["Spaces"] is [String: Any] else {
            throw WallpaperFailure(message: "This macOS wallpaper store is unsupported. The recovery copy was retained.")
        }
        return value
    }
    func desktop(_ saved: [String: Any]) throws -> [String: Any] {
        let all = saved["AllSpacesAndDisplays"] as? [String: Any]
        let defaults = saved["SystemDefault"] as? [String: Any]
        guard let desktop = (all?["Desktop"] ?? defaults?["Desktop"]) as? [String: Any],
              desktop["Content"] is [String: Any] else {
            throw WallpaperFailure(message: "Native wallpaper recovery data is invalid. Recovery copy was retained.")
        }
        return desktop
    }
    func save() throws {
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        if fileManager.fileExists(atPath: marker.path) { _ = try desktop(read(backup)); return }
        _ = try desktop(read(index))
        try Data(contentsOf: index).write(to: backup, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        try Data().write(to: marker, options: .atomic)
    }
    static func merge(current: [String: Any], saved: [String: Any], fallback: [String: Any]) -> [String: Any] {
        var result = current
        if current["Desktop"] != nil || saved["Desktop"] != nil {
            result["Desktop"] = saved["Desktop"] ?? fallback
            if let type = saved["Type"] { result["Type"] = type }
        }
        let keys = Set(current.keys).union(saved.keys).subtracting(["Desktop", "Idle"])
        for key in keys {
            if key == "AllSpacesAndDisplays", let value = saved[key], !(value is [String: Any]) {
                result[key] = value
            } else if current[key] is [String: Any] || saved[key] is [String: Any] {
                result[key] = merge(current: current[key] as? [String: Any] ?? [:],
                                    saved: saved[key] as? [String: Any] ?? [:], fallback: fallback)
            }
        }
        return result
    }
    func wallpaperAgent() throws -> NSRunningApplication {
        guard let agent = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.wallpaper.agent").first,
              agent.executableURL?.path == "/System/Library/CoreServices/WallpaperAgent.app/Contents/MacOS/WallpaperAgent" else {
            throw WallpaperFailure(message: "Your wallpaper service is unavailable. Recovery copy was retained.")
        }
        return agent
    }
    func signal(_ agent: NSRunningApplication, _ signal: Int32) throws {
        guard Darwin.kill(agent.processIdentifier, signal) == 0 else {
            throw WallpaperFailure(message: "Wallpaper service could not reload: \(String(cString: strerror(errno)))")
        }
    }
    static func desktopState(_ value: [String: Any]) -> NSDictionary {
        var result: [String: Any] = [:]
        if var desktop = value["Desktop"] as? [String: Any] {
            desktop.removeValue(forKey: "LastSet")
            desktop.removeValue(forKey: "LastUse")
            result["Desktop"] = desktop
        }
        if let type = value["Type"], value["Desktop"] != nil { result["Type"] = type }
        for (key, child) in value where key != "Desktop" && key != "Idle" {
            if let child = child as? [String: Any] { result[key] = desktopState(child) }
        }
        return result as NSDictionary
    }
    func restore() throws {
        guard fileManager.fileExists(atPath: marker.path) else { return }
        let saved = try read(backup)
        _ = try desktop(saved)
        // Freeze the agent before writing: it must not flush stale cached slideshow state.
        let agent = try wallpaperAgent()
        var restarted = false
        try signal(agent, SIGSTOP)
        defer { if !restarted { try? signal(agent, SIGCONT) } }
        let live = try read(index)
        let desktop = try desktop(saved)
        let merged = Self.merge(current: live, saved: saved, fallback: desktop)
        let data = try PropertyListSerialization.data(fromPropertyList: merged, format: .binary, options: 0)
        try data.write(to: index, options: .atomic)
        // Reload this user's wallpaper service so native aerial/dynamic providers return.
        // A public still-image call cannot restore those providers.
        try signal(agent, SIGKILL)
        restarted = true
        // launchd relaunches this per-user Apple agent; request the restored desktop.
        for screen in NSScreen.screens { _ = NSWorkspace.shared.desktopImageURL(for: screen) }
        let expected = Self.desktopState(merged)
        let deadline = Date(timeIntervalSinceNow: 10)
        var stableSince: Date?
        while Date() < deadline {
            let replacement = try? wallpaperAgent()
            let restarted = replacement != nil && replacement!.processIdentifier != agent.processIdentifier
            let actual = try? read(index)
            if restarted, let actual, Self.desktopState(actual) == expected {
                if stableSince == nil { stableSince = Date() }
                if Date().timeIntervalSince(stableSince!) >= 0.5 {
                    try fileManager.removeItem(at: marker)
                    return
                }
            } else { stableSince = nil }
            Thread.sleep(forTimeInterval: 0.05)
        }
        throw WallpaperFailure(message: "macOS wallpaper recovery did not settle. Recovery copy was retained; retry from the menu.")
    }
}

final class CursorPack {
    let root: URL
    let helper: URL
    let cape: URL
    var prior: URL { root.appendingPathComponent("prior-cursors.cape") }
    var prepared: URL { root.appendingPathComponent("prepared-cursors.cape") }
    var marker: URL { root.appendingPathComponent("cursor-active") }
    init(root: URL) {
        self.root = root
        helper = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/mousecloak")
        cape = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Celeste.cape")
    }
    func run(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = helper
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let details = String(data: data, encoding: .utf8) ?? ""
            throw WallpaperFailure(message: "Celeste cursor operation failed. \(details.suffix(800))")
        }
    }
    func start() throws {
        // Save the user's current cursor registrations before the first change.
        // Never refresh this snapshot while recovering or resuming Celeste mode.
        if !FileManager.default.fileExists(atPath: marker.path) {
            let oldFiles = [prior, prepared].filter { FileManager.default.fileExists(atPath: $0.path) }
            if !oldFiles.isEmpty {
                let archive = root.appendingPathComponent("cursor-backups/" + UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                for file in oldFiles { try FileManager.default.moveItem(at: file, to: archive.appendingPathComponent(file.lastPathComponent)) }
            }
            try run(["--prepare", cape.path, "--prepared", prepared.path, "--prior", prior.path])
            try run(["--verify", prior.path])
            try Data().write(to: marker, options: .atomic)
        } else {
            // A crash or previous partial apply may leave Celeste registrations active.
            // Recover the baseline before the expected-current apply check.
            try run(["--restore-session", prior.path])
        }
        try run(["--apply-session", prepared.path, "--expect", prior.path])
        try run(["--verify", prepared.path])
    }
    func restore() throws {
        guard FileManager.default.fileExists(atPath: marker.path) else { return }
        try run(["--restore-session", prior.path])
        try run(["--verify", prior.path])
        try FileManager.default.removeItem(at: marker)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let home = FileManager.default.homeDirectoryForCurrentUser
    lazy var folder = home.appendingPathComponent("Desktop/Programming+/Celeste-Wallpapers", isDirectory: true)
    lazy var native = NativeWallpaper(root: home.appendingPathComponent(".config/celeste-wallpapers/state", isDirectory: true))
    lazy var cursor = CursorPack(root: native.root)
    var lockDescriptor: Int32 = -1
    var status: NSStatusItem!
    var timer: Timer?
    var enabled = false
    var recoveryNeeded = false
    var lastError: String?
    var focusRevision = 0
    var bag: [URL] = []
    var current: URL?
    let fade = WallpaperFade()
    var observers: [NSObjectProtocol] = []
    var logURL: URL { native.root.appendingPathComponent("events.log") }

    func log(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        try? FileManager.default.createDirectory(at: native.root, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logURL.path) { FileManager.default.createFile(atPath: logURL.path, contents: nil) }
        if let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        try? FileManager.default.createDirectory(at: native.root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: native.root.path)
        lockDescriptor = Darwin.open(native.root.appendingPathComponent("app.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard lockDescriptor >= 0, flock(lockDescriptor, LOCK_EX | LOCK_NB) == 0 else { NSApp.terminate(nil); return }
        NSApp.setActivationPolicy(.accessory)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = status.button {
            button.target = self
            button.action = #selector(click)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self, self.enabled, let image = self.current else { return }
                do { try self.apply(image) } catch { self.slideshowFailed(error) }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.enabled, let image = self.current else { return }
            do { try self.apply(image) } catch { self.slideshowFailed(error) }
        })
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(command(_:)), name: NSNotification.Name("com.kianconti.CelesteWallpapers.command"), object: nil, suspensionBehavior: .deliverImmediately)
        if FileManager.default.fileExists(atPath: native.marker.path) { start() }
        else if FileManager.default.fileExists(atPath: cursor.marker.path) {
            recoveryNeeded = true
            stop()
        }
        log("ready mode=\(enabled ? "slideshow" : "native") interval=60")
        let startupFocusRevision = focusRevision
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let desired = try await CelesteFocusFilter.current.enabled
                guard self.focusRevision == startupFocusRevision else { return }
                self.setFocusMode(desired)
            }
            catch SetFocusFilterIntentError.notFound {
                guard self.focusRevision == startupFocusRevision else { return }
                // Only undo a previous Focus-owned session; preserve manual slideshow state.
                if UserDefaults(suiteName: "com.kianconti.CelesteWallpapers")?.bool(forKey: "focusOwnedSession") == true {
                    self.setFocusMode(false)
                }
            } catch { self.log("focus status unavailable: \(error.localizedDescription)") }
        }
    }
    func refresh() {
        if recoveryNeeded {
            status.button?.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Wallpaper recovery needed")
            status.button?.image?.isTemplate = true
            status.button?.toolTip = "Recovery needed. Click to retry restoring macOS wallpaper."
            status.button?.setAccessibilityLabel("Wallpaper recovery needed, click to restore")
            return
        }
        status.button?.image = NSImage(systemSymbolName: enabled ? "photo.on.rectangle.angled" : "mountain.2", accessibilityDescription: enabled ? "Celeste slideshow" : "macOS wallpaper")
        status.button?.image?.isTemplate = true
        status.button?.toolTip = enabled ? "Celeste wallpapers and cursors · every minute. Click to restore macOS wallpaper; right-click for options." : "macOS wallpaper and cursors. Click for Celeste mode; right-click for options."
        status.button?.setAccessibilityLabel(enabled ? "Celeste slideshow, every minute" : "macOS wallpaper, click for Celeste slideshow")
    }
    @objc func click() {
        if NSApp.currentEvent?.type == .rightMouseUp { showMenu(); return }
        toggle()
    }
    @objc func toggle() {
        if enabled || recoveryNeeded { stop() } else { start() }
    }
    func images() throws -> [URL] {
        let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        let extensions = Set(["jpg", "jpeg", "png", "heic", "tiff", "tif", "webp", "bmp"])
        let pictures = urls.filter { extensions.contains($0.pathExtension.lowercased()) && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
        guard !pictures.isEmpty else { throw WallpaperFailure(message: "No wallpaper images found in \(folder.path).") }
        return pictures
    }
    func start() {
        do {
            let available = try images()
            try native.save()
            try cursor.start()
            enabled = true
            recoveryNeeded = false
            bag = available.shuffled()
            try nextImage()
            timer?.invalidate()
            timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
                guard let self, self.enabled else { return }
                do { try self.nextImage() } catch { self.slideshowFailed(error) }
            }
            RunLoop.main.add(timer!, forMode: .common)
            lastError = nil
            refresh()
        } catch {
            do { try recover() } catch { recoveryNeeded = true; timer?.invalidate(); refresh(); fail(error); return }
            enabled = false
            timer?.invalidate()
            refresh()
            fail(error)
        }
    }
    func nextImage() throws {
        if bag.isEmpty {
            bag = try images().shuffled()
            if bag.count > 1, bag.last == current { bag.swapAt(0, bag.count - 1) }
        }
        while let image = bag.popLast() {
            // Images removed from the folder mid-cycle should not halt the slideshow.
            guard FileManager.default.fileExists(atPath: image.path), NSImage(contentsOf: image) != nil else { continue }
            if let current { try? fade.prepare(oldURL: current) }
            do { try apply(image) } catch { fade.cancel(); throw error }
            fade.finish(whenReady: image)
            current = image
            log("slide \(image.lastPathComponent)")
            return
        }
        throw WallpaperFailure(message: "No readable wallpaper images remain. Restore macOS wallpaper from the menu.")
    }
    func apply(_ url: URL) throws {
        guard !NSScreen.screens.isEmpty else { throw WallpaperFailure(message: "No display is available.") }
        for screen in NSScreen.screens {
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [.imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue, .allowClipping: true])
        }
    }
    @objc func next() {
        guard enabled else { return }
        do { try nextImage() } catch { slideshowFailed(error) }
    }
    func recover() throws {
        fade.cancel()
        timer?.invalidate()
        timer = nil
        var errors: [String] = []
        // Attempt both recoveries even if one fails; retain its marker for retry.
        do { try cursor.restore() } catch { errors.append(error.localizedDescription) }
        do { try native.restore() } catch { errors.append(error.localizedDescription) }
        guard errors.isEmpty else { throw WallpaperFailure(message: errors.joined(separator: "\n")) }
    }
    func stop() {
        timer?.invalidate()
        timer = nil
        do {
            try recover()
            enabled = false
            recoveryNeeded = false
            current = nil
            bag = []
            lastError = nil
            refresh()
            log("restored native wallpaper")
        } catch { recoveryNeeded = true; refresh(); fail(error) }
    }
    func slideshowFailed(_ error: Error) {
        timer?.invalidate()
        timer = nil
        do {
            try recover()
            enabled = false
            recoveryNeeded = false
            current = nil
            refresh()
        } catch { recoveryNeeded = true; refresh(); fail(error); return }
        fail(error)
    }
    func fail(_ error: Error) {
        log("error \(error.localizedDescription)")
        lastError = error.localizedDescription
        refresh()
        status.button?.toolTip = "Celeste Wallpapers: \(error.localizedDescription). Right-click for details."
    }
    @objc func showError() {
        guard let lastError else { return }
        let alert = NSAlert()
        alert.messageText = "Celeste Wallpapers"
        alert.informativeText = lastError
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    func showMenu() {
        let menu = NSMenu()
        let title = NSMenuItem(title: recoveryNeeded ? "Recovery Needed" : (enabled ? "Celeste · Every Minute" : "macOS Wallpaper"), action: nil, keyEquivalent: "")
        menu.addItem(title)
        if lastError != nil {
            menu.addItem(withTitle: "Show Error…", action: #selector(showError), keyEquivalent: "").target = self
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: enabled ? "Restore macOS Wallpaper" : "Start Celeste Slideshow", action: #selector(toggle), keyEquivalent: "").target = self
        let next = menu.addItem(withTitle: "Next Wallpaper", action: #selector(next), keyEquivalent: "")
        next.target = self
        next.isEnabled = enabled && !recoveryNeeded
        menu.addItem(withTitle: "Open Wallpaper Folder", action: #selector(openFolder), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit and Restore", action: #selector(quit), keyEquivalent: "q").target = self
        status.menu = menu
        status.button?.performClick(nil)
        status.menu = nil
    }
    @objc func openFolder() { NSWorkspace.shared.open(folder) }
    @objc func quit() {
        if enabled || FileManager.default.fileExists(atPath: native.marker.path) || FileManager.default.fileExists(atPath: cursor.marker.path) { stop() }
        if !FileManager.default.fileExists(atPath: native.marker.path) && !FileManager.default.fileExists(atPath: cursor.marker.path) { NSApp.terminate(nil) }
    }
    @objc func command(_ notification: Notification) {
        switch notification.object as? String {
        case "toggle": toggle()
        case "next": next()
        case "restore": stop()
        case "menu": showMenu()
        case "quit": quit()
        case "focus-on": setFocusMode(true)
        case "focus-off": setFocusMode(false)
        default: break
        }
    }
    func setFocusMode(_ desired: Bool) {
        focusRevision += 1
        let preferences = UserDefaults(suiteName: "com.kianconti.CelesteWallpapers")
        preferences?.set(desired, forKey: "focusFilterEnabled")
        if desired {
            preferences?.set(true, forKey: "focusOwnedSession")
            if !enabled && !recoveryNeeded { start() }
        } else {
            if enabled || recoveryNeeded { stop() }
            if !recoveryNeeded && !FileManager.default.fileExists(atPath: native.marker.path) && !FileManager.default.fileExists(atPath: cursor.marker.path) {
                preferences?.set(false, forKey: "focusOwnedSession")
            }
        }
    }
}

if CommandLine.arguments.contains("--self-test") {
    let nativeContent: [String: Any] = ["Choices": [["Provider": "aerial", "Configuration": Data([1, 2, 3])]]]
    let nativeDesktop: [String: Any] = ["Content": nativeContent]
    let saved: [String: Any] = ["AllSpacesAndDisplays": ["Desktop": nativeDesktop, "Idle": ["keep": 4], "Type": "desktop"], "Desktop": nativeDesktop, "Idle": ["keep": 1], "Type": "desktop"]
    let live: [String: Any] = ["AllSpacesAndDisplays": "$null", "Desktop": ["Content": "slide"], "Idle": ["keep": 2], "Type": "individual", "Displays": ["new": ["Desktop": ["Content": "slide"], "Idle": ["keep": 3]]]]
    let merged = NativeWallpaper.merge(current: live, saved: saved, fallback: nativeDesktop)
    let all = merged["AllSpacesAndDisplays"] as! [String: Any]
    precondition(all["Idle"] == nil)
    precondition(all["Type"] as! String == "desktop")
    precondition((all["Desktop"] as! NSDictionary) == (nativeDesktop as NSDictionary))
    precondition((merged["Desktop"] as! NSDictionary) == (nativeDesktop as NSDictionary))
    precondition((merged["Idle"] as! NSDictionary) == (["keep": 2] as NSDictionary))
    precondition(merged["Type"] as! String == "desktop")
    let new = (merged["Displays"] as! [String: Any])["new"] as! [String: Any]
    precondition((new["Desktop"] as! NSDictionary) == (nativeDesktop as NSDictionary))
    precondition((new["Idle"] as! NSDictionary) == (["keep": 3] as NSDictionary))
    print("PASS: native provider/configuration restored; screen savers preserved; new displays covered")
} else if CommandLine.arguments.contains("--recover-native") {
    do {
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/celeste-wallpapers/state")
        let lock = Darwin.open(root.appendingPathComponent("app.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard lock >= 0, flock(lock, LOCK_EX | LOCK_NB) == 0 else {
            throw WallpaperFailure(message: "Celeste Wallpapers is already running. Restore through its menu.")
        }
        defer { Darwin.close(lock) }
        try NativeWallpaper(root: root).restore()
        print("PASS: saved native wallpaper restored")
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exit(1)
    }
} else if CommandLine.arguments.count > 1 {
    DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("com.kianconti.CelesteWallpapers.command"), object: CommandLine.arguments[1].replacingOccurrences(of: "--", with: ""), userInfo: nil, deliverImmediately: true)
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
