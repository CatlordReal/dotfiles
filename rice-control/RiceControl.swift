import AppKit

@main
final class RiceControl: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private let sessionScript = "/Users/kianconti/.config/scripts/catppuccin-session.sh"
  private var statusItem: NSStatusItem!
  private var menu: NSMenu!

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    menu = NSMenu()
    menu.delegate = self
    statusItem.menu = menu
    refreshStatus()
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    rebuildMenu()
  }

  private func isSessionEnabled() -> Bool {
    runScript("status").trimmingCharacters(in: .whitespacesAndNewlines) == "on"
  }

  private func runScript(_ action: String) -> String {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: sessionScript)
    process.arguments = [action]
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
      process.waitUntilExit()
      return String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    } catch {
      return ""
    }
  }

  private func refreshStatus() {
    let enabled = isSessionEnabled()
    let imageName = enabled ? "circle.grid.2x2.fill" : "circle.grid.2x2"
    statusItem.button?.image = NSImage(systemSymbolName: imageName, accessibilityDescription: "Catppuccin Rice")
    statusItem.button?.toolTip = enabled ? "Catppuccin Rice: on" : "Catppuccin Rice: off"
  }

  private func rebuildMenu() {
    let enabled = isSessionEnabled()
    menu.removeAllItems()

    let state = NSMenuItem(title: enabled ? "Catppuccin Rice is on" : "Catppuccin Rice is off", action: nil, keyEquivalent: "")
    state.isEnabled = false
    menu.addItem(state)

    let toggle = NSMenuItem(title: enabled ? "Stop Catppuccin Rice" : "Start Catppuccin Rice", action: #selector(toggleSession), keyEquivalent: "")
    toggle.target = self
    menu.addItem(toggle)

    if enabled {
      let reload = NSMenuItem(title: "Reload Rice Components", action: #selector(reloadSession), keyEquivalent: "")
      reload.target = self
      menu.addItem(reload)
    }

    menu.addItem(.separator())
    let quit = NSMenuItem(title: "Quit Rice Control", action: #selector(quit), keyEquivalent: "q")
    quit.target = self
    menu.addItem(quit)
    refreshStatus()
  }

  @objc private func toggleSession() {
    runAsync("toggle")
  }

  @objc private func reloadSession() {
    runAsync("on")
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }

  private func runAsync(_ action: String) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      _ = self?.runScript(action)
      DispatchQueue.main.async {
        self?.refreshStatus()
      }
    }
  }
}
