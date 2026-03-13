import 'package:flutter/material.dart';
import '../models/ocr_text_block.dart';

class BoundingBoxOverlay extends CustomPainter {
  final List<OcrTextBlock> blocks;
  final Size imageSize;

  BoundingBoxOverlay({
    required this.blocks,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final block in blocks) {
      final color = _colorForConfidence(block.confidence);
      final paint = Paint()
        ..color = color.withAlpha(80)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final rect = Rect.fromLTWH(
        block.x * size.width,
        block.y * size.height,
        block.width * size.width,
        block.height * size.height,
      );

      canvas.drawRect(rect, paint);
      canvas.drawRect(rect, borderPaint);

      // Draw confidence text
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${(block.confidence * 100).toInt()}%',
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(rect.left, rect.top - 11));
    }
  }

  Color _colorForConfidence(double confidence) {
    if (confidence >= 0.9) return Colors.green;
    if (confidence >= 0.7) return Colors.yellow.shade700;
    return Colors.red;
  }

  @override
  bool shouldRepaint(covariant BoundingBoxOverlay oldDelegate) {
    return oldDelegate.blocks != blocks;
  }
}
