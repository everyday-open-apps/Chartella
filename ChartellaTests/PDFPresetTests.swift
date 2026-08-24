import CoreGraphics
import UIKit
import XCTest
@testable import Chartella

final class PDFPresetTests: XCTestCase {
    private var storedPages: [ScannedPage] = []
    private var generatedPDFs: [URL] = []

    override func tearDown() {
        storedPages.forEach { $0.removeStoredImage() }
        generatedPDFs.forEach { try? FileManager.default.removeItem(at: $0) }
        storedPages.removeAll()
        generatedPDFs.removeAll()
        super.tearDown()
    }

    func testActualSizePDFPageDimensionsForEveryPreset() throws {
        let cases: [(ScanPreset, CGSize, CGSize)] = [
            (.a4Document, CGSize(width: 210, height: 297), CGSize(width: 595.28, height: 841.89)),
            (.letterDocument, CGSize(width: 215.9, height: 279.4), CGSize(width: 612, height: 792)),
            (.standardCard, CGSize(width: 85.60, height: 53.98), CGSize(width: 595.28, height: 841.89)),
            (.passportPage, CGSize(width: 88, height: 125), CGSize(width: 595.28, height: 841.89)),
            (.other, CGSize(width: 160, height: 90), CGSize(width: 595.28, height: 334.845)),
        ]

        for (preset, imageSize, expectedPageSize) in cases {
            let page = try makePage(preset: preset, size: imageSize)
            let pdfURL = try PDFGenerator.createPDF(from: [page])
            generatedPDFs.append(pdfURL)

            let mediaBox = try firstMediaBox(of: pdfURL)
            XCTAssertEqual(mediaBox.width, expectedPageSize.width, accuracy: 0.05, preset.title)
            XCTAssertEqual(mediaBox.height, expectedPageSize.height, accuracy: 0.05, preset.title)
        }
    }

    func testActualSizeObjectBoundsForCardAndPassport() {
        let pointsPerMillimeter: CGFloat = 72 / 25.4

        assertActualSizeBounds(
            preset: .standardCard,
            imageSize: CGSize(width: 85.60, height: 53.98),
            expectedSize: CGSize(width: 85.60 * pointsPerMillimeter, height: 53.98 * pointsPerMillimeter)
        )
        assertActualSizeBounds(
            preset: .passportPage,
            imageSize: CGSize(width: 88, height: 125),
            expectedSize: CGSize(width: 88 * pointsPerMillimeter, height: 125 * pointsPerMillimeter)
        )
    }

    func testActualSizeDocumentsFillTheirPaperWithoutSecondMargins() {
        let cases: [(ScanPreset, CGSize)] = [
            (.a4Document, CGSize(width: 210, height: 297)),
            (.letterDocument, CGSize(width: 215.9, height: 279.4)),
        ]

        for (preset, imageSize) in cases {
            let image = UIImage.makeTestImage(size: imageSize)
            let pageBounds = CGRect(
                origin: .zero,
                size: PDFGenerator.pageSize(for: preset, image: image)
            )
            let imageBounds = PDFGenerator.imageRect(
                for: image,
                preset: preset,
                in: pageBounds
            )
            XCTAssertEqual(imageBounds.midX, pageBounds.midX, accuracy: 0.01, preset.title)
            XCTAssertEqual(imageBounds.midY, pageBounds.midY, accuracy: 0.01, preset.title)
            XCTAssertTrue(
                abs(imageBounds.width - pageBounds.width) < 1 || abs(imageBounds.height - pageBounds.height) < 1,
                "\(preset.title) should fill its paper without a second PDF margin"
            )
        }
    }

