import SwiftUI
import UIKit

struct ContentView: View {
    @State private var capturedPages: [ScannedPage] = []
    @State private var pdfURL: URL?
    @State private var pdfShareItem: PDFShareItem?
    @State private var isShowingScanWorkflow = false
    @State private var isShowingCameraUnavailableAlert = false
    @State private var isShowingPDFErrorAlert = false
    @State private var scanQuality: ScanQuality = .p3200
    @State private var scanPreset: ScanPreset = .letterDocument
    @State private var selectedPageID: UUID?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let selectedPage {
                    Image(uiImage: selectedPage.thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("selectedPagePreview")
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if let selectedPageNumber {
                                Text("Page \(selectedPageNumber)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.65))
                                    .clipShape(Capsule())
                                    .padding(8)
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            HStack(spacing: 8) {
                                Button {
                                    rotateSelectedPage()
                                } label: {
                                    Image(systemName: "rotate.right")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                        .shadow(radius: 2)
                                }
                                .accessibilityLabel("Rotate selected page")
                                .accessibilityIdentifier("rotatePageButton")

                                Button(role: .destructive) {
                                    removeSelectedPage()
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(Color.red.opacity(0.85))
                                        .clipShape(Circle())
                                        .shadow(radius: 2)
                                }
                                .accessibilityLabel("Remove selected page")
                                .accessibilityIdentifier("removePageButton")
                            }
                            .padding(8)
                        }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 64))
                            .foregroundColor(.accentColor)

                        Text("Ready to scan")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 420)
                }

                if !capturedPages.isEmpty {
                    VStack(spacing: 12) {
                        HStack {
                            Text("\(capturedPages.count) page\(capturedPages.count == 1 ? "" : "s")")
                                .font(.headline)
                                .accessibilityIdentifier("pageCountLabel")

                            Spacer()

                            Button("Clear") {
                                clearScan()
                            }
                            .font(.subheadline)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(capturedPages.enumerated()), id: \.element.id) { index, page in
                                    Button {
                                        selectedPageID = page.id
                                        AppLog.flow.notice("Selected page \(index + 1) for preview")
                                    } label: {
                                        ZStack(alignment: .topLeading) {
                                            Image(uiImage: page.thumbnail)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 64, height: 88)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(
                                                            selectedPageID == page.id ? Color.accentColor : Color.secondary.opacity(0.25),
                                                            lineWidth: selectedPageID == page.id ? 3 : 1
                                                        )
                                                }

                                            Text("\(index + 1)")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(5)
                                                .background(Color.black.opacity(0.65))
                                                .clipShape(Circle())
                                                .padding(4)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Page \(index + 1)")
                                    .accessibilityValue(selectedPageID == page.id ? "Selected" : "")
                                    .accessibilityHint("Shows this page in the large preview")
                                    .accessibilityIdentifier("pageThumbnail\(index + 1)")
                                }
                            }
                        }
                    }
                }

                Button {
                    openCamera()
                } label: {
                    Label(capturedPages.isEmpty ? "Scan" : "Add Page", systemImage: "camera")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("scanButton")

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Scan Type")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()

                        Picker("Scan Type", selection: $scanPreset) {
                            ForEach(ScanPreset.allCases) { preset in
                                Text(preset.title).tag(preset)
                            }
                        }
                        .pickerStyle(.menu)
                        .lineLimit(1)
                        .fixedSize()
                        .accessibilityIdentifier("scanPresetPicker")
                    }

                    Text(scanPreset.detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Image Quality")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Picker("Image Quality", selection: $scanQuality) {
                        ForEach(ScanQuality.allCases) { quality in
                            Text(quality.title).tag(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if !capturedPages.isEmpty {
                    Button {
                        convertCapturedImagesToPDF()
                    } label: {
                        Label(pdfURL == nil ? "Convert to PDF" : "Share PDF", systemImage: "doc.richtext")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("convertPDFButton")

                    if pdfURL != nil {
                        Text("PDF created")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("pdfCreatedLabel")
                    }
                }

                Text("v\(appVersion)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("versionLabel")
            }
            .padding()
        }
        .fullScreenCover(isPresented: $isShowingScanWorkflow, onDismiss: {
            AppLog.flow.notice("Full-screen scan workflow dismissed")
        }) {
            ScanWorkflowView(quality: scanQuality, preset: scanPreset) { croppedImage in
                do {
                    let page = try ScannedPage.store(croppedImage, preset: scanPreset)
                    capturedPages.append(page)
                    selectedPageID = page.id
                    AppLog.flow.notice("Cropped page accepted and stored; total pages: \(capturedPages.count)")
                    invalidateGeneratedPDF()
                    isShowingScanWorkflow = false
                } catch {
                    AppLog.flow.error("Could not store scanned page: \(error.localizedDescription, privacy: .public)")
                    isShowingPDFErrorAlert = true
                    isShowingScanWorkflow = false
                }
            } onCancel: {
                AppLog.flow.notice("User cancelled the scan workflow")
                isShowingScanWorkflow = false
            }
        }
        .sheet(item: $pdfShareItem) { shareItem in
            let _ = AppLog.pdf.notice("Presenting share sheet for \(shareItem.url.lastPathComponent, privacy: .public)")
            ShareSheet(items: [shareItem.url])
        }
        .alert("Camera unavailable", isPresented: $isShowingCameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device does not have an available camera.")
        }
        .alert("Could not create PDF", isPresented: $isShowingPDFErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please retake the photos and try again.")
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    private var selectedPage: ScannedPage? {
        capturedPages.first { $0.id == selectedPageID } ?? capturedPages.last
    }

    private var selectedPageNumber: Int? {
        guard let selectedPage else { return nil }
        return capturedPages.firstIndex { $0.id == selectedPage.id }.map { $0 + 1 }
    }

    private func openCamera() {
        AppLog.flow.notice("Scan/Add Page button selected")
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            AppLog.camera.notice("Camera is available; presenting camera")
            isShowingScanWorkflow = true
        } else {
            AppLog.camera.error("Camera source is unavailable on this device")
            isShowingCameraUnavailableAlert = true
        }
    }

    private func convertCapturedImagesToPDF() {
        AppLog.pdf.notice("PDF conversion requested for \(capturedPages.count) page(s)")
        guard !capturedPages.isEmpty else {
            AppLog.pdf.error("PDF conversion stopped because there are no pages")
            isShowingPDFErrorAlert = true
            return
        }

        do {
            let newPDFURL = try PDFGenerator.createPDF(from: capturedPages)
            pdfURL = newPDFURL
            pdfShareItem = PDFShareItem(url: newPDFURL)
            AppLog.pdf.notice("PDF created successfully: \(newPDFURL.lastPathComponent, privacy: .public)")
        } catch {
            AppLog.pdf.error("PDF creation failed: \(error.localizedDescription, privacy: .public)")
            isShowingPDFErrorAlert = true
        }
    }

    private func clearScan() {
        AppLog.flow.notice("Clearing scan with \(capturedPages.count) page(s)")
        capturedPages.forEach { $0.removeStoredImage() }
        capturedPages.removeAll()
        selectedPageID = nil
        invalidateGeneratedPDF()
    }

    private func rotateSelectedPage() {
        guard let selectedPage,
              let index = capturedPages.firstIndex(where: { $0.id == selectedPage.id }) else { return }
        do {
            try capturedPages[index].rotateClockwise()
            AppLog.flow.notice("Rotated page \(index + 1) 90 degrees clockwise")
            invalidateGeneratedPDF()
        } catch {
            AppLog.flow.error("Could not rotate page: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func removeSelectedPage() {
        guard let selectedPage else { return }
        let pageNumber = selectedPageNumber ?? capturedPages.count
        selectedPageID = PageCollection.remove(selectedPage.id, from: &capturedPages)
        AppLog.flow.notice("Removed page \(pageNumber); \(capturedPages.count) page(s) remain")
        invalidateGeneratedPDF()
    }

    private func invalidateGeneratedPDF() {
        if let pdfURL {
            try? FileManager.default.removeItem(at: pdfURL)
        }
        pdfURL = nil
        pdfShareItem = nil
    }
}

enum ScanQuality: Int, CaseIterable, Identifiable {
    case p2400 = 2400
    case p3200 = 3200
    case p4000 = 4000
    case original = 0

    var id: Self { self }
    var title: String { self == .original ? "Original" : "\(rawValue)p" }
    var maxPixelDimension: CGFloat {
        self == .original ? .greatestFiniteMagnitude : CGFloat(rawValue)
    }
}

enum ScanAppearance: String, CaseIterable, Identifiable {
    case original
    case cleanColor

    var id: Self { self }

    var title: String {
        switch self {
        case .original: return "Original"
        case .cleanColor: return "Clean Color"
        }
    }

    var detail: String {
        switch self {
        case .original:
            return "Keeps the cropped camera colors unchanged."
        case .cleanColor:
            return "Neutralizes yellow or blue paper and improves contrast without generating or replacing text."
        }
    }
}

enum ScanPreset: String, CaseIterable, Identifiable {
    case a4Document
    case letterDocument
    case standardCard
    case passportPage
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .a4Document: return "A4 Document"
        case .letterDocument: return "Letter Document"
        case .standardCard: return "ID / Bank Card"
        case .passportPage: return "Passport Page"
        case .other: return "Other / Unknown"
        }
    }

    var detail: String {
        switch self {
        case .a4Document: return "210 × 297 mm; fills an A4 PDF page at print size."
        case .letterDocument: return "8.5 × 11 in; fills a North American Letter page."
        case .standardCard: return "ID-1 card, 85.60 × 53.98 mm; centered at real size on A4."
        case .passportPage: return "88 × 125 mm; centered at real size on A4."
        case .other: return "Unknown physical size; uses a custom page matching the crop without stretching."
        }
    }

    var physicalSizeMillimeters: CGSize? {
        switch self {
        case .a4Document: return CGSize(width: 210, height: 297)
        case .letterDocument: return CGSize(width: 215.9, height: 279.4)
        case .standardCard: return CGSize(width: 85.60, height: 53.98)
        case .passportPage: return CGSize(width: 88, height: 125)
        case .other: return nil
        }
    }

    var normalizedAspectRatio: CGFloat? {
        guard let size = physicalSizeMillimeters else { return nil }
        return min(size.width, size.height) / max(size.width, size.height)
    }

}

struct ScannedPage: Identifiable {
    let id = UUID()
    let imageURL: URL
    var thumbnail: UIImage
    let preset: ScanPreset

    static func store(_ image: UIImage, preset: ScanPreset) throws -> ScannedPage {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Chartella-Page-\(UUID().uuidString)")
            .appendingPathExtension("jpg")
        guard let data = image.jpegData(compressionQuality: 0.88) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
        let thumbnail = image.resizedToFit(maxPixelDimension: 900)
        AppLog.flow.debug("Stored scan page on disk: \(url.lastPathComponent, privacy: .public)")
        return ScannedPage(imageURL: url, thumbnail: thumbnail, preset: preset)
    }

    // Rotates the stored page 90° clockwise in place, overwriting its JPEG and
    // refreshing the in-memory thumbnail while keeping the same id and position.
    mutating func rotateClockwise() throws {
        guard let image = UIImage(contentsOfFile: imageURL.path) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let rotated = image.rotatedClockwise(steps: 1)
        guard let data = rotated.jpegData(compressionQuality: 0.88) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: imageURL, options: .atomic)
        thumbnail = rotated.resizedToFit(maxPixelDimension: 900)
    }

    func removeStoredImage() {
        try? FileManager.default.removeItem(at: imageURL)
    }
}

enum PageCollection {
    static func remove(_ pageID: UUID, from pages: inout [ScannedPage]) -> UUID? {
        guard let removedIndex = pages.firstIndex(where: { $0.id == pageID }) else {
            return pages.last?.id
        }

        let removedPage = pages.remove(at: removedIndex)
        removedPage.removeStoredImage()
        guard !pages.isEmpty else { return nil }
        return pages[min(removedIndex, pages.count - 1)].id
    }
}

struct PDFShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ScanWorkflowView: View {
    let quality: ScanQuality
    let preset: ScanPreset
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var capturedImage: UIImage?
    @State private var croppedImage: UIImage?
    @State private var isPreparingEditor = false

    var body: some View {
        Group {
            if let croppedImage {
                ScanAppearanceEditorView(image: croppedImage, onComplete: onComplete) {
                    self.croppedImage = nil
                    capturedImage = nil
                }
            } else if let capturedImage {
                if isPreparingEditor {
                    CaptureProcessingView()
                        .onAppear {
                            AppLog.flow.notice("Showing immediate photo-captured confirmation")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                AppLog.flow.notice("Confirmation displayed; opening border editor")
                                isPreparingEditor = false
                            }
                        }
                } else {
                    CropEditorView(
                        image: capturedImage,
                        expectedAspectRatio: preset.normalizedAspectRatio,
                        onUseScan: { croppedImage = $0 }
                    ) {
                        AppLog.flow.notice("Retake selected; returning directly to camera")
                        self.capturedImage = nil
                    }
                }
            } else {
                CameraPicker(preset: preset) { image in
                    AppLog.flow.notice("Photo received; showing capture confirmation")
                    isPreparingEditor = true
                    DispatchQueue.global(qos: .userInitiated).async {
                        let prepared = autoreleasepool {
                            image.preparedForScanning(maxPixelDimension: quality.maxPixelDimension)
                        }
                        DispatchQueue.main.async {
                            capturedImage = prepared
                        }
                    }
                } onCancel: {
                    onCancel()
                }
                .ignoresSafeArea()
            }
        }
    }
}

