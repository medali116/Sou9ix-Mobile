import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:sou9ix/shared/core/formatters.dart';
import 'package:sou9ix/shared/features/expenses/model/expense.dart';

/// Turns a list of expenses (e.g. "ce mois", already filtered by the
/// screen) into a PDF report or a CSV file an accountant can open directly
/// in Excel — "Exporter PDF" / "Exporter Excel" from the Dépenses screen.
class ExpenseExportService {
  const ExpenseExportService();

  Future<void> exportPdf(
    List<Expense> expenses, {
    String title = 'Dépenses',
  }) async {
    final doc = pw.Document();
    final total = expenses.fold<double>(0, (sum, e) => sum + e.montant);
    final dateFmt = DateFormat('dd/MM/yyyy');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            title,
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
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(2),
              4: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('Date', bold: true),
                  _cell('Libellé', bold: true),
                  _cell('Catégorie', bold: true),
                  _cell('Statut', bold: true),
                  _cell('Montant', bold: true, alignRight: true),
                ],
              ),
              for (final e in expenses)
                pw.TableRow(
                  children: [
                    _cell(dateFmt.format(e.date)),
                    _cell(e.label),
                    _cell(e.categorie.label),
                    _cell(e.paye ? 'Payée' : 'Non payée'),
                    _cell(AppFormat.dt(e.montant), alignRight: true),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total : ${AppFormat.dt(total)}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: 'depenses.pdf');
  }

  Future<void> exportCsv(List<Expense> expenses) async {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final buffer = StringBuffer()
      ..writeln(
        'Date;Libellé;Catégorie;Statut;Récurrente;Ajoutée par;Montant (DT)',
      );
    for (final e in expenses) {
      buffer.writeln(
        [
          dateFmt.format(e.date),
          e.label.replaceAll(';', ','),
          e.categorie.label,
          e.paye ? 'Payée' : 'Non payée',
          e.recurrente ? 'Oui' : 'Non',
          e.ajouteePar ?? '',
          e.montant.toStringAsFixed(3),
        ].join(';'),
      );
    }

    // UTF-8 BOM so Excel renders accented French characters correctly.
    final bytes = Uint8List.fromList([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(buffer.toString()),
    ]);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, name: 'depenses.csv', mimeType: 'text/csv'),
        ],
        subject: 'Dépenses & charges',
      ),
    );
  }

  pw.Widget _cell(String text, {bool bold = false, bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: bold ? pw.FontWeight.bold : null,
        ),
      ),
    );
  }
}

const expenseExportService = ExpenseExportService();
