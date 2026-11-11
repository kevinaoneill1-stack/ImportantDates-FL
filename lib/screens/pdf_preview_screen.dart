import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../services/file_actions.dart';
import '../widgets/common.dart';

/// Shows a PDF before it is exported. Export opens the share sheet (iOS,
/// Android) or a Save dialog (macOS), as before.
Future<void> previewPdf(BuildContext context, {required String title, required Uint8List bytes, required String fileName}) =>
    pushPage(context, PdfPreviewScreen(title: title, bytes: bytes, fileName: fileName));

class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({super.key, required this.title, required this.bytes, required this.fileName});
  final String title;
  final Uint8List bytes;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Builder(
            builder: (c) => TextButton.icon(
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Export'),
              onPressed: () => FileActions.exportFile(c, bytes: bytes, fileName: fileName, mimeType: 'application/pdf'),
            ),
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) => bytes,
        pdfFileName: fileName,
        useActions: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
      ),
    );
  }
}