struct CaptureProcessingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)

                Text("Photo captured")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)

                    Text("Finding document edges…")
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(32)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Photo captured. Finding document edges.")
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let preset: ScanPreset
    let onImageCaptured: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        AppLog.camera.notice("Creating UIImagePickerController with custom controls")
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        // Hide Apple's default controls so a tap on our shutter captures and
        // advances immediately, skipping the native Retake / Use Photo review.
        picker.showsCameraControls = false
        picker.delegate = context.coordinator

        let onCancel = self.onCancel
        let overlay = CameraControlsOverlay(
            preset: preset,
            onCapture: { [weak picker] in
                AppLog.camera.notice("Custom shutter tapped; capturing photo")
                picker?.takePicture()
            },
            onCancel: {
                AppLog.camera.notice("Custom camera cancel tapped")
                onCancel()
            }
        )
        overlay.frame = UIScreen.main.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        picker.cameraOverlayView = overlay

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                AppLog.camera.notice("Photo accepted from camera: \(Int(image.size.width))x\(Int(image.size.height)), orientation \(image.imageOrientation.rawValue)")
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                parent.onImageCaptured(image)
            } else {
                AppLog.camera.error("Camera finished, but originalImage was missing or invalid")
            }
            AppLog.camera.notice("Camera capture finished; advancing scan workflow")
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            AppLog.camera.notice("User cancelled camera")
            parent.onCancel()
        }
    }
}

