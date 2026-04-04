// ============================================================
// FILE: lib/components/reservation_pdf_button.dart
//
// DEPENDENCIES — add to pubspec.yaml:
//   pdf: ^3.11.0
//   printing: ^5.13.1
//
// USAGE in ReservationViewScreen build():
//   if (selectedReservation?.requestStatus == 'Approved')
//     ReservationPdfButton(
//       reservation: selectedReservation!,
//       hotels: selectedHotels,
//       flights: selectedFlights,
//     ),
// ============================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:ballys_reservation_app/models/reservation.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_desc.dart';
import 'package:ballys_reservation_app/models/reservation/flight_booking.dart';

class ReservationPdfButton extends StatefulWidget {
  final Reservation reservation;
  final List<HotelDescip> hotels;
  final List<FlightBooking> flights;

  const ReservationPdfButton({
    super.key,
    required this.reservation,
    required this.hotels,
    required this.flights,
  });

  @override
  State<ReservationPdfButton> createState() => _ReservationPdfButtonState();
}

class _ReservationPdfButtonState extends State<ReservationPdfButton> {
  // ── Cached fonts (loaded once in initState) ──────────────────────────────
  pw.Font? _ttf;
  pw.Font? _ttfBold;
  pw.Font? _ttfLight;
  bool _fontsReady = false;

  @override
  void initState() {
    super.initState();
    _preloadFonts();
  }

  // ── Preload fonts eagerly so the asset system is ready ───────────────────
  Future<void> _preloadFonts() async {
    try {
      final regular = await PdfGoogleFonts.nunitoRegular();
      final bold    = await PdfGoogleFonts.nunitoBold();
      final light   = await PdfGoogleFonts.nunitoLight();
      if (mounted) {
        setState(() {
          _ttf        = regular;
          _ttfBold    = bold;
          _ttfLight   = light;
          _fontsReady = true;
        });
      }
    } catch (e) {
      debugPrint('Font preload failed: $e');
    }
  }

  // ── Date helpers ─────────────────────────────────────────────────────────
  String _fmt(DateTime dt) {
    final day    = dt.day.toString().padLeft(2, '0');
    final month  = dt.month.toString().padLeft(2, '0');
    final year   = dt.year.toString();
    final hour   = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12    = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$day/$month/$year  ${h12.toString().padLeft(2, '0')}:$minute $period';
  }

