import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/clients/model/client.dart';

/// Turns the (already filtered) client list into a PDF report or a CSV
/// file — "Exporter PDF" / "Exporter Excel" from the Clients & crédit
/// screen.
class ClientExportService {
  const ClientExportService();

  Future<void> exportPdf(List<Client> clients) async {
    final doc = pw.Document();
    final total = clients.fold<double>(0, (sum, c) => sum + c.creditTotal);
    final dateFmt = DateFormat('dd/MM/yyyy');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Clients & crédit',
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
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('Nom', bold: true),
                  _cell('Téléphone', bold: true),
                  _cell('Solde dû', bold: true, alignRight: true),
                ],
              ),
              for (final c in clients)
                pw.TableRow(
                  children: [
                    _cell(c.nom),
                    _cell(c.telephone),
                    _cell(AppFormat.dt(c.creditTotal), alignRight: true),
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
    await Printing.sharePdf(bytes: bytes, filename: 'clients.pdf');
  }

  Future<void> exportCsv(List<Client> clients) async {
    final buffer = StringBuffer()
      ..writeln('Nom;Téléphone;Solde dû (DT);Limite crédit (DT)');
    for (final c in clients) {
      buffer.writeln(
        [
          c.nom.replaceAll(';', ','),
          c.telephone,
          c.creditTotal.toStringAsFixed(3),
          c.limiteCredit?.toStringAsFixed(3) ?? '',
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
          XFile.fromData(bytes, name: 'clients.csv', mimeType: 'text/csv'),
        ],
        subject: 'Clients & crédit',
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

const clientExportService = ClientExportService();
