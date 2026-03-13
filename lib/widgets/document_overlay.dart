import 'package:flutter/material.dart';
import '../services/ocr_bridge.dart';

class DocumentOverlay extends CustomPainter {
  final DocumentCorners corners;

  DocumentOverlay({required this.corners});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final tl = Offset(corners.topLeft.dx * size.width, corners.topLeft.dy * size.height);
    final tr = Offset(corners.topRight.dx * size.width, corners.topRight.dy * size.height);
    final bl = Offset(corners.bottomLeft.dx * size.width, corners.bottomLeft.dy * size.height);
    final br = Offset(corners.bottomRight.dx * size.width, corners.bottomRight.dy * size.height);

    const armLength = 24.0;

    _drawBracket(canvas, paint, tl, tr, bl, armLength);
    _drawBracket(canvas, paint, tr, tl, br, armLength);
    _drawBracket(canvas, paint, bl, br, tl, armLength);
    _drawBracket(canvas, paint, br, bl, tr, armLength);
  }

  void _drawBracket(Canvas canvas, Paint paint, Offset corner, Offset hNeighbor, Offset vNeighbor, double armLength) {
    // Horizontal arm: fixed length toward hNeighbor
    final hDir = hNeighbor - corner;
    final hDist = hDir.distance;
    final hEnd = hDist > 0 ? corner + hDir * (armLength / hDist) : corner;

    // Vertical arm: same fixed length toward vNeighbor
    final vDir = vNeighbor - corner;
    final vDist = vDir.distance;
    final vEnd = vDist > 0 ? corner + vDir * (armLength / vDist) : corner;

    canvas.drawLine(corner, hEnd, paint);
    canvas.drawLine(corner, vEnd, paint);
  }

  @override
  bool shouldRepaint(covariant DocumentOverlay oldDelegate) {
    return oldDelegate.corners != corners;
  }
}
