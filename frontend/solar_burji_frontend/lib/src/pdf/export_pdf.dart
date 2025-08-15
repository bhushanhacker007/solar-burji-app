import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PdfExporter {
  static Future<pw.ImageProvider?> _loadLogo() async {
    try {
      final bytes = await rootBundle.load('assets/logo.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _header(String title, String rangeText, pw.ImageProvider? logoProvider) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(children: [
            if (logoProvider != null)
              pw.Container(
                margin: const pw.EdgeInsets.only(right: 12),
                height: 36,
                width: 36,
                child: pw.Image(logoProvider),
              ),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Ganesh Center', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(title, style: const pw.TextStyle(fontSize: 12)),
            ]),
          ]),
          pw.Text(rangeText, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static Future<Uint8List> solarReport({
    required Map<String, dynamic> report,
    bool summaryOnly = false,
  }) async {
    final days = (report['days'] as List).cast<Map<String, dynamic>>();
    final doc = pw.Document();
    final range = report['range'] as Map<String, dynamic>;
    final df = DateFormat('yyyy-MM-dd');
    final logo = await _loadLogo();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          _header('Solar Report', 'Range: ${range['start']} to ${range['end']}', logo),
          if (!summaryOnly)
            _table([
              ['Date', 'Import (kWh)', 'Export (kWh)', 'Generation (kWh)', 'Notes'],
              ...days.map((d) => [
                    d['reading_date'],
                    d['import_kwh'].toString(),
                    d['export_kwh'].toString(),
                    d['generation_kwh'].toString(),
                    (d['notes'] ?? '').toString(),
                  ]),
            ]),
          _table([
            ['TOTALS',
              (report['total_import_kwh']).toString(),
              (report['total_export_kwh']).toString(),
              (report['total_generation_kwh']).toString(),
              ''
            ],
          ]),
          pw.SizedBox(height: 12),
          pw.Text('Generated: ${df.format(DateTime.now())}')
        ],
      ),
    );

    return doc.save();
  }

  static Future<Uint8List> salesReport({
    required Map<String, dynamic> report,
    bool groupedByDay = true,
    bool summaryOnly = false,
  }) async {
    final txns = (report['transactions'] as List).cast<Map<String, dynamic>>();
    final doc = pw.Document();
    final range = report['range'] as Map<String, dynamic>;
    final df = DateFormat('yyyy-MM-dd');
    final logo = await _loadLogo();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          _header('Sales Report', 'Range: ${range['start']} to ${range['end']}', logo),
          if (!summaryOnly)
            if (groupedByDay) ...[
              for (final entry in _groupBy(txns, (e) => e['txn_date'] as String).entries) ...[
                pw.SizedBox(height: 8),
                pw.Text('Date: ${entry.key}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                _table([
                  ['Amount (₹)', 'Payment', 'Note'],
                  ...entry.value.map((t) => [
                        t['amount'].toString(),
                        t['payment_method'],
                        (t['note'] ?? '').toString(),
                      ]),
                ]),
                _table([
                  ['Subtotal', entry.value.fold<num>(0, (p, t) => p + (t['amount'] as num)).toStringAsFixed(2), '', ''],
                ]),
              ]
            ]
            else
              _table([
                ['Date', 'Amount (₹)', 'Payment', 'Note'],
                ...txns.map((t) => [
                      t['txn_date'],
                      t['amount'].toString(),
                      t['payment_method'],
                      (t['note'] ?? '').toString(),
                    ]),
              ]),
          _table([
            ['TOTALS', (report['total_amount']).toString(), 'cash=${report['cash_amount']}; online=${report['online_amount']}', ''],
          ]),
          pw.SizedBox(height: 12),
          pw.Text('Generated: ${df.format(DateTime.now())}')
        ],
      ),
    );

    return doc.save();
  }

  static Future<Uint8List> borrowingsReport({
    required Map<String, dynamic> report,
    bool groupedByDay = true,
    bool summaryOnly = false,
  }) async {
    final entries = (report['entries'] as List).cast<Map<String, dynamic>>();
    final doc = pw.Document();
    final range = report['range'] as Map<String, dynamic>;
    final df = DateFormat('yyyy-MM-dd');
    final logo = await _loadLogo();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          _header('Borrowings Report', 'Range: ${range['start']} to ${range['end']}', logo),
          if (!summaryOnly)
            if (groupedByDay) ...[
              for (final entry in _groupBy(entries, (e) => e['txn_date'] as String).entries) ...[
                pw.SizedBox(height: 8),
                pw.Text('Date: ${entry.key}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                _table([
                  ['Customer', 'Amount (₹)', 'Type', 'Note'],
                  ...entry.value.map((e) => [
                        e['customer_name'],
                        e['amount'].toString(),
                        (e['is_repayment'] == 1 ? 'repayment' : 'borrow'),
                        (e['note'] ?? '').toString(),
                      ]),
                ]),
                _table([
                  ['Subtotal', entry.value.fold<num>(0, (p, e) => p + (e['amount'] as num)).toStringAsFixed(2), '', ''],
                ]),
              ]
            ]
            else
              _table([
                ['Date', 'Customer', 'Amount (₹)', 'Type', 'Note'],
                ...entries.map((e) => [
                      e['txn_date'],
                      e['customer_name'],
                      e['amount'].toString(),
                      (e['is_repayment'] == 1 ? 'repayment' : 'borrow'),
                      (e['note'] ?? '').toString(),
                    ]),
              ]),
          _table([
            ['TOTALS', '', 'borrow=${report['borrow_total']}; repayment=${report['repayment_total']}', 'net=${report['net_outstanding_change']}', ''],
          ]),
          pw.SizedBox(height: 12),
          pw.Text('Generated: ${df.format(DateTime.now())}')
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _table(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
      children: [
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(
            decoration: i == 0 ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEFEFEF)) : null,
            children: [
              for (final cell in rows[i])
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(cell, style: pw.TextStyle(fontSize: 10)),
                )
            ],
          )
      ],
    );
  }

  static Map<K, List<T>> _groupBy<T, K>(List<T> items, K Function(T) keyOf) {
    final map = <K, List<T>>{};
    for (final item in items) {
      final k = keyOf(item);
      map.putIfAbsent(k, () => []).add(item);
    }
    return map;
  }
}