  String _fmtDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  // ── PDF builder ──────────────────────────────────────────────────────────
  Future<pw.Document> _buildPdf() async {
    // Use preloaded fonts — fallback-load only if somehow not cached yet
    final ttf      = _ttf      ?? await PdfGoogleFonts.nunitoRegular();
    final ttfBold  = _ttfBold  ?? await PdfGoogleFonts.nunitoBold();
    final ttfLight = _ttfLight ?? await PdfGoogleFonts.nunitoLight();

    final pdf = pw.Document();

    // ── Colour palette ────────────────────────────────────────────────────
    const headerBg  = PdfColor.fromInt(0xFF1B5E20); // deep green
    const sectionBg = PdfColor.fromInt(0xFFE8F5E9); // light green tint
    const accentCol = PdfColor.fromInt(0xFF2E7D32); // medium green
    const lineColor = PdfColor.fromInt(0xFFB2DFDB);
    const textDark  = PdfColor.fromInt(0xFF212121);
    const textGrey  = PdfColor.fromInt(0xFF616161);

    // ── Text styles ───────────────────────────────────────────────────────
    final titleStyle = pw.TextStyle(
      font: ttfBold, fontSize: 20, color: PdfColors.white,
    );
    final subtitleStyle = pw.TextStyle(
      font: ttf, fontSize: 11, color: PdfColors.white,
    );
    final sectionHeadStyle = pw.TextStyle(
      font: ttfBold, fontSize: 11, color: accentCol,
    );
    final labelStyle = pw.TextStyle(
      font: ttfBold, fontSize: 10, color: textDark,
    );
    final valueStyle = pw.TextStyle(
      font: ttf, fontSize: 10, color: textGrey,
    );
    final smallBold = pw.TextStyle(
      font: ttfBold, fontSize: 9, color: textDark,
    );
    final smallVal = pw.TextStyle(
      font: ttfLight, fontSize: 9, color: textGrey,
    );
    final footerStyle = pw.TextStyle(
      font: ttfLight, fontSize: 8, color: textGrey,
    );

    // ── Helper: divider ───────────────────────────────────────────────────
    pw.Widget divider() => pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 6),
          height: 0.6,
          color: lineColor,
        );

    // ── Helper: section header ────────────────────────────────────────────
    pw.Widget sectionHeader(String title) => pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const pw.BoxDecoration(color: sectionBg),
          child: pw.Text(title.toUpperCase(), style: sectionHeadStyle),
        );

    // ── Helper: key-value row ─────────────────────────────────────────────
    pw.Widget kv(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 10),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 135,
                child: pw.Text(label, style: labelStyle),
              ),
              pw.Text(':  ', style: labelStyle),
              pw.Expanded(child: pw.Text(value, style: valueStyle)),
            ],
          ),
        );

    // ── Hotel table ───────────────────────────────────────────────────────
    pw.Widget hotelTable() {
      if (widget.hotels.isEmpty) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text('No hotels selected.', style: valueStyle),
        );
      }

      final headers = [
        'Hotel', 'Category', 'Room Type',
        'Guests', 'Rooms', 'Nights', 'Est. Cost',
      ];

      final rows = widget.hotels.map((h) => [
        h.hotelName        ?? 'N/A',
        h.roomCategoryName ?? 'N/A',
        h.roomTypeName     ?? 'N/A',
        '${h.guestCount}',
        '${h.roomCount}',
        '${h.noOfNights}',
        '${h.selectedCost ?? 'N/A'}',
      ]).toList();

      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: pw.Table(
          border: pw.TableBorder.all(color: lineColor, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2.2),
            1: pw.FlexColumnWidth(1.5),
            2: pw.FlexColumnWidth(1.5),
            3: pw.FlexColumnWidth(0.8),
            4: pw.FlexColumnWidth(0.8),
            5: pw.FlexColumnWidth(0.8),
            6: pw.FlexColumnWidth(1.4),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: sectionBg),
              children: headers
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(h, style: smallBold),
                      ))
                  .toList(),
            ),
            ...rows.map((row) => pw.TableRow(
                  children: row
                      .map((cell) => pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(cell, style: smallVal),
                          ))
                      .toList(),
                )),
          ],
        ),
      );
    }

    // ── Flight table ──────────────────────────────────────────────────────
    pw.Widget flightTable() {
      if (widget.flights.isEmpty) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text('No air tickets.', style: valueStyle),
        );
      }

      final headers = [
        'Leg', 'From Code', 'From City',
        'To Code', 'To City', 'Dep. Date', 'Arr. Date', 'Class', 'Guests',
      ];

      final List<List<String>> rows = [];
      for (final f in widget.flights) {
        final dep = f.airports?.departure;
        final ret = f.airports?.returnFlight;

        rows.add([
          'Departure',
          dep?.dFrom.airportCode.isNotEmpty == true ? dep!.dFrom.airportCode : 'N/A',
          dep?.dFrom.cityName.isNotEmpty    == true ? dep!.dFrom.cityName    : 'N/A',
          dep?.dTo.airportCode.isNotEmpty   == true ? dep!.dTo.airportCode   : 'N/A',
          dep?.dTo.cityName.isNotEmpty      == true ? dep!.dTo.cityName      : 'N/A',
          f.departureDate != null ? _fmtDate(f.departureDate!) : 'N/A',
          f.arrivalDate   != null ? _fmtDate(f.arrivalDate!)   : 'N/A',
          f.airTicketClassName.isNotEmpty   ? f.airTicketClassName            : 'N/A',
          '${f.guestCount}',
        ]);

        if (f.isRoundTrip && ret != null) {
          rows.add([
            'Return',
            ret.rFrom.airportCode.isNotEmpty ? ret.rFrom.airportCode : 'N/A',
            ret.rFrom.cityName.isNotEmpty    ? ret.rFrom.cityName    : 'N/A',
            ret.rTo.airportCode.isNotEmpty   ? ret.rTo.airportCode   : 'N/A',
            ret.rTo.cityName.isNotEmpty      ? ret.rTo.cityName      : 'N/A',
            f.departureDate != null ? _fmtDate(f.departureDate!) : 'N/A',
            f.arrivalDate   != null ? _fmtDate(f.arrivalDate!)   : 'N/A',
            f.airTicketClassName.isNotEmpty  ? f.airTicketClassName  : 'N/A',
            '${f.guestCount}',
          ]);
        }
      }

      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: pw.Table(
          border: pw.TableBorder.all(color: lineColor, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.2),
            1: pw.FlexColumnWidth(1.0),
            2: pw.FlexColumnWidth(1.4),
            3: pw.FlexColumnWidth(1.0),
            4: pw.FlexColumnWidth(1.4),
            5: pw.FlexColumnWidth(1.2),
            6: pw.FlexColumnWidth(1.2),
            7: pw.FlexColumnWidth(1.2),
            8: pw.FlexColumnWidth(0.7),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: sectionBg),
              children: headers
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(h, style: smallBold),
                      ))
                  .toList(),
            ),
            ...rows.map((row) => pw.TableRow(
                  children: row
                      .map((cell) => pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(cell, style: smallVal),
                          ))
                      .toList(),
                )),
          ],
        ),
      );
    }

    // ── Page ──────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [

          // Header bar
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const pw.BoxDecoration(color: headerBg),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('RESERVATION APPROVED', style: titleStyle),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Reservation No: ${widget.reservation.reservNo}',
                  style: subtitleStyle,
                ),
                 pw.Text(
                  'Manual No: ${widget.reservation.reservationnewnumber}',
                  style: subtitleStyle,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // 1. Member Details
          sectionHeader('Member Details'),
          pw.SizedBox(height: 4),
          kv('Member ID',   widget.reservation.mid),
          kv('Member Name', widget.reservation.mName),
          kv('Rating',      widget.reservation.gRating ?? 'N/A'),
          divider(),

          // 2. Hotel & Room Details
          sectionHeader('Hotel & Room Details'),
          pw.SizedBox(height: 4),
          hotelTable(),
          divider(),

          // 3. Stay Dates
          sectionHeader('Stay Dates'),
          pw.SizedBox(height: 4),
          kv('Arrival Date',   _fmtDate(widget.reservation.arrDate)),
          kv('Departure Date', _fmtDate(widget.reservation.depDate)),
          divider(),

          // 4. Air Ticket Details (conditional)
          if (widget.flights.isNotEmpty) ...[
            sectionHeader('Air Ticket Details'),
            pw.SizedBox(height: 4),
            flightTable(),
            pw.SizedBox(height: 6),
            ...widget.flights.asMap().entries.map((entry) {
              final i = entry.key + 1;
              final f = entry.value;
              return kv(
                'Ticket $i Est. Cost',
                '${f.selectedCost ?? 'N/A'}',
              );
            }),
            divider(),
          ],

          // 5. Remarks (conditional)
          if (widget.reservation.remarks.trim().isNotEmpty) ...[
            sectionHeader('Remarks'),
            pw.SizedBox(height: 4),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: pw.Text(widget.reservation.remarks, style: valueStyle),
            ),
            divider(),
          ],

          // 6. Manual Reservation No (conditional)
          // if ((widget.reservation.reservationnewnumber ?? '').trim().isNotEmpty) ...[
          //   sectionHeader('Manual Reservation No'),
          //   pw.SizedBox(height: 4),
          //   kv('Manual No', widget.reservation.reservationnewnumber!),
          //   divider(),
          // ],

          // 7. Approval Information
          sectionHeader('Approval Information'),
          pw.SizedBox(height: 4),
          kv('Approved By',      widget.reservation.isAppBy ?? 'N/A'),
          kv('Approved On',      _fmt(widget.reservation.isAppTime)),
          kv('Approval Remarks', widget.reservation.isAppRemarks.trim().isNotEmpty
              ? widget.reservation.isAppRemarks
              : 'N/A'),
          divider(),

          // Footer
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Generated on ${_fmt(DateTime.now())}',
              style: footerStyle,
            ),
          ),
        ],
      ),
    );

    return pdf;
  }

  // ── Share PDF via WhatsApp ────────────────────────────────────────────────
  Future<void> _sharePdfToWhatsApp(BuildContext context) async {
    try {
      final doc   = await _buildPdf();
      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Reservation_${widget.reservation.reservNo}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Widget build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _fontsReady
                ? const Icon(Icons.share, size: 20)
                : const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
            label: Text(
              _fontsReady ? 'SHARE PDF VIA WHATSAPP' : 'PREPARING...',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF25D366).withOpacity(0.6),
              disabledForegroundColor: Colors.white70,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
            // Disabled (null) until fonts finish loading
            onPressed: _fontsReady
                ? () => _sharePdfToWhatsApp(context)
                : null,
          ),
        ),

        // ── Uncomment to re-enable Download / Print PDF ─────────────────
        // const SizedBox(height: 10),
        // SizedBox(
        //   width: double.infinity,
        //   child: ElevatedButton.icon(
        //     icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
        //     label: const Text(
        //       'DOWNLOAD / PRINT PDF',
        //       style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        //     ),
        //     style: ElevatedButton.styleFrom(
        //       backgroundColor: const Color(0xFFB71C1C),
        //       foregroundColor: Colors.white,
        //       shape: RoundedRectangleBorder(
        //         borderRadius: BorderRadius.circular(12),
        //       ),
        //       padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        //     ),
        //     onPressed: _fontsReady
        //         ? () async {
        //             try {
        //               final doc = await _buildPdf();
        //               await Printing.layoutPdf(
        //                 onLayout: (_) async => doc.save(),
        //                 name: 'Reservation_${widget.reservation.reservNo}.pdf',
        //               );
        //             } catch (e) {
        //               if (context.mounted) {
        //                 ScaffoldMessenger.of(context).showSnackBar(
        //                   SnackBar(
        //                     content: Text('Failed to generate PDF: $e'),
        //                     backgroundColor: Colors.red,
        //                   ),
        //                 );
        //               }
        //             }
        //           }
        //         : null,
        //   ),
        // ),
      ],
    );
  }
}