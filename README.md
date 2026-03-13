# Receipt OCR

A Flutter iOS app that uses Apple's Vision framework for on-device receipt OCR. No external APIs or cloud services — all processing happens locally on the device.

Capture a receipt photo, extract line items with prices, tax, tip, and total, and inspect the raw OCR output through a built-in debug view.

## How It Works

### Processing Pipeline

```
Camera Capture
      |
      v
+-----------------------------+
| Document Segmentation       |  VNDetectDocumentSegmentationRequest
| + Perspective Correction    |  CIPerspectiveCorrection
+-------------+---------------+
              | (cropped image, or original as fallback)
              v
+-----------------------------+
| Document Enhancement        |  CIDocumentEnhancer
| (contrast, shadows, white   |  Saves enhanced image to temp file
|  balance)                   |  so debug view can display it
+-------------+---------------+
              | (enhanced image)
              v
+-----------------------------+
| Vision OCR                  |  VNRecognizeTextRequest(.accurate)
| Returns text blocks with    |  Coordinates normalized 0-1,
| bounding boxes + confidence |  Y-flipped to top-left origin
+-------------+---------------+
              | (text blocks via MethodChannel)
              v
+-----------------------------+
| Receipt Parser (Dart)       |  Groups blocks into lines by Y-proximity
| Line classification, regex  |  Extracts prices, classifies totals/tax/tip
| Layout heuristics           |  Validates sums
+-------------+---------------+
              |
              v
        Parsed Receipt
```

### Swift-Dart Bridge

The app uses a Flutter `MethodChannel` to communicate between Dart and native Swift code.

**Channel:** `com.ocrtest/vision_ocr`
**Method:** `processReceipt`

Dart sends an image path to Swift:
```dart
final result = await channel.invokeMethod('processReceipt', {
  'imagePath': '/path/to/photo.jpg',
});
```

Swift runs the Vision pipeline and returns structured data:
```json
{
  "imageWidth": 3024,
  "imageHeight": 4032,
  "croppedImagePath": "/tmp/cropped_receipt_xxx.jpg",
  "enhancedImagePath": "/tmp/enhanced_receipt_xxx.jpg",
  "textBlocks": [
    {
      "text": "BURGER",
      "x": 0.05,
      "y": 0.32,
      "width": 0.25,
      "height": 0.02,
      "confidence": 0.98
    }
  ]
}
```

All coordinates are normalized (0-1) with a top-left origin. The Y-axis is flipped on the Swift side since Vision uses a bottom-left origin.

The bridge is registered in `AppDelegate.swift` and orchestrates three steps: document segmentation, image enhancement, and OCR. Each step gracefully falls back if it fails (e.g., no document detected skips cropping, enhancement failure uses the original image).

### Key Files

| File | Role |
|------|------|
| `ios/Runner/AppDelegate.swift` | Registers MethodChannel, orchestrates the pipeline |
| `ios/Runner/OcrPlugin/VisionOcrHandler.swift` | Runs VNRecognizeTextRequest, CIDocumentEnhancer |
| `ios/Runner/OcrPlugin/DocumentSegmenter.swift` | Detects document boundaries, applies perspective correction |
| `lib/services/ocr_bridge.dart` | Dart side of the MethodChannel |
| `lib/services/receipt_parser.dart` | Line grouping, classification, price extraction |

## Debug View

The app includes a 3-tab debug view accessible from the result page:

- **Bounding Boxes** — Image overlay with colored rectangles (green/yellow/red by confidence). Toggle between original and enhanced image to see what Vision processed.
- **Raw OCR** — Every text block with its confidence score and normalized coordinates.
- **Parsed Structure** — How each line was classified (item, tax, total, skipped) and validation results.

## Getting Started

Requires iOS 16.0+ and Xcode.

```bash
flutter pub get
cd ios && pod install && cd ..
flutter run
```
