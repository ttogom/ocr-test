import 'package:flutter/material.dart';
import '../models/parsed_receipt.dart';
import '../services/ocr_bridge.dart';
import '../widgets/receipt_item_tile.dart';
import 'debug_page.dart';

class ResultPage extends StatelessWidget {
  final String imagePath;
  final OcrResult ocrResult;
  final ParsedReceipt parsedReceipt;

  const ResultPage({
    super.key,
    required this.imagePath,
    required this.ocrResult,
    required this.parsedReceipt,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug View',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DebugPage(
                    imagePath: imagePath,
                    ocrResult: ocrResult,
                    parsedReceipt: parsedReceipt,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          if (parsedReceipt.storeName != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                parsedReceipt.storeName!,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(),
          ],
          if (parsedReceipt.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No line items detected.\nTry the debug view for details.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          else
            ...parsedReceipt.items.map((item) => ReceiptItemTile(item: item)),
          if (parsedReceipt.items.isNotEmpty) ...[
            const Divider(indent: 16, endIndent: 16),
            _buildTotalRow('Items Sum', parsedReceipt.itemsSum),
          ],
          if (parsedReceipt.subtotal != null)
            _buildTotalRow('Subtotal', parsedReceipt.subtotal!),
          if (parsedReceipt.tax != null)
            _buildTotalRow('Tax', parsedReceipt.tax!),
          if (parsedReceipt.tip != null)
            _buildTotalRow('Tip', parsedReceipt.tip!),
          if (parsedReceipt.total != null) ...[
            const Divider(indent: 16, endIndent: 16),
            _buildTotalRow('Total', parsedReceipt.total!, bold: true),
          ],
          if (parsedReceipt.validationNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Validation',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            ...parsedReceipt.validationNotes.map(
              (note) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Text(
                  note,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontFamily: 'Menlo',
            ),
          ),
        ],
      ),
    );
  }
}
