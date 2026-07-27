import AppKit
import Foundation

enum WallpaperError: Error {
  case invalidArguments
}

func usage() -> Never {
  FileHandle.standardError.write(Data("Usage: WallpaperControl get|set <image-path>\n".utf8))
  exit(2)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let action = arguments.first else { usage() }
let workspace = NSWorkspace.shared

switch action {
case "get":
  for screen in NSScreen.screens {
    if let url = workspace.desktopImageURL(for: screen) {
      print(url.path)
      exit(0)
    }
  }
  exit(1)

case "set":
  guard arguments.count == 2 else { usage() }
  let url = URL(fileURLWithPath: arguments[1]).standardizedFileURL
  guard FileManager.default.fileExists(atPath: url.path) else {
    FileHandle.standardError.write(Data("Wallpaper file not found: \(url.path)\n".utf8))
    exit(1)
  }

  var failures: [String] = []
  for screen in NSScreen.screens {
    do {
      try workspace.setDesktopImageURL(url, for: screen, options: [:])
    } catch {
      failures.append(error.localizedDescription)
    }
  }

  if failures.isEmpty {
    print(url.path)
    exit(0)
  }
  FileHandle.standardError.write(Data((failures.joined(separator: "\n") + "\n").utf8))
  exit(1)

default:
  usage()
}
