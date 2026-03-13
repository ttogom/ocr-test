import '../models/ocr_text_block.dart';
import '../models/parsed_receipt.dart';

class ReceiptParser {
  // Price pattern: optional $ sign, digits, dot, two digits
  static final _priceRegex = RegExp(r'\$?\d+\.\d{2}\b');

  // Keywords for totals/tax/tip
  static final _totalKeywords = RegExp(r'\b(total|amount\s*due|balance\s*due|grand\s*total)\b', caseSensitive: false);
  static final _subtotalKeywords = RegExp(r'\b(subtotal|sub\s*total|sub-total)\b', caseSensitive: false);
  static final _taxKeywords = RegExp(r'\b(tax|hst|gst|pst|vat|sales\s*tax)\b', caseSensitive: false);
  static final _tipKeywords = RegExp(r'\b(tip|gratuity)\b', caseSensitive: false);

  // Skip patterns - things that aren't line items
  static final _dateRegex = RegExp(r'\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}');
  static final _timeRegex = RegExp(r'\d{1,2}:\d{2}\s*(AM|PM|am|pm)?');
  static final _phoneRegex = RegExp(r'[\(]?\d{3}[\)\-\s]?\d{3}[\-\s]?\d{4}');
  static final _cardRegex = RegExp(r'\b(visa|mastercard|amex|debit|credit|card|xxxx|\*{4})\b', caseSensitive: false);
  static final _thankYouRegex = RegExp(r'\b(thank\s*you|come\s*again|welcome)\b', caseSensitive: false);
  static final _addressRegex = RegExp(r'\b(street|st\.|ave|avenue|blvd|rd\.|road|suite|ste)\b', caseSensitive: false);

  ParsedReceipt parse(List<OcrTextBlock> blocks) {
    if (blocks.isEmpty) {
      return const ParsedReceipt(validationNotes: ['No text blocks found']);
    }

    // Step 1: Group blocks into lines by Y-coordinate proximity
    final lines = _groupIntoLines(blocks);

    // Step 2: Classify each line
    final classifiedLines = <ClassifiedLine>[];
    final items = <ReceiptItem>[];
    String? storeName;
    double? subtotal;
    double? tax;
    double? tip;
    double? total;

    // First line(s) before any prices are likely the store name
    bool foundFirstPrice = false;
    final storeNameParts = <String>[];

    for (final line in lines) {
      final text = line.map((b) => b.text).join(' ').trim();
      if (text.isEmpty) continue;

      final classification = _classifyLine(text, line);
      final price = _extractPrice(text, line);

      classifiedLines.add(ClassifiedLine(
        text: text,
        classification: classification,
        extractedPrice: price,
      ));

      if (!foundFirstPrice && price == null && !_shouldSkipLine(text)) {
        storeNameParts.add(text);
        continue;
      }
      foundFirstPrice = true;

      switch (classification) {
        case LineClassification.item:
          if (price != null) {
            final name = _extractItemName(text);
            items.add(ReceiptItem(name: name, price: price, rawText: text));
          }
          break;
        case LineClassification.subtotal:
          subtotal = price;
          break;
        case LineClassification.tax:
          tax = price;
          break;
        case LineClassification.tip:
          tip = price;
          break;
        case LineClassification.total:
          total = price;
          break;
        case LineClassification.storeName:
          storeNameParts.add(text);
          break;
        default:
          break;
      }
    }

    if (storeNameParts.isNotEmpty) {
      storeName = storeNameParts.first;
    }

    // Step 3: Validation
    final validationNotes = <String>[];
    _validate(items, subtotal, tax, tip, total, validationNotes);

    return ParsedReceipt(
      storeName: storeName,
      items: items,
      subtotal: subtotal,
      tax: tax,
      tip: tip,
      total: total,
      classifiedLines: classifiedLines,
      validationNotes: validationNotes,
    );
  }

  /// Group OCR blocks into lines based on Y-coordinate proximity.
  /// Blocks whose centerY values are within a threshold are on the same line.
  List<List<OcrTextBlock>> _groupIntoLines(List<OcrTextBlock> blocks) {
    if (blocks.isEmpty) return [];

    // Sort by Y first, then X
    final sorted = List<OcrTextBlock>.from(blocks)
      ..sort((a, b) {
        final yDiff = a.centerY - b.centerY;
        if (yDiff.abs() < 0.008) {
          return a.x.compareTo(b.x);
        }
        return yDiff.compareTo(0);
      });

    final lines = <List<OcrTextBlock>>[];
    var currentLine = <OcrTextBlock>[sorted.first];

    for (int i = 1; i < sorted.length; i++) {
      final block = sorted[i];
      final lastBlock = currentLine.last;

      // If this block's center Y is close to the current line's, same line
      final avgLineY = currentLine.fold(0.0, (sum, b) => sum + b.centerY) / currentLine.length;
      if ((block.centerY - avgLineY).abs() < 0.012) {
        currentLine.add(block);
      } else {
        // Sort current line left-to-right and start new line
        currentLine.sort((a, b) => a.x.compareTo(b.x));
        lines.add(currentLine);
        currentLine = [block];
      }
    }

    currentLine.sort((a, b) => a.x.compareTo(b.x));
    lines.add(currentLine);

    return lines;
  }

