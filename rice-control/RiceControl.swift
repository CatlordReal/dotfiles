import AppKit

@main
final class RiceControl: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private let sessionScript = "/Users/kianconti/.config/scripts/catppuccin-session.sh"
  private let controlScript = "/Users/kianconti/.config/scripts/appearance-control.sh"
  private var statusItem: NSStatusItem!
  private var menu: NSMenu!

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    menu = NSMenu()
    menu.delegate = self
    statusItem.menu = menu
    statusItem.button?.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
    refreshStatus()
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    rebuildMenu()
  }

  private func isSessionEnabled() -> Bool {
    runScript(sessionScript, arguments: ["status"]).trimmingCharacters(in: .whitespacesAndNewlines) == "on"
  }

  private func runScript(_ executable: String, arguments: [String]) -> String {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
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
    statusItem.button?.imagePosition = .imageLeading
    statusItem.button?.title = "Rice"
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

    let themes = NSMenuItem(title: "Colour Theme", action: nil, keyEquivalent: "")
    let themeMenu = NSMenu()
    for (title, flavour) in [("Latte 🌻", "latte"), ("Frappe 🪴", "frappe"), ("Macchiato 🌺", "macchiato"), ("Mocha 🌿", "mocha")] {
      let item = NSMenuItem(title: title, action: #selector(selectTheme(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = flavour
      themeMenu.addItem(item)
    }
    themes.submenu = themeMenu
    menu.addItem(themes)

    if enabled {
      let reload = NSMenuItem(title: "Reload Rice Components", action: #selector(reloadSession), keyEquivalent: "")
      reload.target = self
      menu.addItem(reload)
    }

    let help = NSMenuItem(title: "Help & Shortcuts", action: #selector(showHelp), keyEquivalent: "")
    help.target = self
    menu.addItem(help)

    menu.addItem(.separator())
    let quit = NSMenuItem(title: "Quit Rice Control", action: #selector(quit), keyEquivalent: "q")
    quit.target = self
    menu.addItem(quit)
    refreshStatus()
  }

  @objc private func toggleSession() {
    runAsync(sessionScript, arguments: ["toggle"])
  }

  @objc private func selectTheme(_ sender: NSMenuItem) {
    guard let flavour = sender.representedObject as? String else { return }
    runAsync(controlScript, arguments: ["theme", flavour])
  }

  @objc private func reloadSession() {
    runAsync(controlScript, arguments: ["reload-all"])
  }

  @objc private func showHelp() {
    let alert = NSAlert()
    alert.messageText = "Rice shortcuts"
    alert.informativeText = "Alt+Q: half + two quarters\nAlt+Enter: open Kitty\nAlt+H/J/K/L: focus\nAlt+Shift+H/J/K/L: move\nAlt+1..9: workspace\nAlt+Shift+1..9: move + follow\nAlt+Ctrl+1..9: move without follow\nAlt+F: fullscreen\nAlt+Shift+Space: float/tiling\nAlt+Tab: previous workspace"
    alert.addButton(withTitle: "Close")
    alert.runModal()
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }

  private func runAsync(_ executable: String, arguments: [String]) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      _ = self?.runScript(executable, arguments: arguments)
      DispatchQueue.main.async {
        self?.refreshStatus()
      }
    }
  }
}
