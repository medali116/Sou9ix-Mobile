import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/caisse/viewmodel/cash_session_provider.dart';
import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/employees/model/shift.dart';

/// Builds a printable/shareable PDF of a cash session's movement journal.
///
/// Deliberately mirrors [showMaCaisseSheet] in what it omits: no computed
/// "total en caisse" while the session is still open — the same reason the
/// on-screen sheet hides it applies here, since a cashier could otherwise
/// print this report themselves and read the expected-cash figure it would
/// have shown instead of counting blind.
class CaisseReportPdfService {
  const CaisseReportPdfService();

  Future<void> printOrShare({
    required Shift shift,
    required Employee employee,
    required List<CashMovement> movements,
  }) async {
    final doc = _build(shift, employee, movements);
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'rapport_caisse_${shift.id}.pdf',
    );
  }

  pw.Document _build(
    Shift shift,
    Employee employee,
    List<CashMovement> movements,
  ) {
    final doc = pw.Document();
    final dateFmt = DateFormat('dd/MM/yyyy · HH:mm');
    final periode = shift.clockOut == null
        ? 'Depuis le ${dateFmt.format(shift.clockIn)}'
        : '${dateFmt.format(shift.clockIn)} → ${dateFmt.format(shift.clockOut!)}';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Rapport de caisse',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Employé : ${employee.nom}',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.Text(periode, style: const pw.TextStyle(fontSize: 11)),
              pw.Text(
                shift.enCours ? 'Statut : Ouverte' : 'Statut : Clôturée',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder(
                  horizontalInside: const pw.BorderSide(
                    width: 0.5,
                    color: PdfColors.grey400,
                  ),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(4),
                  2: pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _cell('Heure', bold: true),
                      _cell('Mouvement', bold: true),
                      _cell('Montant', bold: true, alignRight: true),
                    ],
                  ),
                  for (final m in movements)
                    pw.TableRow(
                      children: [
                        _cell(DateFormat('HH:mm').format(m.date)),
                        _cell(m.label),
                        _cell(
                          '${m.montant >= 0 ? '+' : ''}${AppFormat.dt(m.montant)}',
                          alignRight: true,
                        ),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Document généré le ${dateFmt.format(DateTime.now())} — usage interne.',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          );
        },
      ),
    );
    return doc;
  }

  pw.Widget _cell(String text, {bool bold = false, bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
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

const caisseReportPdfService = CaisseReportPdfService();
