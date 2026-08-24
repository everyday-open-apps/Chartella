import SwiftUI
import UIKit
import Vision
import CoreImage
import ImageIO

private struct CropCorners {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    static let fallback = CropCorners(
        topLeft: CGPoint(x: 0.08, y: 0.92),
        topRight: CGPoint(x: 0.92, y: 0.92),
        bottomRight: CGPoint(x: 0.92, y: 0.08),
        bottomLeft: CGPoint(x: 0.08, y: 0.08)
    )
}

struct CropEditorView: View {
    let image: UIImage
    let expectedAspectRatio: CGFloat?
    let onUseScan: (UIImage) -> Void
    let onRetake: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var corners = CropCorners.fallback
    @State private var isDetecting = true
    @State private var isProcessing = false
    @State private var showCropError = false

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let imageRect = aspectFitRect(imageSize: image.size, in: geometry.size)

                ZStack {
                    Color.black.ignoresSafeArea()

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)

                    if isDetecting {
                        ProgressView("Finding document…")
                            .tint(.white)
                            .foregroundColor(.white)
                            .padding()
                            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        cropOverlay(in: imageRect)
                    }
                }
                .coordinateSpace(name: "cropEditor")
            }
            .navigationTitle("Adjust Corners")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Retake", action: onRetake)
                        .accessibilityIdentifier("retakeButton")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Next", action: useScan)
                        .disabled(isDetecting || isProcessing)
                        .accessibilityIdentifier("cropNextButton")
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            AppLog.flow.notice("Crop editor appeared for image \(Int(image.size.width))x\(Int(image.size.height))")
            detectDocument()
        }
        .alert("Could not crop image", isPresented: $showCropError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Adjust the corners and try again.")
        }
    }

    @ViewBuilder
    private func cropOverlay(in imageRect: CGRect) -> some View {
        let points = displayPoints(in: imageRect)

        Path { path in
            path.move(to: points.topLeft)
            path.addLine(to: points.topRight)
            path.addLine(to: points.bottomRight)
            path.addLine(to: points.bottomLeft)
            path.closeSubpath()
        }
        .fill(Color.accentColor.opacity(0.14))
        .overlay {
            Path { path in
                path.move(to: points.topLeft)
                path.addLine(to: points.topRight)
                path.addLine(to: points.bottomRight)
                path.addLine(to: points.bottomLeft)
                path.closeSubpath()
            }
            .stroke(Color.accentColor, lineWidth: 3)
        }

        cornerHandle(at: points.topLeft, keyPath: \.topLeft, in: imageRect)
        cornerHandle(at: points.topRight, keyPath: \.topRight, in: imageRect)
        cornerHandle(at: points.bottomRight, keyPath: \.bottomRight, in: imageRect)
        cornerHandle(at: points.bottomLeft, keyPath: \.bottomLeft, in: imageRect)
    }

    private func cornerHandle(
        at point: CGPoint,
        keyPath: WritableKeyPath<CropCorners, CGPoint>,
        in imageRect: CGRect
    ) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 30, height: 30)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 4))
            .contentShape(Circle().inset(by: -15))
            .position(point)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("cropEditor"))
                    .onChanged { value in
                        corners[keyPath: keyPath] = normalizedPoint(value.location, in: imageRect)
                    }
                    .onEnded { _ in
                        AppLog.crop.debug("User finished moving a crop corner")
                    }
            )
    }

    private func detectDocument() {
        AppLog.detection.notice("Starting Vision rectangle detection")
        guard let cgImage = image.cgImage else {
            AppLog.detection.error("Border detection stopped: could not create CGImage; using fallback corners")
            isDetecting = false
            return
        }

        let request = VNDetectRectanglesRequest { request, error in
            if let error {
                AppLog.detection.error("Vision request completed with error: \(error.localizedDescription, privacy: .public)")
            }
            let rectangle = (request.results as? [VNRectangleObservation])?.first
            DispatchQueue.main.async {
                if let rectangle {
                    AppLog.detection.notice("Document border detected with confidence \(rectangle.confidence)")
                    corners = CropCorners(
                        topLeft: rectangle.topLeft,
                        topRight: rectangle.topRight,
                        bottomRight: rectangle.bottomRight,
                        bottomLeft: rectangle.bottomLeft
                    )
                } else {
                    AppLog.detection.notice("No document border detected; using fallback corners")
                }
                isDetecting = false
                AppLog.detection.notice("Border detection stage finished; editor controls enabled")
            }
        }
        request.maximumObservations = 1
        request.minimumConfidence = 0.55
        if let expectedAspectRatio {
            request.minimumAspectRatio = Float(max(0.2, expectedAspectRatio - 0.18))
            request.maximumAspectRatio = Float(min(1.0, expectedAspectRatio + 0.18))
        } else {
            request.minimumAspectRatio = 0.2
            request.maximumAspectRatio = 1.0
        }
        request.minimumSize = 0.2
        request.quadratureTolerance = 35

        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                do {
                    try VNImageRequestHandler(cgImage: cgImage).perform([request])
                } catch {
                    AppLog.detection.error("Vision rectangle detection failed: \(error.localizedDescription, privacy: .public)")
                    DispatchQueue.main.async {
                        isDetecting = false
                    }
                }
            }
        }
    }

    private func useScan() {
        AppLog.crop.notice("Use Scan selected; starting perspective correction")
        isProcessing = true
        let selectedCorners = corners
        let sourceImage = image

        DispatchQueue.global(qos: .userInitiated).async {
            let cropped = autoreleasepool {
                PerspectiveCropper.crop(image: sourceImage, corners: selectedCorners)
            }
            DispatchQueue.main.async {
                isProcessing = false
                if let cropped {
                    AppLog.crop.notice("Perspective correction succeeded: output \(Int(cropped.size.width))x\(Int(cropped.size.height))")
                    onUseScan(cropped)
                } else {
                    AppLog.crop.error("Perspective correction failed; showing error alert")
                    showCropError = true
                }
            }
        }
    }

    private func aspectFitRect(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (containerSize.width - size.width) / 2,
            y: (containerSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func displayPoints(in rect: CGRect) -> CropCorners {
        func convert(_ point: CGPoint) -> CGPoint {
            CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + (1 - point.y) * rect.height)
        }
        return CropCorners(
            topLeft: convert(corners.topLeft),
            topRight: convert(corners.topRight),
            bottomRight: convert(corners.bottomRight),
            bottomLeft: convert(corners.bottomLeft)
        )
    }

    private func normalizedPoint(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max((point.x - rect.minX) / rect.width, 0), 1),
            y: min(max(1 - (point.y - rect.minY) / rect.height, 0), 1)
        )
    }
}

