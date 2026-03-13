import 'package:flutter/material.dart';
import '../models/parsed_receipt.dart';

class ReceiptItemTile extends StatelessWidget {
  final ReceiptItem item;

  const ReceiptItemTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            '\$${item.price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'Menlo',
            ),
          ),
        ],
      ),
    );
  }
}
