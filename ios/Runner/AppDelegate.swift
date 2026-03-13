import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let ocrHandler = VisionOcrHandler()
    private let segmenter = DocumentSegmenter()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(name: "com.ocrtest/vision_ocr", binaryMessenger: controller.binaryMessenger)

        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }

            if call.method == "processReceipt" {
                guard let args = call.arguments as? [String: Any],
                      let imagePath = args["imagePath"] as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing imagePath", details: nil))
                    return
                }
                self.handleProcessReceipt(imagePath: imagePath, result: result)
            } else if call.method == "detectDocument" {
                guard let args = call.arguments as? [String: Any],
                      let bytes = args["bytes"] as? FlutterStandardTypedData,
                      let width = args["width"] as? Int,
                      let height = args["height"] as? Int,
                      let bytesPerRow = args["bytesPerRow"] as? Int else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing frame data", details: nil))
                    return
                }
                self.handleDetectDocument(
                    bytes: bytes.data,
                    width: width,
                    height: height,
                    bytesPerRow: bytesPerRow,
                    result: result
                )
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func handleDetectDocument(bytes: Data, width: Int, height: Int, bytesPerRow: Int, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Create a grayscale pixel buffer from the Y plane bytes
            var pixelBuffer: CVPixelBuffer?
            let attrs: [String: Any] = [
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            ]
            let status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                width,
                height,
                kCVPixelFormatType_OneComponent8,
                attrs as CFDictionary,
                &pixelBuffer
            )

            guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
                DispatchQueue.main.async { result(nil) }
                return
            }

            CVPixelBufferLockBaseAddress(buffer, [])
            let dest = CVPixelBufferGetBaseAddress(buffer)!
            let destBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

            bytes.withUnsafeBytes { srcPtr in
                let src = srcPtr.baseAddress!
                for row in 0..<height {
                    memcpy(dest + row * destBytesPerRow, src + row * bytesPerRow, min(bytesPerRow, destBytesPerRow))
                }
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])

            let request = VNDetectDocumentSegmentationRequest()
            let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up, options: [:])

            do {
                try handler.perform([request])

                guard let observation = request.results?.first as? VNRectangleObservation,
                      observation.confidence > 0.85 else {
                    DispatchQueue.main.async { result(nil) }
                    return
                }

                // Return 4 corners, Y-flipped to top-left origin
                let corners: [String: Any] = [
                    "topLeft": [Double(observation.topLeft.x), Double(1.0 - observation.topLeft.y)],
                    "topRight": [Double(observation.topRight.x), Double(1.0 - observation.topRight.y)],
                    "bottomLeft": [Double(observation.bottomLeft.x), Double(1.0 - observation.bottomLeft.y)],
                    "bottomRight": [Double(observation.bottomRight.x), Double(1.0 - observation.bottomRight.y)],
                ]

                DispatchQueue.main.async { result(corners) }
            } catch {
                DispatchQueue.main.async { result(nil) }
            }
        }
    }

    private func handleProcessReceipt(imagePath: String, result: @escaping FlutterResult) {
        // First try document segmentation, then enhance, then OCR
        segmenter.segmentAndCrop(imagePath: imagePath) { [weak self] segmentResult in
            guard let self = self else { return }

            var bestImagePath = imagePath
            var croppedImagePath: String? = nil
            var enhancedImagePath: String? = nil

            // Step 1: Use cropped image if document was detected
            switch segmentResult {
            case .success(let croppedPath):
                if let path = croppedPath {
                    bestImagePath = path
                    croppedImagePath = path
                }
            case .failure:
                break
            }

            // Step 2: Enhance the image (cropped or original)
            DispatchQueue.global(qos: .userInitiated).async {
                if let enhancedPath = VisionOcrHandler.enhanceDocument(imagePath: bestImagePath) {
                    bestImagePath = enhancedPath
                    enhancedImagePath = enhancedPath
                }

                // Step 3: OCR on the enhanced image
                self.ocrHandler.recognizeText(from: bestImagePath) { ocrResult in
                    DispatchQueue.main.async {
                        switch ocrResult {
                        case .success(let (width, height, blocks)):
                            var response: [String: Any] = [
                                "imageWidth": width,
                                "imageHeight": height,
                                "textBlocks": self.ocrHandler.toDictionaryArray(blocks)
                            ]
                            if let cropped = croppedImagePath {
                                response["croppedImagePath"] = cropped
                            }
                            if let enhanced = enhancedImagePath {
                                response["enhancedImagePath"] = enhanced
                            }
                            result(response)
                        case .failure(let error):
                            result(FlutterError(code: "OCR_ERROR", message: error.localizedDescription, details: nil))
                        }
                    }
                }
            }
        }
    }
}
