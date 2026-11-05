import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class PickedFile {
  PickedFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

/// Cross-platform save / share / pick / open helpers.
class FileActions {
  static bool get _isDesktop => Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// iOS & Android: opens the system share sheet (Save to Files, AirDrop,
  /// Mail...). macOS: shows a Save dialog.
  static Future<void> exportFile(
    BuildContext context, {
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    if (_isDesktop) {
      final path = await FilePicker.platform.saveFile(fileName: fileName, bytes: bytes);
      if (path != null) {
        final f = File(path);
        if (!await f.exists() || await f.length() == 0) await f.writeAsBytes(bytes, flush: true);
      }
      return;
    }
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: mimeType)],
      sharePositionOrigin: origin,
    ));
  }

  static Future<PickedFile?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: Platform.isMacOS ? FileType.custom : FileType.any,
      allowedExtensions: Platform.isMacOS ? ['json'] : null,
      withData: true,
    );
    return _first(result);
  }

  static Future<PickedFile?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    return _first(result);
  }

  static Future<List<PickedFile>> pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'heic', 'gif', 'webp'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return [];
    final out = <PickedFile>[];
    for (final f in result.files) {
      final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
      if (bytes != null) out.add(PickedFile(f.name, bytes));
    }
    return out;
  }

  static Future<PickedFile?> _first(FilePickerResult? result) async {
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
    return bytes == null ? null : PickedFile(f.name, bytes);
  }

  /// Opens a file in the platform's default viewer (Quick Look style).
  static Future<void> openWithSystem(String sourcePath, String fileName) async {
    final tmp = await getTemporaryDirectory();
    final copy = File('${tmp.path}/${DateTime.now().millisecondsSinceEpoch}-$fileName');
    await File(sourcePath).copy(copy.path);
    if (Platform.isMacOS) {
      await launchUrl(Uri.file(copy.path));
    } else {
      await OpenFilex.open(copy.path);
    }
  }
}
