import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // Always start centered on the visible screen. Without this, macOS state
    // restoration can reopen the window at a saved off-screen position.
    self.makeKeyAndOrderFront(nil)
    self.center()
    // The session toolbar (title field, mode selector, MIC/SPK indicators,
    // Mulai/Export buttons) overflows below this width — see main_screen.dart.
    self.contentMinSize = NSSize(width: 860, height: 700)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
