import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ocr/models/ocr_text_block.dart';
import 'package:receipt_ocr/services/receipt_parser.dart';
import 'package:receipt_ocr/models/parsed_receipt.dart';

void main() {
  late ReceiptParser parser;

  setUp(() {
    parser = ReceiptParser();
  });

  group('ReceiptParser', () {
    test('parses simple receipt with items and total', () {
      final blocks = [
        _block('BURGER JOINT', x: 0.2, y: 0.05),
        _block('Cheeseburger', x: 0.05, y: 0.20),
        _block('\$8.99', x: 0.75, y: 0.20),
        _block('Fries', x: 0.05, y: 0.25),
        _block('\$3.49', x: 0.75, y: 0.25),
        _block('Soda', x: 0.05, y: 0.30),
        _block('\$2.00', x: 0.75, y: 0.30),
        _block('Subtotal', x: 0.05, y: 0.40),
        _block('\$14.48', x: 0.75, y: 0.40),
        _block('Tax', x: 0.05, y: 0.45),
        _block('\$1.30', x: 0.75, y: 0.45),
        _block('Total', x: 0.05, y: 0.50),
        _block('\$15.78', x: 0.75, y: 0.50),
      ];

      final result = parser.parse(blocks);

      expect(result.storeName, 'BURGER JOINT');
      expect(result.items.length, 3);
      expect(result.items[0].name, 'Cheeseburger');
      expect(result.items[0].price, 8.99);
      expect(result.items[1].name, 'Fries');
      expect(result.items[1].price, 3.49);
      expect(result.items[2].name, 'Soda');
      expect(result.items[2].price, 2.00);
      expect(result.subtotal, 14.48);
      expect(result.tax, 1.30);
      expect(result.total, 15.78);
    });

    test('handles single-block lines with embedded prices', () {
      final blocks = [
        _block('MY STORE', x: 0.3, y: 0.05),
        _block('Coffee \$4.50', x: 0.05, y: 0.20, w: 0.8),
        _block('Muffin \$3.25', x: 0.05, y: 0.25, w: 0.8),
        _block('Total \$7.75', x: 0.05, y: 0.35, w: 0.8),
      ];

      final result = parser.parse(blocks);

      expect(result.items.length, 2);
      expect(result.items[0].price, 4.50);
      expect(result.items[1].price, 3.25);
      expect(result.total, 7.75);
    });

    test('skips date, phone, and card lines', () {
      final blocks = [
        _block('RESTAURANT', x: 0.3, y: 0.05),
        _block('01/15/2024', x: 0.3, y: 0.10),
        _block('(555) 123-4567', x: 0.2, y: 0.12),
        _block('VISA XXXX1234', x: 0.2, y: 0.14),
        _block('Pasta \$12.00', x: 0.05, y: 0.30, w: 0.8),
        _block('Total \$12.00', x: 0.05, y: 0.40, w: 0.8),
      ];

      final result = parser.parse(blocks);

      expect(result.items.length, 1);
      expect(result.items[0].name, 'Pasta');
      expect(result.total, 12.00);
    });

    test('detects tip', () {
      final blocks = [
        _block('Pizza \$15.00', x: 0.05, y: 0.20, w: 0.8),
        _block('Tax \$1.35', x: 0.05, y: 0.30, w: 0.8),
        _block('Tip \$3.00', x: 0.05, y: 0.35, w: 0.8),
        _block('Total \$19.35', x: 0.05, y: 0.40, w: 0.8),
      ];

      final result = parser.parse(blocks);

      expect(result.tip, 3.00);
      expect(result.tax, 1.35);
      expect(result.total, 19.35);
    });

    test('returns empty receipt for no blocks', () {
      final result = parser.parse([]);

      expect(result.items, isEmpty);
      expect(result.storeName, isNull);
      expect(result.validationNotes, contains('No text blocks found'));
    });

    test('validation notes when items sum matches subtotal', () {
      final blocks = [
        _block('Item A', x: 0.05, y: 0.20),
        _block('\$5.00', x: 0.75, y: 0.20),
        _block('Item B', x: 0.05, y: 0.25),
        _block('\$3.00', x: 0.75, y: 0.25),
        _block('Subtotal', x: 0.05, y: 0.35),
        _block('\$8.00', x: 0.75, y: 0.35),
        _block('Total', x: 0.05, y: 0.40),
        _block('\$8.00', x: 0.75, y: 0.40),
      ];

      final result = parser.parse(blocks);

      expect(result.validationNotes, anyElement(contains('matches subtotal')));
    });

    test('handles quantity prefix in item names', () {
      final blocks = [
        _block('2x Taco \$6.00', x: 0.05, y: 0.20, w: 0.8),
      ];

      final result = parser.parse(blocks);

      expect(result.items.length, 1);
      expect(result.items[0].name, 'Taco');
      expect(result.items[0].price, 6.00);
    });

  });
}

OcrTextBlock _block(
  String text, {
  double x = 0.05,
  double y = 0.10,
  double w = 0.3,
  double h = 0.02,
  double confidence = 0.95,
}) {
  return OcrTextBlock(
    text: text,
    x: x,
    y: y,
    width: w,
    height: h,
    confidence: confidence,
  );
}
