import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:sou9ix/shared/core/formatters.dart';
import 'package:sou9ix/shared/features/sales/model/sale.dart';

/// Builds a printable/shareable PDF ticket for a [Sale] and hands it to the
/// OS print/share sheet via the `printing` package — covers "imprimer",
/// "réimprimer" (same sale, opened again from l'historique) and exporting
/// the ticket as a real PDF file with a single flow. [nomTicket] and
/// [logoBytes] come from Profil → "Gestion de l'entreprise".
class TicketPdfService {
  const TicketPdfService();

  Future<void> printOrShare(
    Sale sale, {
    String nomTicket = 'Sou9ix',
    Uint8List? logoBytes,
  }) async {
    final doc = _build(sale, nomTicket, logoBytes);
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'ticket_${sale.id}.pdf',
    );
  }

  pw.Document _build(Sale sale, String nomTicket, Uint8List? logoBytes) {
    final doc = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy · HH:mm').format(sale.dateHeure);

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
                    if (logoBytes != null)
                      pw.Image(pw.MemoryImage(logoBytes), width: 48, height: 48)
                    else
                      pw.Text(
                        nomTicket,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    pw.Text(
                      'Épicerie El Baraka — La Marsa',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(dateStr, style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      'Ticket #${sale.id.substring(sale.id.length - 6).toUpperCase()}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              if (sale.lignes.isEmpty)
                pw.Text(
                  'Détails de vente indisponibles.',
                  style: const pw.TextStyle(fontSize: 9),
                )
              else
                ...sale.lignes.map(
                  (l) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text(
                            l.discount.isNone
                                ? l.product.name
                                : '${l.product.name} (${l.discount.label((v) => v.toStringAsFixed(2))})',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            l.product.venduAuPoids
                                ? AppFormat.kg(l.quantite)
                                : 'x${l.quantite.toInt()}',
                            style: const pw.TextStyle(fontSize: 9),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            AppFormat.dtShort(l.sousTotal),
                            style: const pw.TextStyle(fontSize: 9),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              pw.Divider(),
              _row('Mode de paiement', sale.modePaiement.label),
              if (!sale.discount.isNone) ...[
                _row('Sous-total', AppFormat.dtShort(sale.sousTotal)),
                _row('Remise', sale.discount.label(AppFormat.dtShort)),
              ],
              pw.SizedBox(height: 4),
              _row('Total TTC', AppFormat.dt(sale.total), bold: true),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Merci de votre visite !',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.BarcodeWidget(
                  data: sale.id,
                  barcode: pw.Barcode.qrCode(),
                  width: 60,
                  height: 60,
                  drawText: false,
                ),
              ),
            ],
          );
        },
      ),
    );
    return doc;
  }

  pw.Widget _row(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: bold ? 11 : 9,
      fontWeight: bold ? pw.FontWeight.bold : null,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
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

const ticketPdfService = TicketPdfService();
