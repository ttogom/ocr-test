import Vision
import UIKit
import CoreImage

class VisionOcrHandler {

    struct TextBlock {
        let text: String
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let confidence: Float
    }

    func recognizeText(from imagePath: String, completion: @escaping (Result<(Int, Int, [TextBlock]), Error>) -> Void) {
        guard let image = UIImage(contentsOfFile: imagePath),
              let cgImage = image.cgImage else {
            completion(.failure(NSError(domain: "VisionOCR", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])))
            return
        }

        // Use the oriented dimensions (what the user actually sees), not raw CGImage dims
        let imageWidth = Int(image.size.width * image.scale)
        let imageHeight = Int(image.size.height * image.scale)

        let cgOrientation = VisionOcrHandler.cgOrientation(from: image.imageOrientation)

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.success((imageWidth, imageHeight, [])))
                return
            }

            var blocks: [TextBlock] = []

            for observation in observations {
                guard let candidate = observation.topCandidates(1).first else { continue }

                let boundingBox = observation.boundingBox

                // Flip Y from bottom-left origin (Vision) to top-left origin (Flutter)
                let flippedY = 1.0 - boundingBox.origin.y - boundingBox.height

                let block = TextBlock(
                    text: candidate.string,
                    x: boundingBox.origin.x,
                    y: flippedY,
                    width: boundingBox.width,
                    height: boundingBox.height,
                    confidence: candidate.confidence
                )
                blocks.append(block)
            }

            completion(.success((imageWidth, imageHeight, blocks)))
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        // Pass orientation so Vision knows how to interpret the pixel data
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgOrientation, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Apply CIDocumentEnhancer and save the result to a temp file.
    /// Returns the path to the enhanced image, or nil if enhancement failed.
    static func enhanceDocument(imagePath: String) -> String? {
        guard let image = UIImage(contentsOfFile: imagePath),
              let cgImage = image.cgImage else { return nil }

        let ciImage = CIImage(cgImage: cgImage)

        guard let filter = CIFilter(name: "CIDocumentEnhancer") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(5.0, forKey: "inputAmount")

        guard let outputImage = filter.outputImage else { return nil }

        let context = CIContext()
        guard let enhancedCGImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }

        // Preserve original orientation
        let enhancedUIImage = UIImage(cgImage: enhancedCGImage, scale: image.scale, orientation: image.imageOrientation)

        let tempDir = NSTemporaryDirectory()
        let fileName = "enhanced_receipt_\(UUID().uuidString).jpg"
        let filePath = (tempDir as NSString).appendingPathComponent(fileName)

        guard let jpegData = enhancedUIImage.jpegData(compressionQuality: 0.9) else { return nil }

        do {
            try jpegData.write(to: URL(fileURLWithPath: filePath))
            return filePath
        } catch {
            return nil
        }
    }

    func toDictionaryArray(_ blocks: [TextBlock]) -> [[String: Any]] {
        return blocks.map { block in
            return [
                "text": block.text,
                "x": Double(block.x),
                "y": Double(block.y),
                "width": Double(block.width),
                "height": Double(block.height),
                "confidence": Double(block.confidence)
            ]
        }
    }

    static func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up:            return .up
        case .down:          return .down
        case .left:          return .left
        case .right:         return .right
        case .upMirrored:    return .upMirrored
        case .downMirrored:  return .downMirrored
        case .leftMirrored:  return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default:    return .up
        }
    }
}
