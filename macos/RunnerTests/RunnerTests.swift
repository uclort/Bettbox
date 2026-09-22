import FlutterMacOS
import Cocoa
import XCTest
@testable import tray_manager

class RunnerTests: XCTestCase {

  func testTrayIconUsesNativeDisabledAppearance() {
    let trayIcon = TrayIcon()
    trayIcon.setImage(NSImage(size: NSSize(width: 18, height: 18)), "left")

    trayIcon.setActive(false)
    XCTAssertEqual(trayIcon.statusItem?.button?.appearsDisabled, true)

    trayIcon.setActive(true)
    XCTAssertEqual(trayIcon.statusItem?.button?.appearsDisabled, false)
  }

}
