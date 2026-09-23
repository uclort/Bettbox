import FlutterMacOS
import Cocoa
import XCTest
@testable import tray_manager

class RunnerTests: XCTestCase {

  func testTrayIconUsesBrighterInactiveTint() throws {
    let trayIcon = TrayIcon()
    trayIcon.setImage(NSImage(size: NSSize(width: 18, height: 18)), "left")

    trayIcon.setActive(false)
    let inactiveButton = try XCTUnwrap(trayIcon.statusItem?.button)
    XCTAssertFalse(inactiveButton.appearsDisabled)
    XCTAssertNil(inactiveButton.contentTintColor)
    XCTAssertEqual(inactiveButton.image?.isTemplate, false)

    let inactiveColor = try XCTUnwrap(
      TrayIcon.inactiveColor.usingColorSpace(.sRGB)
    )
    XCTAssertEqual(inactiveColor.redComponent, 0.60, accuracy: 0.01)
    XCTAssertEqual(inactiveColor.greenComponent, 0.60, accuracy: 0.01)
    XCTAssertEqual(inactiveColor.blueComponent, 0.60, accuracy: 0.01)

    trayIcon.setActive(true)
    let activeButton = try XCTUnwrap(trayIcon.statusItem?.button)
    XCTAssertFalse(activeButton.appearsDisabled)
    XCTAssertNil(activeButton.contentTintColor)
    XCTAssertEqual(activeButton.image?.isTemplate, true)
  }

  func testSpeedTitleKeepsNormalTextColorWhenInactive() throws {
    let trayIcon = TrayIcon()
    trayIcon.setImage(NSImage(size: NSSize(width: 18, height: 18)), "left")
    trayIcon.setActive(false)
    trayIcon.setSpeedTitle(upload: 1024, download: 2048, active: false)

    let button = try XCTUnwrap(trayIcon.statusItem?.button)
    let attributes = button.attributedTitle.attributes(
      at: 0,
      effectiveRange: nil
    )
    XCTAssertNil(attributes[.foregroundColor])
    XCTAssertGreaterThan(button.attributedTitle.length, 0)
  }

  func testTrayIconDetectsOptionFromEventOrCurrentKeyboardState() {
    XCTAssertTrue(
      TrayIcon.isOptionPressed(eventFlags: [.option], currentFlags: [])
    )
    XCTAssertTrue(
      TrayIcon.isOptionPressed(eventFlags: [], currentFlags: [.option])
    )
    XCTAssertFalse(
      TrayIcon.isOptionPressed(eventFlags: [], currentFlags: [])
    )
  }

}
