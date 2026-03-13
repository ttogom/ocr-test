import 'package:flutter/services.dart';
import '../models/ocr_text_block.dart';

class OcrResult {
  final int imageWidth;
  final int imageHeight;
  final String? croppedImagePath;
  final String? enhancedImagePath;
  final List<OcrTextBlock> textBlocks;

  const OcrResult({
    required this.imageWidth,
    required this.imageHeight,
    this.croppedImagePath,
    this.enhancedImagePath,
    required this.textBlocks,
  });
}

class OcrBridge {
  static const _channel = MethodChannel('com.ocrtest/vision_ocr');

  Future<OcrResult> processReceipt(String imagePath) async {
    final result = await _channel.invokeMethod<Map>('processReceipt', {
      'imagePath': imagePath,
    });

    if (result == null) {
      throw Exception('OCR returned null result');
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(result);
    final List<dynamic> rawBlocks = data['textBlocks'] as List<dynamic>;

    final textBlocks = rawBlocks
        .map((b) => OcrTextBlock.fromMap(Map<String, dynamic>.from(b as Map)))
        .toList();

    return OcrResult(
      imageWidth: data['imageWidth'] as int,
      imageHeight: data['imageHeight'] as int,
      croppedImagePath: data['croppedImagePath'] as String?,
      enhancedImagePath: data['enhancedImagePath'] as String?,
      textBlocks: textBlocks,
    );
  }
}
