import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private func restoreWindow(_ window: NSWindow) {
    if window.isMiniaturized {
      window.deminiaturize(self)
    }
    window.makeKeyAndOrderFront(self)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    sender.activate(ignoringOtherApps: true)

    // Reopen only the app's primary window(s).
    // `sender.windows` may also contain system text utility panels
    // (Spelling/Grammar/Substitutions), which should not be forced open.
    let mainWindows = sender.windows.compactMap { $0 as? MainFlutterWindow }
    if !mainWindows.isEmpty {
      for window in mainWindows {
        restoreWindow(window)
      }
      return true
    }

    // Fallback: restore the first regular non-panel window.
    if let regularWindow = sender.windows.first(where: { !($0 is NSPanel) && $0.canBecomeMain }) {
      restoreWindow(regularWindow)
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
