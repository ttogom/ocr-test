import Flutter
import UIKit

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
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