final class ScanGuideOverlay: UIView {
    private let preset: ScanPreset
    private let guideView = UIView()
    private let captionLabel = UILabel()

    init(preset: ScanPreset) {
        self.preset = preset
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear

        guideView.isUserInteractionEnabled = false
        guideView.backgroundColor = .clear
        guideView.layer.borderColor = UIColor.systemYellow.cgColor
        guideView.layer.borderWidth = 3
        guideView.layer.cornerRadius = 8
        addSubview(guideView)

        captionLabel.text = preset.title
        captionLabel.textColor = .white
        captionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        captionLabel.font = .preferredFont(forTextStyle: .caption1)
        captionLabel.textAlignment = .center
        captionLabel.layer.cornerRadius = 6
        captionLabel.clipsToBounds = true
        addSubview(captionLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let millimeters = preset.physicalSizeMillimeters else { return }

        let ratio = millimeters.width / millimeters.height
        let availableRect = bounds.inset(by: UIEdgeInsets(top: 90, left: 24, bottom: 190, right: 24))
        var guideSize = CGSize(width: availableRect.width, height: availableRect.width / ratio)
        if guideSize.height > availableRect.height {
            guideSize.height = availableRect.height
            guideSize.width = availableRect.height * ratio
        }

        guideView.frame = CGRect(
            x: availableRect.midX - guideSize.width / 2,
            y: availableRect.midY - guideSize.height / 2,
            width: guideSize.width,
            height: guideSize.height
        )

        let captionSize = captionLabel.sizeThatFits(CGSize(width: guideSize.width, height: 28))
        captionLabel.frame = CGRect(
            x: availableRect.midX - min(guideSize.width, captionSize.width + 20) / 2,
            y: guideView.frame.minY - 34,
            width: min(guideSize.width, captionSize.width + 20),
            height: 26
        )
    }
}

// Camera overlay used when Apple's default controls are hidden: a shutter that
// captures and advances immediately (no Retake / Use Photo review), a Cancel
// button, and the preset guide when the selected preset has a known size.
final class CameraControlsOverlay: UIView {
    private let onCapture: () -> Void
    private let onCancel: () -> Void
    private let guide: ScanGuideOverlay?

