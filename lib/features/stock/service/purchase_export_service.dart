import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/stock/model/purchase_invoice.dart';

/// Turns the (already filtered) invoice list into a PDF report or a CSV
/// file — "Exporter PDF" / "Exporter Excel" from the Achats fournisseurs
/// screen.
class PurchaseExportService {
  const PurchaseExportService();

  Future<void> exportPdf(List<PurchaseInvoice> invoices) async {
    final doc = pw.Document();
    final total = invoices.fold<double>(0, (sum, i) => sum + i.montantTotal);
    final restant = invoices.fold<double>(
      0,
      (sum, i) => sum + i.montantRestant,
    );
    final dateFmt = DateFormat('dd/MM/yyyy');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Achats fournisseurs',
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
              3: pw.FlexColumnWidth(2),
              4: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('Fournisseur', bold: true),
                  _cell('Référence', bold: true),
                  _cell('Date', bold: true),
                  _cell('Total', bold: true, alignRight: true),
                  _cell('Reste', bold: true, alignRight: true),
                ],
              ),
              for (final i in invoices)
                pw.TableRow(
                  children: [
                    _cell(i.fournisseurNom ?? 'Fournisseur non précisé'),
                    _cell(i.reference),
                    _cell(dateFmt.format(i.date)),
                    _cell(AppFormat.dt(i.montantTotal), alignRight: true),
                    _cell(
                      i.soldee ? 'Soldée' : AppFormat.dt(i.montantRestant),
                      alignRight: true,
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Total achats : ${AppFormat.dt(total)}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Reste à payer : ${AppFormat.dt(restant)}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: 'achats_fournisseurs.pdf');
  }

  Future<void> exportCsv(List<PurchaseInvoice> invoices) async {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final buffer = StringBuffer()
      ..writeln('Fournisseur;Référence;Date;Total (DT);Payé (DT);Reste (DT)');
    for (final i in invoices) {
      buffer.writeln(
        [
          (i.fournisseurNom ?? '').replaceAll(';', ','),
          i.reference,
          dateFmt.format(i.date),
          i.montantTotal.toStringAsFixed(3),
          i.montantPaye.toStringAsFixed(3),
          i.montantRestant.toStringAsFixed(3),
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
            name: 'achats_fournisseurs.csv',
            mimeType: 'text/csv',
          ),
        ],
        subject: 'Achats fournisseurs',
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

const purchaseExportService = PurchaseExportService();