    func testOtherUsesCustomFullBleedPageAndPreservesAspectRatio() {
        let image = UIImage.makeTestImage(size: CGSize(width: 1600, height: 900))
        let pageSize = PDFGenerator.pageSize(for: .other, image: image)
        let pageBounds = CGRect(origin: .zero, size: pageSize)
        let imageBounds = PDFGenerator.imageRect(for: image, preset: .other, in: pageBounds)

        XCTAssertEqual(pageSize.width, 595.28, accuracy: 0.01)
        XCTAssertEqual(pageSize.width / pageSize.height, 1600.0 / 900.0, accuracy: 0.001)
        XCTAssertEqual(imageBounds.minX, pageBounds.minX, accuracy: 0.001)
        XCTAssertEqual(imageBounds.minY, pageBounds.minY, accuracy: 0.001)
        XCTAssertEqual(imageBounds.width, pageBounds.width, accuracy: 0.001)
        XCTAssertEqual(imageBounds.height, pageBounds.height, accuracy: 0.001)
    }

    func testMixedPresetPDFUsesPerPagePaperSizes() throws {
        let pages = try [
            makePage(preset: .a4Document, size: CGSize(width: 210, height: 297)),
            makePage(preset: .letterDocument, size: CGSize(width: 215.9, height: 279.4)),
            makePage(preset: .standardCard, size: CGSize(width: 85.60, height: 53.98)),
            makePage(preset: .passportPage, size: CGSize(width: 88, height: 125)),
            makePage(preset: .other, size: CGSize(width: 160, height: 90)),
        ]
        let pdfURL = try PDFGenerator.createPDF(from: pages)
        generatedPDFs.append(pdfURL)

        guard let document = CGPDFDocument(pdfURL as CFURL) else {
            return XCTFail("Could not open generated mixed-preset PDF")
        }
        XCTAssertEqual(document.numberOfPages, 5)
        let expectedSizes = [
            CGSize(width: 595.28, height: 841.89),
            CGSize(width: 612, height: 792),
            CGSize(width: 595.28, height: 841.89),
            CGSize(width: 595.28, height: 841.89),
            CGSize(width: 595.28, height: 334.845),
        ]
        for (index, expectedSize) in expectedSizes.enumerated() {
            guard let page = document.page(at: index + 1) else {
                return XCTFail("Missing PDF page \(index + 1)")
            }
            let mediaBox = page.getBoxRect(.mediaBox)
            XCTAssertEqual(mediaBox.width, expectedSize.width, accuracy: 0.05)
            XCTAssertEqual(mediaBox.height, expectedSize.height, accuracy: 0.05)
        }
    }

    private func assertActualSizeBounds(preset: ScanPreset, imageSize: CGSize, expectedSize: CGSize) {
        let image = UIImage.makeTestImage(size: imageSize)
        let pageSize = PDFGenerator.pageSize(for: preset, image: image)
        let pageBounds = CGRect(origin: .zero, size: pageSize)
        let imageBounds = PDFGenerator.imageRect(
            for: image,
            preset: preset,
            in: pageBounds
        )

        XCTAssertLessThanOrEqual(imageBounds.width, expectedSize.width + 0.01, preset.title)
        XCTAssertLessThanOrEqual(imageBounds.height, expectedSize.height + 0.01, preset.title)
        XCTAssertTrue(
            abs(imageBounds.width - expectedSize.width) < 1 || abs(imageBounds.height - expectedSize.height) < 1,
            "\(preset.title) should fill at least one physical target dimension without distortion"
        )
        XCTAssertEqual(imageBounds.midX, pageBounds.midX, accuracy: 0.01, preset.title)
        XCTAssertEqual(imageBounds.midY, pageBounds.midY, accuracy: 0.01, preset.title)
    }

    private func makePage(preset: ScanPreset, size: CGSize) throws -> ScannedPage {
        let page = try ScannedPage.store(.makeTestImage(size: size), preset: preset)
        storedPages.append(page)
        return page
    }

    private func firstMediaBox(of url: URL) throws -> CGRect {
        guard let document = CGPDFDocument(url as CFURL), let page = document.page(at: 1) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return page.getBoxRect(.mediaBox)
    }
}

