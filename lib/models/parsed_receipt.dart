class ReceiptItem {
  final String name;
  final double price;
  final String rawText;

  const ReceiptItem({
    required this.name,
    required this.price,
    required this.rawText,
  });

  @override
  String toString() => 'ReceiptItem("$name", \$$price)';
}

enum LineClassification {
  item,
  subtotal,
  tax,
  tip,
  total,
  storeName,
  skipped,
  unknown,
}

class ClassifiedLine {
  final String text;
  final LineClassification classification;
  final double? extractedPrice;

  const ClassifiedLine({
    required this.text,
    required this.classification,
    this.extractedPrice,
  });
}

class ParsedReceipt {
  final String? storeName;
  final List<ReceiptItem> items;
  final double? subtotal;
  final double? tax;
  final double? tip;
  final double? total;
  final List<ClassifiedLine> classifiedLines;
  final List<String> validationNotes;

  const ParsedReceipt({
    this.storeName,
    this.items = const [],
    this.subtotal,
    this.tax,
    this.tip,
    this.total,
    this.classifiedLines = const [],
    this.validationNotes = const [],
  });

  double get itemsSum => items.fold(0.0, (sum, item) => sum + item.price);

  @override
  String toString() =>
      'ParsedReceipt(store: $storeName, items: ${items.length}, '
      'subtotal: $subtotal, tax: $tax, tip: $tip, total: $total)';
}
