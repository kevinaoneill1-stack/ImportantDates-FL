import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/important_date.dart';
import '../utils/date_utils.dart';

/// Branded A4 PDF reports, matching the native PDFReportHelper layout.
class PdfReport {
  static const _blue = PdfColor(0.16, 0.39, 0.92);
  static const _green = PdfColor(0.12, 0.66, 0.43);
  static const _red = PdfColor(0.90, 0.22, 0.27);
  static const _orange = PdfColor(0.95, 0.55, 0.12);
  static const _grey = PdfColor(0.45, 0.45, 0.50);

  static Future<Uint8List> createItemsPdf(String title, List<ImportantDate> items) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
    final doc = pw.Document(
      title: title,
      author: 'Important Dates',
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final generated = DateFormatting.dateTimeShort(DateTime.now());

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 42, 42, 40),
      header: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          width: 54,
          height: 8,
          decoration: pw.BoxDecoration(color: _blue, borderRadius: pw.BorderRadius.circular(4)),
        ),
        pw.SizedBox(height: 12),
        pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Important Dates • Generated $generated',
            style: const pw.TextStyle(fontSize: 10, color: _grey)),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
        pw.SizedBox(height: 8),
      ]),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber}', style: const pw.TextStyle(fontSize: 9, color: _grey)),
      ),
      build: (ctx) {
        if (items.isEmpty) {
          return [pw.Text('No items matched this report.', style: const pw.TextStyle(fontSize: 14, color: _grey))];
        }
        return [
          pw.Text('${items.length} ${items.length == 1 ? 'item' : 'items'}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _grey)),
          pw.SizedBox(height: 10),
          for (final i in items) ..._itemWidgets(i),
        ];
      },
    ));
    return doc.save();
  }

  static PdfColor _accent(ImportantDate i) {
    if (i.isAccomplished) return _green;
    if (i.daysRemaining < 0) return _red;
    if (i.daysRemaining <= 30) return _orange;
    return _blue;
  }

  static String _reminders(ImportantDate i) {
    final days = i.selectedReminderDays;
    if (days.isEmpty) return '${i.notificationDays} days before';
    return '${days.map((d) => '$d days').join(', ')} before';
  }

  static pw.Widget _row(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(
            width: 105,
            child: pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _grey)),
          ),
          pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 10))),
        ]),
      );

  /// Each record is emitted as separate rows so long records and notes can
  /// flow across page breaks.
  static List<pw.Widget> _itemWidgets(ImportantDate i) {
    final accent = _accent(i);
    final notes = i.notes.trim();
    final files = [...i.attachments]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return [
      pw.Container(
        height: 6,
        decoration: pw.BoxDecoration(
          color: PdfColor(accent.red, accent.green, accent.blue, 0.15),
          borderRadius: pw.BorderRadius.circular(3),
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Text(i.item, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.Text(i.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: accent)),
      pw.SizedBox(height: 4),
      if (i.isAccomplished) ...[
        _row('Status', 'Completed'),
        _row('Completed', DateFormatting.abbreviated(i.accomplishedDate ?? i.dueDate)),
        _row('Original due', DateFormatting.abbreviated(i.dueDate)),
      ] else ...[
        _row('Status', i.daysRemaining < 0 ? 'Overdue' : 'Current'),
        _row('Due', DateFormatting.abbreviated(i.dueDate)),
        _row('Timing', i.daysRemaining < 0 ? '${-i.daysRemaining} days overdue' : '${i.daysRemaining} days remaining'),
        _row('Reminders', _reminders(i)),
      ],
      _row('Travel document', i.isTravelDocument ? 'Yes' : 'No'),
      if (files.isEmpty)
        _row('Attachments', 'None')
      else ...[
        _row('Attachments', '${files.length}'),
        _row('Files', files.map((f) => f.fileName).join(', ')),
      ],
      if (notes.isNotEmpty) ...[
        pw.SizedBox(height: 3),
        pw.Text('Notes', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _grey)),
        pw.Paragraph(text: notes, style: const pw.TextStyle(fontSize: 11)),
      ],
      pw.SizedBox(height: 14),
    ];
  }
}
