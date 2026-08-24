import XCTest

final class ChartellaUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false

        addUIInterruptionMonitor(withDescription: "Camera permission") { alert in
            for title in ["Allow", "OK", "Continue"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }

        app.launch()
    }

    func testSelectAndRemovePageThenPresentPDFShareSheet() throws {
        let scanButton = app.buttons["scanButton"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 15), "Chartella did not reach its initial screen")
        capturePage(using: scanButton)

        let pageCount = app.staticTexts["pageCountLabel"]
        XCTAssertTrue(pageCount.waitForExistence(timeout: 30), "The accepted page did not return to the main screen")
        XCTAssertEqual(pageCount.label, "1 page")
        XCTAssertTrue(app.images["selectedPagePreview"].exists, "The accepted page was not shown in the large preview")
        XCTAssertEqual(app.buttons["pageThumbnail1"].value as? String, "Selected")
        XCTAssertTrue(app.buttons["removePageButton"].exists, "The selected-page remove control was not available")
        XCTAssertTrue(waitUntilHittable(scanButton, timeout: 5), "Add Page should remain visible above the scan settings")

        capturePage(using: scanButton)
        XCTAssertEqual(pageCount.label, "2 pages")
        XCTAssertEqual(app.buttons["pageThumbnail2"].value as? String, "Selected")

        app.buttons["pageThumbnail1"].tap()
        XCTAssertEqual(app.buttons["pageThumbnail1"].value as? String, "Selected")
        XCTAssertNotEqual(app.buttons["pageThumbnail2"].value as? String, "Selected")

        app.buttons["removePageButton"].tap()
        XCTAssertEqual(pageCount.label, "1 page")
        XCTAssertEqual(app.buttons["pageThumbnail1"].value as? String, "Selected")

        let convertButton = app.buttons["convertPDFButton"]
        XCTAssertTrue(convertButton.waitForExistence(timeout: 10))
        convertButton.tap()

        XCTAssertTrue(waitForShareSheet(timeout: 20), "The native PDF share sheet did not appear")
        attachScreenshot(named: "PDF-share-sheet")
    }

    private func capturePage(using scanButton: XCUIElement) {
        scanButton.tap()

        // UIImagePickerController owns the camera controls, so their identifiers
        // come from iOS rather than Chartella. PhotoCapture is stable across the
        // iOS versions used by this project.
        let shutter = app.buttons["PhotoCapture"]
        if !shutter.waitForExistence(timeout: 15) {
            app.tap() // Gives a pending system permission interruption a UI event.
        }
        XCTAssertTrue(shutter.waitForExistence(timeout: 15), "The system camera shutter did not appear")
        shutter.tap()

        let usePhoto = app.buttons["Use Photo"]
        XCTAssertTrue(usePhoto.waitForExistence(timeout: 15), "The camera confirmation screen did not appear")
        usePhoto.tap()

        let cropNext = app.buttons["cropNextButton"]
        XCTAssertTrue(cropNext.waitForExistence(timeout: 30), "The crop editor did not appear")
        XCTAssertTrue(waitUntilHittable(cropNext, timeout: 30), "Document detection did not enable Next")
        cropNext.tap()

        let cleanColor = app.buttons["Clean Color"]
        XCTAssertTrue(cleanColor.waitForExistence(timeout: 30), "The per-page appearance preview did not appear")
        cleanColor.tap()

        let useScan = app.buttons["useScanButton"]
        XCTAssertTrue(waitUntilHittable(useScan, timeout: 30), "Clean Color preview did not finish")
        useScan.tap()
    }

    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        return XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: element)],
            timeout: timeout
        ) == .completed
    }

    private func waitForShareSheet(timeout: TimeInterval) -> Bool {
        let candidates = [
            app.otherElements["ActivityListView"],
            app.navigationBars["Activity"],
            app.buttons["Save to Files"],
            app.buttons["Copy"]
        ]
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if candidates.contains(where: \.exists) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        } while Date() < deadline
        return false
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