    init(preset: ScanPreset, onCapture: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onCapture = onCapture
        self.onCancel = onCancel
        self.guide = preset.physicalSizeMillimeters != nil ? ScanGuideOverlay(preset: preset) : nil
        super.init(frame: .zero)
        backgroundColor = .clear

        if let guide {
            guide.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(guide)
        }

        let shutterButton = UIButton(type: .custom)
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 35
        shutterButton.layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor
        shutterButton.layer.borderWidth = 4
        shutterButton.layer.shadowColor = UIColor.black.cgColor
        shutterButton.layer.shadowOpacity = 0.4
        shutterButton.layer.shadowRadius = 5
        shutterButton.layer.shadowOffset = .zero
        shutterButton.accessibilityLabel = "Capture photo"
        shutterButton.accessibilityIdentifier = "captureButton"
        shutterButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        addSubview(shutterButton)

        let cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        cancelButton.accessibilityIdentifier = "cameraCancelButton"
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        addSubview(cancelButton)

        NSLayoutConstraint.activate([
            shutterButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -24),
            shutterButton.widthAnchor.constraint(equalToConstant: 70),
            shutterButton.heightAnchor.constraint(equalToConstant: 70),

            cancelButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 24),
            cancelButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guide?.frame = bounds
    }

