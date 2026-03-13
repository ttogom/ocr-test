import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/services.dart';
import '../models/ocr_text_block.dart';

class DocumentCorners {
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomLeft;
  final Offset bottomRight;

  const DocumentCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });
}

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

  /// Detect document boundary from a camera frame's Y plane (grayscale).
  /// Returns 4 normalized corner points, or null if no document found.
  Future<DocumentCorners?> detectDocument({
    required Uint8List bytes,
    required int width,
    required int height,
    required int bytesPerRow,
  }) async {
    final result = await _channel.invokeMethod<Map>('detectDocument', {
      'bytes': bytes,
      'width': width,
      'height': height,
      'bytesPerRow': bytesPerRow,
    });

    if (result == null) return null;

    final data = Map<String, dynamic>.from(result);
    return DocumentCorners(
      topLeft: _toOffset(data['topLeft']),
      topRight: _toOffset(data['topRight']),
      bottomLeft: _toOffset(data['bottomLeft']),
      bottomRight: _toOffset(data['bottomRight']),
    );
  }

  static Offset _toOffset(dynamic list) {
    final l = list as List<dynamic>;
    return Offset((l[0] as num).toDouble(), (l[1] as num).toDouble());
  }

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
