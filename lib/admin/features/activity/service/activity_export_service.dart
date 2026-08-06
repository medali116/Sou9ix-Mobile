import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:sou9ix/shared/features/activity/model/activity_log_entry.dart';

/// Turns the (already filtered) journal entries into a PDF report or a CSV
/// file — "Exporter PDF" / "Exporter Excel" from the Journal d'activité.
class ActivityExportService {
  const ActivityExportService();

  Future<void> exportPdf(List<ActivityLogEntry> entries) async {
    final doc = pw.Document();
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Journal d\'activité',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Généré le ${dateFmt.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(3),
              4: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('Date', bold: true),
                  _cell('Employé', bold: true),
                  _cell('Catégorie', bold: true),
                  _cell('Action', bold: true),
                  _cell('Détails', bold: true),
                ],
              ),
              for (final e in entries)
                pw.TableRow(
                  children: [
                    _cell(dateFmt.format(e.date)),
                    _cell(e.employeeName),
                    _cell(e.category.label),
                    _cell(
                      '${e.action}${e.targetName != null ? ' — ${e.targetName}' : ''}',
                    ),
                    _cell(
                      e.isFieldChange
                          ? '${e.champ} : ${e.ancienneValeur} → ${e.nouvelleValeur}'
                          : (e.motif ?? ''),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: 'journal_activite.pdf');
  }

  Future<void> exportCsv(List<ActivityLogEntry> entries) async {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final buffer = StringBuffer()
      ..writeln(
        'Date;Employé;Catégorie;Action;Cible;Champ;Ancienne valeur;Nouvelle valeur;Motif;Montant',
      );
    for (final e in entries) {
      buffer.writeln(
        [
          dateFmt.format(e.date),
          e.employeeName,
          e.category.label,
          e.action,
          (e.targetName ?? '').replaceAll(';', ','),
          e.champ ?? '',
          e.ancienneValeur ?? '',
          e.nouvelleValeur ?? '',
          (e.motif ?? '').replaceAll(';', ','),
          e.montant?.toStringAsFixed(3) ?? '',
        ].join(';'),
      );
    }

    final bytes = Uint8List.fromList([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(buffer.toString()),
    ]);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            name: 'journal_activite.csv',
            mimeType: 'text/csv',
          ),
        ],
        subject: 'Journal d\'activité',
      ),
    );
  }

  pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: bold ? pw.FontWeight.bold : null,
        ),
      ),
    );
  }
}

const activityExportService = ActivityExportService();