  LineClassification _classifyLine(String text, List<OcrTextBlock> blocks) {
    if (_shouldSkipLine(text)) return LineClassification.skipped;

    final hasPrice = _priceRegex.hasMatch(text);

    if (_totalKeywords.hasMatch(text) && !_subtotalKeywords.hasMatch(text)) {
      return hasPrice ? LineClassification.total : LineClassification.skipped;
    }
    if (_subtotalKeywords.hasMatch(text)) {
      return hasPrice ? LineClassification.subtotal : LineClassification.skipped;
    }
    if (_taxKeywords.hasMatch(text)) {
      return hasPrice ? LineClassification.tax : LineClassification.skipped;
    }
    if (_tipKeywords.hasMatch(text)) {
      return hasPrice ? LineClassification.tip : LineClassification.skipped;
    }

    if (hasPrice) {
      return LineClassification.item;
    }

    return LineClassification.unknown;
  }

  bool _shouldSkipLine(String text) {
    if (_dateRegex.hasMatch(text) && text.length < 30) return true;
    if (_timeRegex.hasMatch(text) && text.length < 20) return true;
    if (_phoneRegex.hasMatch(text)) return true;
    if (_cardRegex.hasMatch(text)) return true;
    if (_thankYouRegex.hasMatch(text)) return true;
    if (_addressRegex.hasMatch(text)) return true;
    if (text.length < 2) return true;
    return false;
  }

  double? _extractPrice(String text, List<OcrTextBlock> blocks) {
    // Look for right-aligned price blocks first (layout heuristic)
    for (final block in blocks.reversed) {
      if (block.rightEdge > 0.6) {
        final match = _priceRegex.firstMatch(block.text);
        if (match != null) {
          final priceStr = match.group(0)!.replaceAll('\$', '');
          return double.tryParse(priceStr);
        }
      }
    }

    // Fallback: find last price in the full line text
    final matches = _priceRegex.allMatches(text).toList();
    if (matches.isNotEmpty) {
      final priceStr = matches.last.group(0)!.replaceAll('\$', '');
      return double.tryParse(priceStr);
    }

    return null;
  }

  String _extractItemName(String text) {
    // Remove the price from the end
    var name = text.replaceAll(_priceRegex, '').trim();
    // Remove trailing dots, dashes used as separators
    name = name.replaceAll(RegExp(r'[\.\-]+$'), '').trim();
    // Remove leading quantity patterns like "1x" or "2 x"
    name = name.replaceFirst(RegExp(r'^\d+\s*[xX]\s*'), '').trim();
    return name.isEmpty ? text : name;
  }

  void _validate(
    List<ReceiptItem> items,
    double? subtotal,
    double? tax,
    double? tip,
    double? total,
    List<String> notes,
  ) {
    final itemsSum = items.fold(0.0, (sum, item) => sum + item.price);

    if (items.isEmpty) {
      notes.add('No line items detected');
    }

    if (subtotal != null && items.isNotEmpty) {
      final diff = (itemsSum - subtotal).abs();
      if (diff < 0.02) {
        notes.add('Items sum matches subtotal (\$${itemsSum.toStringAsFixed(2)})');
      } else {
        notes.add('Items sum (\$${itemsSum.toStringAsFixed(2)}) differs from subtotal (\$${subtotal.toStringAsFixed(2)}) by \$${diff.toStringAsFixed(2)}');
      }
    }

    if (total != null && subtotal != null && tax != null) {
      final expected = subtotal + tax + (tip ?? 0);
      final diff = (expected - total).abs();
      if (diff < 0.02) {
        notes.add('Subtotal + tax + tip matches total');
      } else {
        notes.add('Subtotal + tax + tip (\$${expected.toStringAsFixed(2)}) differs from total (\$${total.toStringAsFixed(2)}) by \$${diff.toStringAsFixed(2)}');
      }
    }

    if (total == null) {
      notes.add('No total detected');
    }
  }
}
