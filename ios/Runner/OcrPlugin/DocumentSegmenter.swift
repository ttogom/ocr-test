import Vision
import UIKit
import CoreImage

class DocumentSegmenter {

    func segmentAndCrop(imagePath: String, completion: @escaping (Result<String?, Error>) -> Void) {
        guard let image = UIImage(contentsOfFile: imagePath),
              let cgImage = image.cgImage else {
            completion(.failure(NSError(domain: "DocumentSegmenter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])))
            return
        }

        let request = VNDetectDocumentSegmentationRequest()
        let cgOrientation = VisionOcrHandler.cgOrientation(from: image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgOrientation, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])

                guard let result = request.results?.first,
                      let detectedDocument = result as? VNRectangleObservation else {
                    // No document detected — return nil (graceful fallback)
                    completion(.success(nil))
                    return
                }

                let croppedPath = self.applyPerspectiveCorrection(
                    cgImage: cgImage,
                    observation: detectedDocument,
                    originalOrientation: image.imageOrientation
                )

                completion(.success(croppedPath))
            } catch {
                // Graceful fallback — don't fail, just return nil
                completion(.success(nil))
            }
        }
    }

    private func applyPerspectiveCorrection(cgImage: CGImage, observation: VNRectangleObservation, originalOrientation: UIImage.Orientation) -> String? {
        // Apply orientation so the CIImage pixels match what Vision saw
        let cgOrientation = VisionOcrHandler.cgOrientation(from: originalOrientation)
        let ciImage = CIImage(cgImage: cgImage).oriented(cgOrientation)

        let imageWidth = ciImage.extent.width
        let imageHeight = ciImage.extent.height

        // Convert normalized Vision coordinates to pixel coordinates
        let topLeft = CGPoint(x: observation.topLeft.x * imageWidth, y: observation.topLeft.y * imageHeight)
        let topRight = CGPoint(x: observation.topRight.x * imageWidth, y: observation.topRight.y * imageHeight)
        let bottomLeft = CGPoint(x: observation.bottomLeft.x * imageWidth, y: observation.bottomLeft.y * imageHeight)
        let bottomRight = CGPoint(x: observation.bottomRight.x * imageWidth, y: observation.bottomRight.y * imageHeight)

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }

        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")

        guard let outputImage = filter.outputImage else { return nil }

        let context = CIContext()
        guard let correctedCGImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }

        let uiImage = UIImage(cgImage: correctedCGImage)

        let tempDir = NSTemporaryDirectory()
        let fileName = "cropped_receipt_\(UUID().uuidString).jpg"
        let filePath = (tempDir as NSString).appendingPathComponent(fileName)

        guard let jpegData = uiImage.jpegData(compressionQuality: 0.9) else { return nil }

        do {
            try jpegData.write(to: URL(fileURLWithPath: filePath))
            return filePath
        } catch {
            return nil
        }
    }
}
