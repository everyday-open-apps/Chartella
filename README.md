# Chartella

Chartella is a native iOS app written in Swift and SwiftUI. The long-term goal is to turn the iPhone camera into a simple document scanner that can capture a photo and convert it to PDF.

The current first version is intentionally small: it opens the iPhone camera from a Scan button, captures one or more photos, converts them to a PDF, and opens the iOS share sheet.

## Platform Support

- iOS only
- iPhone only for the first version
- Minimum iOS version: iOS 15.0
- No Android support
- No web support
- No macOS, Mac Catalyst, visionOS, or iPad-specific support

## Current Version

### v0.15 Prioritized Scan Button

- Keeps the original large page preview
- Places **Scan / Add Page** above Scan Type and Image Quality so the primary action is reached before the settings

### v0.14 Page Selection and Removal

- Tapping a numbered thumbnail changes the large preview to that page
- Highlights the selected thumbnail and labels the large preview with its page number
- Shows a trash button directly on the large preview and removes only that selected page while preserving the remaining page order
- Selects the following page after removal, or the previous page when the removed page was last

### v0.13 Clean Color Default

- Opens each page's post-crop preview with Clean Color selected by default
- Still lets the user switch between Clean Color and Original before accepting that individual page

### v0.12 Original and Clean Color

- Adds a per-page preview with Original and Clean Color controls after cropping
- Starts each new page at Original and updates the large preview immediately when either appearance is selected
- Clean Color neutralizes yellow or blue paper, improves contrast, and mildly sharpens text
- Performs deterministic Core Image processing entirely on-device; it does not use generative AI or replace document text
- Keeps Original available when unchanged cropped camera colors are preferred

### v0.10 Visible Version Footer

- Shows the installed app version as centered text at the bottom of the main screen
- Reads the value from the app bundle so the displayed version follows future release updates

### v0.9 Actual-Size-Only PDF Output

- Removes the PDF Output setting and the Fit to A4 mode
- Always uses the selected known standard's physical dimensions
- Keeps A4 and Letter as full matching paper pages
- Keeps ID / Bank Card and Passport Page centered at physical size on A4
- Gives Other / Unknown a custom full-bleed page matching the crop's aspect ratio, because its real-world physical size cannot be inferred from a photo

### v0.8 Physical Scan Presets

- Adds A4 Document, Letter Document, ID / Bank Card, Passport Page, and Other / Unknown scan presets
- Shows a preset-shaped camera guide and narrows Vision rectangle detection toward the selected aspect ratio
- Stores the preset with every captured page
- Supports Actual Size output for known standards and Fit to A4 output for readable sharing
- Defaults A4 and Letter scans to their matching full paper canvas without adding a second artificial margin
- Centers standard cards (85.60 × 53.98 mm) and passport pages (88 × 125 mm) at physical size on A4
- Treats unknown objects honestly: preserve proportions and fit them inside A4 margins without claiming their physical size
- Includes real-iPhone unit coverage for every preset, physical card/passport bounds, Fit to A4 margins/aspect ratio, full-page document fill, and mixed A4/Letter PDFs

### v0.7 Explicit PDF Page Layout

- Adds Portrait, Auto, and Landscape choices for generated PDF pages
- Defaults to portrait because camera-frame dimensions do not reliably describe the paper inside the photo
- Keeps the processed scan pixels intact and scales them proportionally inside the selected A4 page

### v0.6 Selectable Scan Quality

- Adds an image quality selector for newly captured pages
- Supports 2400p, 3200p, and 4000p maximum image dimensions
- Adds an Original option to preserve the camera's full resolution
- Uses 2400p by default to preserve the previous scan behavior

### v0.5 Document Cropping and Memory Improvements

- Detects document boundaries automatically after capture using Vision
- Provides draggable corner handles for manual crop adjustment
- Applies perspective correction to flatten angled document photos
- Resizes captured images before scan processing to reduce peak memory use
- Stores accepted pages as disk-backed JPEG files instead of full-resolution in-memory images
- Keeps smaller thumbnails in memory for the preview and page strip
- Loads and releases one scanned page at a time during PDF generation
- Removes stored page images when the scan is cleared

### v0.4 Multi-Photo PDF

- Native SwiftUI app
- Single screen
- Scan button opens the iPhone camera
- Captures multiple photos as PDF pages
- Shows the latest captured photo in the app
- Shows page count and page thumbnails
- Add Page support
- Clear support
- Converts captured photos to a multi-page PDF
- Shares or saves the PDF through the iOS share sheet
- Xcode project included
- Ready to run on iPhone after selecting a development team in Xcode

## Run on iPhone

1. Open `Chartella.xcodeproj` in Xcode.
2. Select the `Chartella` target.
3. Set your Apple development team under **Signing & Capabilities**.
4. Connect your iPhone.
5. Select your iPhone as the run destination.
6. Press **Run**.

If Xcode asks you to trust the developer certificate on your iPhone, open **Settings > General > VPN & Device Management** and trust your developer profile.

## Product Goal

The planned scanner app will support the following document workflow.

## Core Features

### Document Scanning

- Scan paper documents, receipts, notes, invoices, whiteboards, IDs, and certificates.
- Capture documents directly from the iPhone camera.
- Support single-page and multi-page scans.
- Keep scanned pages organized before exporting.

### Automatic Edge Detection

- Detect document boundaries automatically after capture.
- Highlight the detected page area for review.
- Let users manually adjust corners when automatic detection needs correction.

### Crop, Rotate, and Perspective Correction

- Crop scans to the exact document area.
- Rotate pages to the correct orientation.
- Correct angled photos so documents appear flat and readable.
- Support quick fixes before saving or exporting.

### Image Enhancement

- Sharpen text for better readability.
- Improve contrast for faded or low-light documents.
- Reduce shadows and background noise.
- Provide scan filters for clean document output, such as original, black and white, grayscale, and enhanced color.

### PDF Creation

- Create single-page PDFs from one scan.
- Create multi-page PDFs from multiple captured pages.
- Reorder, delete, or add pages before final export.
- Generate compact, shareable PDF files.

### Export Options

- Export scans as PDF.
- Export individual pages as JPG images.
- Optionally support OCR-based export to editable formats such as Word or TXT.
- Preserve high-quality output suitable for business, school, and personal documents.

### Sharing

- Share files by email.
- Share with AirDrop.
- Send through messaging apps.
- Save or upload to cloud storage apps available on the device.
- Use the native iOS share sheet for familiar sharing workflows.

## Example Use Cases

- Save receipts for expense tracking.
- Digitize handwritten notes.
- Scan invoices and business paperwork.
- Capture whiteboard discussions after meetings.
- Store copies of IDs, certificates, and personal records.
- Convert paper documents into shareable PDFs.

## Recommended MVP

The first version should focus on the essential scan-to-PDF workflow:

1. Capture a document with the camera.
2. Auto-detect document edges.
3. Allow manual crop and rotation adjustments.
4. Apply basic image enhancement.
5. Create single-page or multi-page PDFs.
6. Export as PDF or JPG.
7. Share through the iOS share sheet.

## Future Enhancements

- OCR text recognition.
- Searchable PDFs.
- Word and TXT export.
- Document folders and tags.
- Password-protected PDFs.
- PDF merge, split, and compression.
- Signature and annotation tools.
- Cloud sync across devices.

## License

Chartella is free software licensed under the GNU General Public License v3.0.
See the [LICENSE](LICENSE) file for the full text.

Copyright (c) 2026 winlin