struct ScanAppearanceEditorView: View {
    let image: UIImage
    let onComplete: (UIImage) -> Void
    let onRetake: () -> Void

    @State private var appearance: ScanAppearance = .cleanColor
    @State private var cleanColorImage: UIImage?
    @State private var isPreparingCleanColor = true

    private var previewImage: UIImage {
        if appearance == .cleanColor, let cleanColorImage {
            return cleanColorImage
        }
        return image
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 18) {
                ZStack {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("appearancePreviewImage")

                    if appearance == .cleanColor && isPreparingCleanColor {
                        ProgressView("Preparing Clean Color…")
                            .tint(.white)
                            .foregroundColor(.white)
                            .padding()
                            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                Picker("Appearance", selection: $appearance) {
                    ForEach(ScanAppearance.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("scanAppearancePicker")

                Text(appearance.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Preview Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Retake", action: onRetake)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Use Scan") {
                        onComplete(previewImage)
                    }
                    .disabled(appearance == .cleanColor && cleanColorImage == nil)
                    .accessibilityIdentifier("useScanButton")
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear(perform: prepareCleanColorPreview)
    }

    private func prepareCleanColorPreview() {
        let sourceImage = image
        DispatchQueue.global(qos: .userInitiated).async {
            let processed = autoreleasepool {
                DocumentImageEnhancer.process(sourceImage, appearance: .cleanColor)
            }
            DispatchQueue.main.async {
                cleanColorImage = processed
                isPreparingCleanColor = false
            }
        }
    }
}

enum DocumentImageEnhancer {
    private static let context = CIContext(options: [.cacheIntermediates: false])

    static func process(_ image: UIImage, appearance: ScanAppearance) -> UIImage? {
        switch appearance {
        case .original:
            return image
        case .cleanColor:
            return cleanColor(image)
        }
    }

    private static func cleanColor(_ image: UIImage) -> UIImage? {
        guard let input = CIImage(image: image) else { return nil }
        let gains = estimatedPaperWhiteGains(for: image)

        let balanced = input.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: gains.red, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: gains.green, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: gains.blue, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0),
        ])
        .applyingFilter("CIColorControls", parameters: [
            kCIInputBrightnessKey: 0.01,
            kCIInputContrastKey: 1.10,
            kCIInputSaturationKey: 0.98,
        ])
        .applyingFilter("CISharpenLuminance", parameters: [
            kCIInputSharpnessKey: 0.35,
            kCIInputRadiusKey: 1.0,
        ])

        guard let output = context.createCGImage(balanced, from: input.extent) else { return nil }
        context.clearCaches()
        return UIImage(cgImage: output, scale: image.scale, orientation: .up)
    }

    private static func estimatedPaperWhiteGains(for image: UIImage) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        guard let cgImage = image.cgImage else { return (1, 1, 1) }

        let sampleWidth = 96
        let sampleHeight = max(1, Int(CGFloat(sampleWidth) * CGFloat(cgImage.height) / CGFloat(cgImage.width)))
        var pixels = [UInt8](repeating: 0, count: sampleWidth * sampleHeight * 4)
        guard let sampleContext = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: sampleWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return (1, 1, 1) }

