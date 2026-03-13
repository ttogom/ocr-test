class OcrTextBlock {
  final String text;
  final double x;
  final double y;
  final double width;
  final double height;
  final double confidence;

  const OcrTextBlock({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
  });

  factory OcrTextBlock.fromMap(Map<String, dynamic> map) {
    return OcrTextBlock(
      text: map['text'] as String,
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      width: (map['width'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      confidence: (map['confidence'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'confidence': confidence,
    };
  }

  /// Right edge of this block (normalized)
  double get rightEdge => x + width;

  /// Center Y of this block (normalized)
  double get centerY => y + height / 2;

  @override
  String toString() =>
      'OcrTextBlock("$text", x:${x.toStringAsFixed(3)}, y:${y.toStringAsFixed(3)}, '
      'w:${width.toStringAsFixed(3)}, h:${height.toStringAsFixed(3)}, '
      'conf:${confidence.toStringAsFixed(2)})';
}