final class ImagePreparationTests: XCTestCase {
    func testPortraitCameraOrientationIsNormalizedWithoutSwappingWidthAndHeightTwice() throws {
        let sensorImage = UIImage.makeTestImage(size: CGSize(width: 400, height: 300))
        let cgImage = try XCTUnwrap(sensorImage.cgImage)
        let portraitCameraImage = UIImage(cgImage: cgImage, scale: 1, orientation: .right)

        XCTAssertEqual(portraitCameraImage.size.width, CGFloat(cgImage.height))
        XCTAssertEqual(portraitCameraImage.size.height, CGFloat(cgImage.width))
        XCTAssertLessThan(portraitCameraImage.size.width, portraitCameraImage.size.height)

        let prepared = portraitCameraImage.preparedForScanning(maxPixelDimension: 240)

        XCTAssertEqual(prepared.imageOrientation, .up)
        XCTAssertEqual(prepared.size.width, 180, accuracy: 0.01)
        XCTAssertEqual(prepared.size.height, 240, accuracy: 0.01)
        XCTAssertLessThan(prepared.size.width, prepared.size.height)
    }
}

final class PageCollectionTests: XCTestCase {
    private var storedPages: [ScannedPage] = []

    override func tearDown() {
        storedPages.forEach { $0.removeStoredImage() }
        storedPages.removeAll()
        super.tearDown()
    }

    func testRemovingSelectedPageDeletesItsFileAndSelectsTheFollowingPage() throws {
        let first = try makePage()
        let second = try makePage()
        let third = try makePage()
        var pages = [first, second, third]

        let nextSelection = PageCollection.remove(second.id, from: &pages)

        XCTAssertEqual(pages.map(\.id), [first.id, third.id])
        XCTAssertEqual(nextSelection, third.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.imageURL.path))
    }

    func testRemovingLastPageSelectsTheNewLastPage() throws {
        let first = try makePage()
        let second = try makePage()
        var pages = [first, second]

        let nextSelection = PageCollection.remove(second.id, from: &pages)

        XCTAssertEqual(pages.map(\.id), [first.id])
        XCTAssertEqual(nextSelection, first.id)
    }

    func testRemovingOnlyPageLeavesNoSelection() throws {
        let page = try makePage()
        var pages = [page]

        let nextSelection = PageCollection.remove(page.id, from: &pages)

        XCTAssertTrue(pages.isEmpty)
        XCTAssertNil(nextSelection)
    }

    private func makePage() throws -> ScannedPage {
        let page = try ScannedPage.store(.makeTestImage(size: CGSize(width: 120, height: 180)), preset: .a4Document)
        storedPages.append(page)
        return page
    }
}

final class DocumentImageEnhancerTests: XCTestCase {
    func testOriginalReturnsTheUnmodifiedImage() throws {
        let image = UIImage.makeTestImage(size: CGSize(width: 120, height: 180))
        let result = try XCTUnwrap(DocumentImageEnhancer.process(image, appearance: .original))

        XCTAssertTrue(result === image)
    }

    func testCleanColorNeutralizesYellowPaperWithoutRemovingDarkMarks() throws {
        let size = CGSize(width: 120, height: 180)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(red: 0.90, green: 0.82, blue: 0.57, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(white: 0.12, alpha: 1).setFill()
            context.fill(CGRect(x: 30, y: 0, width: 60, height: size.height))
        }

        let result = try XCTUnwrap(DocumentImageEnhancer.process(image, appearance: .cleanColor))
        XCTAssertEqual(result.size.width, image.size.width, accuracy: 0.01)
        XCTAssertEqual(result.size.height, image.size.height, accuracy: 0.01)

        let background = try XCTUnwrap(result.rgbPixel(x: 10, y: 10))
        let darkMark = try XCTUnwrap(result.rgbPixel(x: 60, y: 76))
        let backgroundSpread = max(background.red, background.green, background.blue)
            - min(background.red, background.green, background.blue)

        XCTAssertLessThan(backgroundSpread, 0.18, "Paper should become substantially more neutral")
        XCTAssertLessThan(darkMark.luminance, background.luminance * 0.5, "Dark text-like marks must remain dark")
    }
}