        sampleContext.interpolationQuality = .medium
        sampleContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

        var samples: [(luminance: CGFloat, red: CGFloat, green: CGFloat, blue: CGFloat)] = []
        samples.reserveCapacity(sampleWidth * sampleHeight)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = CGFloat(pixels[index]) / 255
            let green = CGFloat(pixels[index + 1]) / 255
            let blue = CGFloat(pixels[index + 2]) / 255
            let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            samples.append((luminance, red, green, blue))
        }

        samples.sort { $0.luminance > $1.luminance }
        let brightSamples = samples.prefix(max(1, samples.count / 5))
        let count = CGFloat(brightSamples.count)
        let averageRed = brightSamples.reduce(CGFloat.zero) { $0 + $1.red } / count
        let averageGreen = brightSamples.reduce(CGFloat.zero) { $0 + $1.green } / count
        let averageBlue = brightSamples.reduce(CGFloat.zero) { $0 + $1.blue } / count
        let target = min(0.97, max(0.92, max(averageRed, averageGreen, averageBlue)))

        func linearComponent(_ component: CGFloat) -> CGFloat {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        let linearTarget = linearComponent(target)

        func gain(for component: CGFloat) -> CGFloat {
            min(3.0, max(0.70, linearTarget / max(linearComponent(component), 0.001)))
        }
        return (gain(for: averageRed), gain(for: averageGreen), gain(for: averageBlue))
    }
}

private enum PerspectiveCropper {
    static let context = CIContext(options: [.cacheIntermediates: false])

    static func crop(image: UIImage, corners: CropCorners) -> UIImage? {
        guard let input = CIImage(image: image) else {
            AppLog.crop.error("Could not create CIImage from captured photo")
            return nil
        }
        let extent = input.extent

        func imagePoint(_ point: CGPoint) -> CGPoint {
            CGPoint(x: extent.minX + point.x * extent.width, y: extent.minY + point.y * extent.height)
        }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            AppLog.crop.error("CIPerspectiveCorrection filter is unavailable")
            return nil
        }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: imagePoint(corners.topLeft)), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: imagePoint(corners.topRight)), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: imagePoint(corners.bottomRight)), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: imagePoint(corners.bottomLeft)), forKey: "inputBottomLeft")

        guard
            let output = filter.outputImage,
            let cgImage = context.createCGImage(output, from: output.extent)
        else {
            AppLog.crop.error("Core Image could not render the perspective-corrected output")
            return nil
        }

        let result = UIImage(cgImage: cgImage)
        context.clearCaches()
        return result
    }
}