    @objc private func captureTapped() {
        onCapture()
    }

    @objc private func cancelTapped() {
        onCancel()
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        AppLog.pdf.notice("Creating share sheet with \(items.count) item(s)")
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum PDFGenerator {
    private static let a4Page = CGSize(width: 595.28, height: 841.89)
    private static let letterPage = CGSize(width: 612, height: 792)

    static func createPDF(from pages: [ScannedPage]) throws -> URL {
        AppLog.pdf.notice("PDF renderer starting with \(pages.count) disk-backed image(s), actual-size output")
        guard pages.allSatisfy({ FileManager.default.fileExists(atPath: $0.imageURL.path) }) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Chartella-\(UUID().uuidString)")
            .appendingPathExtension("pdf")

        // UIGraphicsPDFRenderer fixes every page to the renderer's initial
        // bounds, even when beginPage receives a different rectangle. The
        // classic PDF context is required for a mixed A4/Letter document.
        guard UIGraphicsBeginPDFContextToFile(fileURL.path, .zero, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        defer { UIGraphicsEndPDFContext() }

        for (index, page) in pages.enumerated() {
            try autoreleasepool {
                guard let image = UIImage(contentsOfFile: page.imageURL.path) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                let pageBounds = CGRect(origin: .zero, size: pageSize(for: page.preset, image: image))
                let imageBounds = imageRect(
                    for: image,
                    preset: page.preset,
                    in: pageBounds
                )
                AppLog.pdf.debug("Rendering PDF page \(index + 1): preset \(page.preset.rawValue, privacy: .public), image \(Int(image.size.width))x\(Int(image.size.height)), page \(Int(pageBounds.width))x\(Int(pageBounds.height))")
                UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)
                UIColor.white.setFill()
                UIRectFill(pageBounds)
                image.draw(in: imageBounds)
            }
        }

        AppLog.pdf.notice("PDF renderer finished writing \(fileURL.lastPathComponent, privacy: .public)")
        return fileURL
    }

    static func pageSize(for preset: ScanPreset, image: UIImage) -> CGSize {
        if preset == .other, image.size.width > 0 {
            return CGSize(
                width: a4Page.width,
                height: a4Page.width * image.size.height / image.size.width
            )
        }
        // Standard document pages follow the scanned image's orientation, so a
        // landscape crop yields a landscape page instead of being letterboxed
        // into a fixed portrait sheet. Card and passport presets stay portrait
        // A4 because they center a fixed physical-size rectangle on the sheet.
        let imageIsLandscape = image.size.width > image.size.height
        if preset == .letterDocument {
            return imageIsLandscape ? landscape(letterPage) : letterPage
        }
        if preset == .a4Document {
            return imageIsLandscape ? landscape(a4Page) : a4Page
        }
        return a4Page
    }

    private static func landscape(_ portrait: CGSize) -> CGSize {
        CGSize(width: portrait.height, height: portrait.width)
    }

    static func imageRect(
        for image: UIImage,
        preset: ScanPreset,
        in pageBounds: CGRect
    ) -> CGRect {
        let targetBounds: CGRect

        if preset == .a4Document || preset == .letterDocument || preset == .other {
            // A full-page scan already contains the paper's own margins, so do
            // not shrink it by adding a second set of PDF margins. Unknown
            // objects use a custom page with the crop's own aspect ratio.
            targetBounds = pageBounds
        } else if let millimeters = preset.physicalSizeMillimeters {
            let pointsPerMillimeter: CGFloat = 72 / 25.4
            let physicalSize = CGSize(
                width: millimeters.width * pointsPerMillimeter,
                height: millimeters.height * pointsPerMillimeter
            )
            targetBounds = CGRect(
                x: pageBounds.midX - physicalSize.width / 2,
                y: pageBounds.midY - physicalSize.height / 2,
                width: physicalSize.width,
                height: physicalSize.height
            )
        } else {
            targetBounds = pageBounds
        }

        let widthScale = targetBounds.width / image.size.width
        let heightScale = targetBounds.height / image.size.height
        let scale = min(widthScale, heightScale)
        let imageSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        return CGRect(
            x: targetBounds.midX - imageSize.width / 2,
            y: targetBounds.midY - imageSize.height / 2,
            width: imageSize.width,
            height: imageSize.height
        )
    }
}

extension UIImage {
    func resizedToFit(maxPixelDimension: CGFloat) -> UIImage {
        let longestEdge = max(size.width, size.height)
        guard longestEdge > maxPixelDimension else { return self }
        let ratio = maxPixelDimension / longestEdge
        let targetSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func rotatedClockwise(steps: Int) -> UIImage {
        let turns = ((steps % 4) + 4) % 4
        guard turns != 0 else { return self }
        let radians = CGFloat(turns) * .pi / 2
        let swapsAxes = turns % 2 == 1
        let outputSize = swapsAxes ? CGSize(width: size.height, height: size.width) : size
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            // The renderer uses a flipped (y-down) coordinate space, so a
            // positive rotation turns the content clockwise, matching the
            // rotate.right control.
            let cg = context.cgContext
            cg.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
            cg.rotate(by: radians)
            draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        }
    }

    func preparedForScanning(maxPixelDimension: CGFloat) -> UIImage {
        // UIImage.size is already the logical, orientation-aware size. Swapping
        // it again for .left/.right camera images turns portrait into landscape
        // and makes draw(in:) stretch the pixels because drawing also respects
        // imageOrientation.
        let orientedSize = size
        let ratio = min(1, maxPixelDimension / max(orientedSize.width, orientedSize.height))
        let targetSize = CGSize(width: orientedSize.width * ratio, height: orientedSize.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
