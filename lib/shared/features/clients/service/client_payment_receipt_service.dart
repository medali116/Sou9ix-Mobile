import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:sou9ix/shared/core/formatters.dart';

/// Builds a small printable receipt for a karné payment — "Imprimer reçu"
/// on the post-encaissement confirmation.
class ClientPaymentReceiptService {
  const ClientPaymentReceiptService();

  Future<void> print({
    required String clientNom,
    required double montant,
    required double soldeRestant,
  }) async {
    final doc = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy · HH:mm').format(DateTime.now());

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(16),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Sou9ix',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Reçu de paiement',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(dateStr, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              _row('Client', clientNom),
              _row('Montant reçu', AppFormat.dt(montant), bold: true),
              _row('Solde restant', AppFormat.dt(soldeRestant)),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Merci !',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();
    await Printing.layoutPdf(onLayout: (_) => bytes, name: 'recu_paiement.pdf');
  }

  pw.Widget _row(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: bold ? 11 : 9,
      fontWeight: bold ? pw.FontWeight.bold : null,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }
}

const clientPaymentReceiptService = ClientPaymentReceiptService();
