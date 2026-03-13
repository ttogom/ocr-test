import 'package:flutter/material.dart';
import 'pages/camera_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReceiptOcrApp());
}

class ReceiptOcrApp extends StatelessWidget {
  const ReceiptOcrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Receipt OCR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const CameraPage(),
    );
  }
}
