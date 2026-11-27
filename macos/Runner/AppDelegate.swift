import Cocoa
import FlutterMacOS
import Carbon

@main
class AppDelegate: FlutterAppDelegate {
  private var eventMonitor: Any?
  private var hotkeyChannel: FlutterMethodChannel?

  // Closing the window hides the app to the tray (minimize-to-tray keeps a
  // recording running); only the tray's "Keluar" quits. TrayService asks
  // nativeapi to cancel the close, but on macOS 27 the title-bar close button
  // still closes the window after the cancel, and returning true here then
  // terminated the app mid-recording. The window is not released on close
  // (MainFlutterWindow), so it can be shown again.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  // Clicking the Dock icon brings the hidden or closed window back.
  override func applicationShouldHandleReopen(
    _ sender: NSApplication, hasVisibleWindows flag: Bool
  ) -> Bool {
    if !flag {
      for window in sender.windows where window is MainFlutterWindow {
        window.makeKeyAndOrderFront(nil)
      }
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }

    hotkeyChannel = FlutterMethodChannel(
      name: "com.trareon.global_hotkey",
      binaryMessenger: controller.engine.binaryMessenger
    )

    // Global event monitor — fires even when app is in background.
    // Requires Accessibility permissions (System Settings → Privacy & Security
    // → Accessibility). First launch will prompt macOS; subsequent launches
    // silently degrade if permission is denied.
    eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
      self?.handleGlobalKeyEvent(event)
    }
  }

  private func handleGlobalKeyEvent(_ event: NSEvent) {
    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    let hasControl = modifiers.contains(.control)
    let hasShift = modifiers.contains(.shift)

    guard hasControl && hasShift else { return }

    switch Int(event.keyCode) {
    case kVK_ANSI_R:  // Ctrl+Shift+R → start/stop recording
      hotkeyChannel?.invokeMethod("startStop", arguments: nil)
    case kVK_ANSI_P:  // Ctrl+Shift+P → pause/resume
      hotkeyChannel?.invokeMethod("pauseResume", arguments: nil)
    default:
      break
    }
  }

  deinit {
    if let monitor = eventMonitor {
      NSEvent.removeMonitor(monitor)
    }
  }
}