final class PDFOrientationTests: XCTestCase {
    func testLandscapeDocumentImagesProduceLandscapePages() {
        let cases: [(ScanPreset, CGSize)] = [
            (.a4Document, CGSize(width: 841.89, height: 595.28)),
            (.letterDocument, CGSize(width: 792, height: 612)),
        ]
        let landscapeImage = UIImage.makeTestImage(size: CGSize(width: 300, height: 200))
        for (preset, expected) in cases {
            let size = PDFGenerator.pageSize(for: preset, image: landscapeImage)
            XCTAssertGreaterThan(size.width, size.height, preset.title)
            XCTAssertEqual(size.width, expected.width, accuracy: 0.05, preset.title)
            XCTAssertEqual(size.height, expected.height, accuracy: 0.05, preset.title)
        }
    }

    func testPortraitDocumentImagesStayPortrait() {
        let portraitImage = UIImage.makeTestImage(size: CGSize(width: 200, height: 300))
        let a4 = PDFGenerator.pageSize(for: .a4Document, image: portraitImage)
        let letter = PDFGenerator.pageSize(for: .letterDocument, image: portraitImage)
        XCTAssertLessThan(a4.width, a4.height)
        XCTAssertLessThan(letter.width, letter.height)
    }

    func testCardAndPassportStayPortraitA4RegardlessOfImageOrientation() {
        let landscapeCard = UIImage.makeTestImage(size: CGSize(width: 300, height: 200))
        let card = PDFGenerator.pageSize(for: .standardCard, image: landscapeCard)
        let passport = PDFGenerator.pageSize(for: .passportPage, image: landscapeCard)
        XCTAssertEqual(card.width, 595.28, accuracy: 0.05)
        XCTAssertEqual(card.height, 841.89, accuracy: 0.05)
        XCTAssertEqual(passport.width, 595.28, accuracy: 0.05)
        XCTAssertEqual(passport.height, 841.89, accuracy: 0.05)
    }
}

final class ImageRotationTests: XCTestCase {
    func testRotationSwapsWidthAndHeightForOddQuarterTurns() {
        let image = UIImage.makeTestImage(size: CGSize(width: 80, height: 120))

        let once = image.rotatedClockwise(steps: 1)
        XCTAssertEqual(once.size.width, 120, accuracy: 0.01)
        XCTAssertEqual(once.size.height, 80, accuracy: 0.01)

        let twice = image.rotatedClockwise(steps: 2)
        XCTAssertEqual(twice.size.width, 80, accuracy: 0.01)
        XCTAssertEqual(twice.size.height, 120, accuracy: 0.01)

        let fourTimes = image.rotatedClockwise(steps: 4)
        XCTAssertEqual(fourTimes.size.width, 80, accuracy: 0.01)
        XCTAssertEqual(fourTimes.size.height, 120, accuracy: 0.01)
    }

    func testRotationCarriesTopLeftMarkerClockwiseToTopRight() throws {
        let size = CGSize(width: 100, height: 100)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let marked = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 30, height: 30))
        }

        let rotated = marked.rotatedClockwise(steps: 1)
        let topLeft = try XCTUnwrap(rotated.rgbPixel(x: 5, y: 5))
        let topRight = try XCTUnwrap(rotated.rgbPixel(x: 94, y: 5))

        // A clockwise quarter turn carries the top-left marker to the top-right.
        XCTAssertGreaterThan(topRight.red, 0.5, "Top-right should hold the rotated marker")
        XCTAssertLessThan(topRight.green, 0.3)
        XCTAssertLessThan(topLeft.red, 0.3, "Top-left should no longer be the marker")
    }
}

private extension UIImage {
    static func makeTestImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }


    func rgbPixel(x: Int, y: Int) -> (red: CGFloat, green: CGFloat, blue: CGFloat, luminance: CGFloat)? {
        guard
            let cgImage,
            let croppedPixel = cgImage.cropping(to: CGRect(x: x, y: y, width: 1, height: 1))
        else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(croppedPixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let red = CGFloat(pixel[0]) / 255
        let green = CGFloat(pixel[1]) / 255
        let blue = CGFloat(pixel[2]) / 255
        return (red, green, blue, 0.2126 * red + 0.7152 * green + 0.0722 * blue)
    }
}
