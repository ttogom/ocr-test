import 'dart:io';
import 'package:flutter/material.dart';
import '../models/ocr_text_block.dart';
import '../models/parsed_receipt.dart';
import '../services/ocr_bridge.dart';
import '../widgets/bounding_box_overlay.dart';

class DebugPage extends StatelessWidget {
  final String imagePath;
  final OcrResult ocrResult;
  final ParsedReceipt parsedReceipt;

  const DebugPage({
    super.key,
    required this.imagePath,
    required this.ocrResult,
    required this.parsedReceipt,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Debug'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Bounding Boxes'),
              Tab(text: 'Raw OCR'),
              Tab(text: 'Parsed'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _BoundingBoxTab(
              imagePath: imagePath,
              ocrResult: ocrResult,
            ),
            _RawOcrTab(blocks: ocrResult.textBlocks),
            _ParsedTab(parsedReceipt: parsedReceipt),
          ],
        ),
      ),
    );
  }
}

class _BoundingBoxTab extends StatefulWidget {
  final String imagePath;
  final OcrResult ocrResult;

  const _BoundingBoxTab({
    required this.imagePath,
    required this.ocrResult,
  });

  @override
  State<_BoundingBoxTab> createState() => _BoundingBoxTabState();
}

class _BoundingBoxTabState extends State<_BoundingBoxTab> {
  bool _showEnhanced = true;

  String get _displayImagePath {
    if (_showEnhanced && widget.ocrResult.enhancedImagePath != null) {
      return widget.ocrResult.enhancedImagePath!;
    }
    return widget.imagePath;
  }

  @override
  Widget build(BuildContext context) {
    final hasEnhanced = widget.ocrResult.enhancedImagePath != null;

    return Column(
      children: [
        if (hasEnhanced)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Text('Enhanced', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                Switch(
                  value: _showEnhanced,
                  onChanged: (v) => setState(() => _showEnhanced = v),
                ),
                const Spacer(),
                Text(
                  _showEnhanced ? 'What Vision saw' : 'Original',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        Expanded(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Image.file(
                      File(_displayImagePath),
                      fit: BoxFit.contain,
                      width: constraints.maxWidth,
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: BoundingBoxOverlay(
                          blocks: widget.ocrResult.textBlocks,
                          imageSize: Size(
                            widget.ocrResult.imageWidth.toDouble(),
                            widget.ocrResult.imageHeight.toDouble(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _RawOcrTab extends StatelessWidget {
  final List<OcrTextBlock> blocks;

  const _RawOcrTab({required this.blocks});

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) {
      return const Center(child: Text('No text blocks detected'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        final block = blocks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'conf: ${(block.confidence * 100).toStringAsFixed(1)}%  '
                  'pos: (${block.x.toStringAsFixed(3)}, ${block.y.toStringAsFixed(3)})  '
                  'size: ${block.width.toStringAsFixed(3)} x ${block.height.toStringAsFixed(3)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Menlo',
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ParsedTab extends StatelessWidget {
  final ParsedReceipt parsedReceipt;

  const _ParsedTab({required this.parsedReceipt});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionHeader('Line Classifications'),
        ...parsedReceipt.classifiedLines.map((line) {
          final color = _colorForClassification(line.classification);
          return Card(
            margin: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              dense: true,
              leading: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              title: Text(
                line.text,
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                '${line.classification.name}'
                '${line.extractedPrice != null ? '  \$${line.extractedPrice!.toStringAsFixed(2)}' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontFamily: 'Menlo',
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        _sectionHeader('Validation'),
        if (parsedReceipt.validationNotes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('No validation notes', style: TextStyle(color: Colors.grey)),
          )
        else
          ...parsedReceipt.validationNotes.map(
            (note) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              child: Text(note, style: const TextStyle(fontSize: 13)),
            ),
          ),
        const SizedBox(height: 16),
        _sectionHeader('Summary'),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Store: ${parsedReceipt.storeName ?? "N/A"}\n'
            'Items: ${parsedReceipt.items.length}\n'
            'Items sum: \$${parsedReceipt.itemsSum.toStringAsFixed(2)}\n'
            'Subtotal: ${parsedReceipt.subtotal?.toStringAsFixed(2) ?? "N/A"}\n'
            'Tax: ${parsedReceipt.tax?.toStringAsFixed(2) ?? "N/A"}\n'
            'Tip: ${parsedReceipt.tip?.toStringAsFixed(2) ?? "N/A"}\n'
            'Total: ${parsedReceipt.total?.toStringAsFixed(2) ?? "N/A"}',
            style: const TextStyle(fontSize: 13, fontFamily: 'Menlo', height: 1.6),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _colorForClassification(LineClassification classification) {
    switch (classification) {
      case LineClassification.item:
        return Colors.blue;
      case LineClassification.subtotal:
        return Colors.orange;
      case LineClassification.tax:
        return Colors.purple;
      case LineClassification.tip:
        return Colors.teal;
      case LineClassification.total:
        return Colors.green;
      case LineClassification.storeName:
        return Colors.indigo;
      case LineClassification.skipped:
        return Colors.grey;
      case LineClassification.unknown:
        return Colors.grey.shade400;
    }
  }
}
