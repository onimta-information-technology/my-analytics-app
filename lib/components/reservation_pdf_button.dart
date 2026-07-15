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
    const headerBg   = PdfColor.fromInt(0xFF1B5E20); // deep green
    const sectionBg  = PdfColor.fromInt(0xFFE8F5E9); // light green tint
    const accentCol  = PdfColor.fromInt(0xFF2E7D32); // medium green
    const lineColor  = PdfColor.fromInt(0xFFB2DFDB);
    const textDark   = PdfColor.fromInt(0xFF212121);
    const textGrey   = PdfColor.fromInt(0xFF616161);
    // Card colours — matches Flutter view screen
    const cardBg     = PdfColor.fromInt(0xFFE4E0E0); // same grey as Card color in view
    const cardBorder = PdfColor.fromInt(0xFFBDBDBD);
    // Flight accent colours
    const blueCol    = PdfColor.fromInt(0xFF1565C0); // departure blue
    const greenCol   = PdfColor.fromInt(0xFF2E7D32); // return green

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
    final footerStyle = pw.TextStyle(
      font: ttfLight, fontSize: 8, color: textGrey,
    );
    // Card-specific styles
    final cardTitleStyle = pw.TextStyle(
      font: ttfBold, fontSize: 12, color: textDark,
    );
    final cardLabelStyle = pw.TextStyle(
      font: ttfBold, fontSize: 10, color: textDark,
    );
    final cardValueStyle = pw.TextStyle(
      font: ttf, fontSize: 10, color: textDark,
    );
    final cardCostStyle = pw.TextStyle(
      font: ttfBold, fontSize: 11, color: textDark,
    );
    final flightRouteStyle = pw.TextStyle(
      font: ttfBold, fontSize: 13, color: textDark,
    );
    final flightLabelStyle = pw.TextStyle(
      font: ttfBold, fontSize: 10, color: textDark,
    );
    final flightValueStyle = pw.TextStyle(
      font: ttf, fontSize: 10, color: textGrey,
    );
    final guestLabelStyle = pw.TextStyle(
      font: ttfBold, fontSize: 10, color: textGrey,
    );
    final guestCountStyle = pw.TextStyle(
      font: ttfBold, fontSize: 13, color: textDark,
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

    // ── Helper: card-style rich text row (label: value) ───────────────────
    pw.Widget cardRichRow(String label, String value) => pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(text: '$label: ', style: cardLabelStyle),
              pw.TextSpan(text: value, style: cardValueStyle),
            ],
          ),
        );

    // ══════════════════════════════════════════════════════════════════════
    // ── Hotel Cards — matches view screen Card layout exactly ─────────────
    // ══════════════════════════════════════════════════════════════════════
    pw.Widget hotelCards() {
      if (widget.hotels.isEmpty) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: pw.Text('No hotels selected.', style: valueStyle),
        );
      }

      return pw.Column(
        children: widget.hotels.map((hotel) {
          return pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            decoration: pw.BoxDecoration(
              color: cardBg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: cardBorder, width: 0.5),
            ),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Hotel name — matches view screen title text
                pw.Text(
                  hotel.hotelName ?? 'N/A',
                  style: cardTitleStyle,
                ),
                pw.SizedBox(height: 5),

                // Category
                cardRichRow('Category', hotel.roomCategoryName ?? 'N/A'),
                pw.SizedBox(height: 4),

                // Room Type
                cardRichRow('Room Type', hotel.roomTypeName ?? 'N/A'),
                pw.SizedBox(height: 5),

                // Guests | Nights | Rooms — inline row like view screen
                pw.Row(
                  children: [
                    pw.Text(
                      'Guests: ${hotel.guestCount}',
                      style: cardValueStyle,
                    ),
                    pw.SizedBox(width: 16),
                    pw.Text(
                      'Nights: ${hotel.noOfNights}',
                      style: cardValueStyle,
                    ),
                    pw.SizedBox(width: 16),
                    pw.Text(
                      'Rooms: ${hotel.roomCount}',
                      style: cardValueStyle,
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),

                // Estimated Cost — slightly larger, like view screen
                pw.Text(
                  'Estimated Cost: ${hotel.selectedCost ?? 'N/A'}',
                  style: cardCostStyle,
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    // ══════════════════════════════════════════════════════════════════════
    // ── Flight Cards — matches FlightCard widget layout exactly ───────────
    // ══════════════════════════════════════════════════════════════════════
    pw.Widget flightCards() {
      if (widget.flights.isEmpty) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: pw.Text('No air tickets.', style: valueStyle),
        );
      }

      return pw.Column(
        children: widget.flights.asMap().entries.map((entry) {
          final flight = entry.value;
          final dep = flight.airports?.departure;
          final ret = flight.airports?.returnFlight;

          // Build departure route string: "CMB → DXB"
          final depFrom = dep?.dFrom.airportCode.isNotEmpty == true
              ? dep!.dFrom.airportCode
              : 'N/A';
          final depTo = dep?.dTo.airportCode.isNotEmpty == true
              ? dep!.dTo.airportCode
              : 'N/A';

          // Build return route string if round trip
          final retFrom = ret?.rFrom.airportCode.isNotEmpty == true
              ? ret!.rFrom.airportCode
              : null;
          final retTo = ret?.rTo.airportCode.isNotEmpty == true
              ? ret!.rTo.airportCode
              : null;
          final hasReturn = flight.isRoundTrip && ret != null;

          final depDate = flight.departureDate != null
              ? _fmtDate(flight.departureDate!)
              : 'N/A';
          final arrDate = flight.arrivalDate != null
              ? _fmtDate(flight.arrivalDate!)
              : 'N/A';

          return pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            decoration: pw.BoxDecoration(
              // color: PdfColors.white,
               color: cardBg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: cardBorder, width: 0.5),
              boxShadow: [
                const pw.BoxShadow(
                  color: PdfColor.fromInt(0x1A000000),
                  blurRadius: 2,
                  offset: PdfPoint(0, 1),
                ),
              ],
            ),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // ── Left column: routes + class + dates + cost ────────────
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Departure route with coloured bullet
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          // Blue circle bullet (mimics flight_takeoff icon colour)
                          pw.Container(
                            width: 8,
                            height: 8,
                            decoration: const pw.BoxDecoration(
                              color: blueCol,
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                          pw.SizedBox(width: 6),
                          // Use plain ASCII '>' — Nunito does not include U+2192
                          pw.Text(
                            '$depFrom  >  $depTo',
                            style: flightRouteStyle.copyWith(color: blueCol),
                          ),
                        ],
                      ),

                      // Return route (only if round trip)
                      if (hasReturn) ...[
                        pw.SizedBox(height: 4),
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Container(
                              width: 8,
                              height: 8,
                              decoration: const pw.BoxDecoration(
                                color: greenCol,
                                shape: pw.BoxShape.circle,
                              ),
                            ),
                            pw.SizedBox(width: 6),
                            pw.Text(
                              '${retFrom ?? 'N/A'}  >  ${retTo ?? 'N/A'}',
                              style: flightRouteStyle.copyWith(
                                color: greenCol,
                                fontWeight: pw.FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],

                      pw.SizedBox(height: 6),

                      // Class
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: 'Class: ',
                              style: flightLabelStyle,
                            ),
                            pw.TextSpan(
                              text: flight.airTicketClassName.isNotEmpty
                                  ? flight.airTicketClassName
                                  : 'N/A',
                              style: flightLabelStyle,
                            ),
                          ],
                        ),
                      ),

                      pw.SizedBox(height: 6),

                      // Arrival Date — matches FlightCard label
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: 'Arrival Date: ',
                              style: flightLabelStyle,
                            ),
                            pw.TextSpan(
                              text: arrDate,
                              style: flightValueStyle,
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 4),

                      // Departure Date
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: 'Departure Date: ',
                              style: flightLabelStyle,
                            ),
                            pw.TextSpan(
                              text: depDate,
                              style: flightValueStyle,
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 4),

                      // Estimated Cost
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: 'Estimated Cost: ',
                              style: flightLabelStyle,
                            ),
                            pw.TextSpan(
                              text: '${flight.selectedCost ?? 'N/A'}',
                              style: flightValueStyle,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Right column: guest icon + label + count ──────────
                // Matches FlightCard's right-side Column layout
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Clean grey circle — no emoji, just a solid dot
                    pw.Container(
                      width: 28,
                      height: 28,
                      decoration: const pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFF9E9E9E),
                        shape: pw.BoxShape.circle,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'G',
                          style: pw.TextStyle(
                            font: ttfBold,
                            fontSize: 13,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Guests', style: guestLabelStyle),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${flight.guestCount}',
                      style: guestCountStyle,
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    // ══════════════════════════════════════════════════════════════════════
    // ── Guest Cards — one card per guest on the reservation ───────────────
    // ══════════════════════════════════════════════════════════════════════
    pw.Widget guestCards() {
      if (widget.reservation.guests.isEmpty) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: pw.Text('No guests.', style: valueStyle),
        );
      }

      return pw.Column(
        children: widget.reservation.guests.map((guest) {
          final arr = guest.arrivalDate != null
              ? _fmtDate(guest.arrivalDate!)
              : 'N/A';
          final dep = guest.departureDate != null
              ? _fmtDate(guest.departureDate!)
              : 'N/A';
          return pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            decoration: pw.BoxDecoration(
              color: cardBg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: cardBorder, width: 0.5),
            ),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  guest.guestName.isNotEmpty ? guest.guestName : 'N/A',
                  style: cardTitleStyle,
                ),
                pw.SizedBox(height: 5),
                cardRichRow('Member ID', guest.mid.isNotEmpty ? guest.mid : 'N/A'),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.Text('Arrival: $arr', style: cardValueStyle),
                    pw.SizedBox(width: 16),
                    pw.Text('Departure: $dep', style: cardValueStyle),
                  ],
                ),
                pw.SizedBox(height: 4),
                cardRichRow('Air Ticket', guest.airTicketRequisition),
                if (guest.remarks.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  cardRichRow('Remarks', guest.remarks),
                ],
              ],
            ),
          );
        }).toList(),
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
                  style: pw.TextStyle(fontSize: 16),
                ),
                pw.Text(
                  'Manual No: ${widget.reservation.reservationnewnumber}',
                  style: pw.TextStyle(fontSize: 16),
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
          kv('Requested By', widget.reservation.reqBy.trim().isNotEmpty
              ? widget.reservation.reqBy
              : 'N/A'),
          kv('Reservation Date', _fmtDate(widget.reservation.reservDate)),
          kv('Package Amount', widget.reservation.packageAmountDisplay.trim().isNotEmpty
              ? widget.reservation.packageAmountDisplay
              : 'N/A'),
          kv('Air Ticket', widget.reservation.airticketReservationStatus.trim().isNotEmpty
              ? widget.reservation.airticketReservationStatus
              : 'N/A'),
          kv('Remarks',      widget.reservation.remarks.trim().isNotEmpty
              ? widget.reservation.remarks
              : 'N/A'),
          divider(),

          // 2. Guest Details — one card per guest attached to the reservation
          if (widget.reservation.guests.isNotEmpty) ...[
            sectionHeader('Guest Details'),
            pw.SizedBox(height: 2),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6),
              child: guestCards(),
            ),
            divider(),
          ],

          // 3. Hotel & Room Details — card layout matching view screen
          sectionHeader('Hotel & Room Details'),
          pw.SizedBox(height: 2),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6),
            child: hotelCards(),
          ),
          divider(),

          // 3. Stay Dates
          sectionHeader('Stay Dates'),
          pw.SizedBox(height: 2),
          kv('Arrival Date',   _fmtDate(widget.reservation.arrDate)),
          kv('Departure Date', _fmtDate(widget.reservation.depDate)),
          divider(),

          // 4. Air Ticket Details — card layout matching FlightCard widget
          if (widget.flights.isNotEmpty) ...[
            sectionHeader('Air Ticket Details'),
            pw.SizedBox(height: 2),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6),
              child: flightCards(),
            ),
            divider(),
          ],

          // 5. Remarks (conditional)
          // if (widget.reservation.remarks.trim().isNotEmpty) ...[
          //   sectionHeader('Remarks'),
          //   pw.SizedBox(height: 4),
          //   pw.Padding(
          //     padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          //     child: pw.Text(widget.reservation.remarks, style: valueStyle),
          //   ),
          //   divider(),
          // ],

          // 6. Approval Information
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