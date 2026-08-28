// ============================================================
// FILE: lib/components/reservation_pdf_button_ballys.dart
//
// Ballys counterpart of reservation_pdf_button.dart — builds the same
// approved-reservation PDF summary and shares it via WhatsApp (or any other
// share target the OS offers), but reads off the ReservationBallys model.
//
// USAGE in ReservationViewScreenBallys build(), Approved tab:
//   if (selectedReservation?.requestStatus == 'Approved')
//     ReservationPdfButtonBallys(
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

import 'package:ballys_reservation_app/models/reervationBallys.dart';
import 'package:ballys_reservation_app/models/reservation/flight_bookng_ballys.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_desc_ballys.dart';

class ReservationPdfButtonBallys extends StatefulWidget {
  final ReservationBallys reservation;
  final List<HotelDescipBallys> hotels;
  final List<FlightBookingBallys> flights;

  const ReservationPdfButtonBallys({
    super.key,
    required this.reservation,
    required this.hotels,
    required this.flights,
  });

  @override
  State<ReservationPdfButtonBallys> createState() =>
      _ReservationPdfButtonBallysState();
}

class _ReservationPdfButtonBallysState
    extends State<ReservationPdfButtonBallys> {
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

  Future<void> _preloadFonts() async {
    try {
      final regular = await PdfGoogleFonts.nunitoRegular();
      final bold = await PdfGoogleFonts.nunitoBold();
      final light = await PdfGoogleFonts.nunitoLight();
      if (mounted) {
        setState(() {
          _ttf = regular;
          _ttfBold = bold;
          _ttfLight = light;
          _fontsReady = true;
        });
      }
    } catch (e) {
      debugPrint('Font preload failed: $e');
    }
  }

  // ── Date helpers ─────────────────────────────────────────────────────────
  String _fmt(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$day/$month/$year  ${h12.toString().padLeft(2, '0')}:$minute $period';
  }

  String _fmtDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  // ── Guest label helpers (mirrors ReservationViewScreenBallys) ─────────────
  String _packageLabel(String raw, {bool shared = false}) {
    final amount = raw.trim();
    final numeric = amount.isEmpty
        ? null
        : double.tryParse(amount.replaceAll(RegExp(r'[^0-9.]'), ''));
    // No package of their own — they travel on another guest's package.
    if (numeric == null || numeric == 0) return 'Shared';

    final currency = amount.replaceAll(RegExp(r'[0-9.,]'), '').trim();
    final formatted = NumberFormat('#,##0').format(numeric);
    final label = currency.isEmpty ? formatted : '$currency $formatted';
    return shared ? '$label (Shared)' : label;
  }

  /// A guest's own stay, shown only when it differs from the reservation's —
  /// the payload repeats the reservation dates on every guest, so printing
  /// them each time would say nothing.
  String? _stayLabel(
    DateTime? arrival,
    DateTime? departure,
    DateTime? reservationArrival,
    DateTime? reservationDeparture,
  ) {
    if (arrival == null && departure == null) return null;

    bool sameDay(DateTime? a, DateTime? b) =>
        a != null &&
        b != null &&
        a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;

    if (sameDay(arrival, reservationArrival) &&
        sameDay(departure, reservationDeparture)) {
      return null;
    }

    final from = arrival != null ? _fmtDate(arrival) : '-';
    final to = departure != null ? _fmtDate(departure) : '-';
    return '$from > $to';
  }

  // ── PDF builder ──────────────────────────────────────────────────────────
  Future<pw.Document> _buildPdf() async {
    final ttf = _ttf ?? await PdfGoogleFonts.nunitoRegular();
    final ttfBold = _ttfBold ?? await PdfGoogleFonts.nunitoBold();
    final ttfLight = _ttfLight ?? await PdfGoogleFonts.nunitoLight();

    final pdf = pw.Document();

    // ── Colour palette ────────────────────────────────────────────────────
    const headerBg = PdfColor.fromInt(0xFF1B5E20);
    const sectionBg = PdfColor.fromInt(0xFFE8F5E9);
    const accentCol = PdfColor.fromInt(0xFF2E7D32);
    const lineColor = PdfColor.fromInt(0xFFB2DFDB);
    const textDark = PdfColor.fromInt(0xFF212121);
    const textGrey = PdfColor.fromInt(0xFF616161);
    const cardBg = PdfColor.fromInt(0xFFE4E0E0);
    const cardBorder = PdfColor.fromInt(0xFFBDBDBD);
    const blueCol = PdfColor.fromInt(0xFF1565C0);
    const greenCol = PdfColor.fromInt(0xFF2E7D32);

    // ── Text styles ───────────────────────────────────────────────────────
    final titleStyle = pw.TextStyle(
      font: ttfBold,
      fontSize: 20,
      color: PdfColors.white,
    );
    final sectionHeadStyle = pw.TextStyle(
      font: ttfBold,
      fontSize: 11,
      color: accentCol,
    );
    final labelStyle = pw.TextStyle(font: ttfBold, fontSize: 10, color: textDark);
    final valueStyle = pw.TextStyle(font: ttf, fontSize: 10, color: textGrey);
    final footerStyle = pw.TextStyle(font: ttfLight, fontSize: 8, color: textGrey);
    final cardTitleStyle = pw.TextStyle(font: ttfBold, fontSize: 12, color: textDark);
    final cardLabelStyle = pw.TextStyle(font: ttfBold, fontSize: 10, color: textDark);
    final cardValueStyle = pw.TextStyle(font: ttf, fontSize: 10, color: textDark);
    final cardCostStyle = pw.TextStyle(font: ttfBold, fontSize: 11, color: textDark);
    final flightRouteStyle = pw.TextStyle(font: ttfBold, fontSize: 13, color: textDark);
    final flightLabelStyle = pw.TextStyle(font: ttfBold, fontSize: 10, color: textDark);
    final flightValueStyle = pw.TextStyle(font: ttf, fontSize: 10, color: textGrey);
    final guestLabelStyle = pw.TextStyle(font: ttfBold, fontSize: 10, color: textGrey);
    final guestCountStyle = pw.TextStyle(font: ttfBold, fontSize: 13, color: textDark);

    pw.Widget divider() => pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 6),
          height: 0.6,
          color: lineColor,
        );

    pw.Widget sectionHeader(String title) => pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const pw.BoxDecoration(color: sectionBg),
          child: pw.Text(title.toUpperCase(), style: sectionHeadStyle),
        );

    pw.Widget kv(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 10),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(width: 135, child: pw.Text(label, style: labelStyle)),
              pw.Text(':  ', style: labelStyle),
              pw.Expanded(child: pw.Text(value, style: valueStyle)),
            ],
          ),
        );

    pw.Widget cardRichRow(String label, String value) => pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(text: '$label: ', style: cardLabelStyle),
              pw.TextSpan(text: value, style: cardValueStyle),
            ],
          ),
        );

    // ── Hotel Cards ──────────────────────────────────────────────────────
    // Each card is returned as a separate MultiPage child. Wrapping them in one
    // pw.Column makes the whole group a single unsplittable block, so as soon as
    // it grows past the page it gets clipped and only the first card survives.
    List<pw.Widget> hotelCards() {
      if (widget.hotels.isEmpty) {
        return [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: pw.Text('No hotels selected.', style: valueStyle),
          ),
        ];
      }
      return widget.hotels.map((hotel) {
          // A room booked over its own dates — an amendment can move one room
          // without moving the reservation.
          final roomStay = _stayLabel(
            hotel.arrivalDate,
            hotel.departureDate,
            widget.reservation.arrDate,
            widget.reservation.depDate,
          );
          return pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: pw.BoxDecoration(
              color: cardBg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: cardBorder, width: 0.5),
            ),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(hotel.hotelName ?? 'N/A', style: cardTitleStyle),
                // The rooms are listed once for the whole reservation, so each
                // one names the guest(s) it was booked for.
                if (hotel.assignedGuests.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    hotel.assignedGuests.map((g) => g.label).join(', '),
                    style: cardLabelStyle.copyWith(color: textGrey),
                  ),
                ],
                pw.SizedBox(height: 5),
                cardRichRow('Category', hotel.roomCategoryName ?? 'N/A'),
                pw.SizedBox(height: 4),
                cardRichRow('Room Type', hotel.roomTypeName ?? 'N/A'),
                pw.SizedBox(height: 5),
                pw.Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    pw.Text('Guests: ${hotel.guestCount}', style: cardValueStyle),
                    if ((hotel.childrenCount ?? 0) > 0)
                      pw.Text(
                        'Children: ${hotel.childrenCount}',
                        style: cardValueStyle,
                      ),
                    pw.Text('Nights: ${hotel.noOfNights}', style: cardValueStyle),
                    pw.Text('Rooms: ${hotel.roomCount}', style: cardValueStyle),
                  ],
                ),
                if (roomStay != null) ...[
                  pw.SizedBox(height: 5),
                  cardRichRow('Stay', roomStay),
                ],
                pw.SizedBox(height: 6),
                pw.Text(
                  'Estimated Cost: ${hotel.selectedCost ?? 'N/A'}',
                  style: cardCostStyle,
                ),
              ],
            ),
          );
      }).toList();
    }

    // ── Flight Cards ─────────────────────────────────────────────────────
    List<pw.Widget> flightCards() {
      if (widget.flights.isEmpty) {
        return [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: pw.Text('No air tickets.', style: valueStyle),
          ),
        ];
      }
      return widget.flights.map((flight) {
          final dep = flight.airports?.departure;
          final ret = flight.airports?.returnFlight;

          final depFrom = dep?.dFrom.airportCode.isNotEmpty == true
              ? dep!.dFrom.airportCode
              : 'N/A';
          final depTo = dep?.dTo.airportCode.isNotEmpty == true
              ? dep!.dTo.airportCode
              : 'N/A';

          final retFrom = ret?.rFrom.airportCode.isNotEmpty == true
              ? ret!.rFrom.airportCode
              : null;
          final retTo = ret?.rTo.airportCode.isNotEmpty == true
              ? ret!.rTo.airportCode
              : null;
          final hasReturn = flight.isRoundTrip && ret != null;

          final depDate =
              flight.departureDate != null ? _fmtDate(flight.departureDate!) : 'N/A';
          final arrDate =
              flight.arrivalDate != null ? _fmtDate(flight.arrivalDate!) : 'N/A';

          return pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: pw.BoxDecoration(
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
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Container(
                            width: 8,
                            height: 8,
                            decoration: const pw.BoxDecoration(
                              color: blueCol,
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Text(
                            '$depFrom  >  $depTo',
                            style: flightRouteStyle.copyWith(color: blueCol),
                          ),
                        ],
                      ),
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
                      // Tickets are listed once for the whole reservation, so
                      // each one names the guest(s) it was booked for.
                      if (flight.assignedGuests.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        pw.Text(
                          flight.assignedGuests.map((g) => g.label).join(', '),
                          style: flightLabelStyle.copyWith(color: textGrey),
                        ),
                      ],
                      pw.SizedBox(height: 6),
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(text: 'Class: ', style: flightLabelStyle),
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
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(text: 'Arrival Date: ', style: flightLabelStyle),
                            pw.TextSpan(text: arrDate, style: flightValueStyle),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: 'Departure Date: ',
                              style: flightLabelStyle,
                            ),
                            pw.TextSpan(text: depDate, style: flightValueStyle),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 4),
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
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
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
                    pw.Text('${flight.guestCount}', style: guestCountStyle),
                  ],
                ),
              ],
            ),
          );
      }).toList();
    }

    // ── Guest Cards ──────────────────────────────────────────────────────
    // Members travelling on another guest's package are folded into that
    // guest's `accompanyingMembers` when the payload is parsed, so walking
    // `guests` alone prints only the package owner. Flatten owner + members
    // into one card each, exactly the way the Approved tab lists them.
    List<pw.Widget> guestCards() {
      final cards = <_PdfGuestCard>[];

      for (final guest in widget.reservation.guests) {
        // Members travel on the owner's dates, so both carry the same stay.
        final stay = _stayLabel(
          guest.arrivalDate,
          guest.departureDate,
          widget.reservation.arrDate,
          widget.reservation.depDate,
        );
        final owner = guest.guestName.trim().isNotEmpty
            ? guest.guestName.trim()
            : guest.mid;

        cards.add(_PdfGuestCard(
          mid: guest.mid,
          name: guest.guestName,
          package: _packageLabel(
            guest.packageAmount,
            shared: guest.sharedPackage,
          ),
          hasFamilyMembers: guest.hasFamilyMembers,
          stay: stay,
          sharesWith: null,
          airTicket: guest.airTicketRequisition,
          remarks: guest.remarks,
        ));

        for (final member in guest.accompanyingMembers) {
          cards.add(_PdfGuestCard(
            mid: member.mid,
            name: member.guestName,
            package: _packageLabel(
              member.packageAmount,
              shared: member.sharedPackage,
            ),
            hasFamilyMembers: member.hasFamilyMembers,
            stay: stay,
            sharesWith: owner,
            // Rooms, tickets and dates sit on the owner, so a member carries
            // no air-ticket flag or remarks of their own.
            airTicket: null,
            remarks: '',
          ));
        }
      }

      if (cards.isEmpty) {
        return [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: pw.Text('No guests.', style: valueStyle),
          ),
        ];
      }

      return cards.asMap().entries.map((entry) {
        final index = entry.key;
        final card = entry.value;

        return pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
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
                '${index + 1}. '
                '${card.name.trim().isNotEmpty ? card.name.trim() : 'Unnamed guest'}',
                style: cardTitleStyle,
              ),
              if (card.mid.trim().isNotEmpty) ...[
                pw.SizedBox(height: 5),
                cardRichRow('Member ID', card.mid),
              ],
              // The rooms, tickets and dates sit on the guest whose package
              // this member is on, so the card says whose that is.
              // if (card.sharesWith != null) ...[
              //   pw.SizedBox(height: 4),
              //   pw.Text(
              //     'Shared package with ${card.sharesWith}',
              //     style: cardLabelStyle.copyWith(color: textGrey),
              //   ),
              // ],
              pw.SizedBox(height: 4),
              cardRichRow('Package', card.package),
              pw.SizedBox(height: 4),
              cardRichRow(
                'Family members',
                card.hasFamilyMembers ? 'Included' : 'Not included',
              ),
              // A guest travelling on their own dates rather than the
              // reservation's.
              if (card.stay != null) ...[
                pw.SizedBox(height: 4),
                cardRichRow('Stay', card.stay!),
              ],
              if (card.airTicket != null) ...[
                pw.SizedBox(height: 4),
                cardRichRow('Air Ticket', card.airTicket!),
              ],
              if (card.remarks.trim().isNotEmpty) ...[
                pw.SizedBox(height: 4),
                cardRichRow('Remarks', card.remarks.trim()),
              ],
            ],
          ),
        );
      }).toList();
    }

    // Every person on the reservation: each guest plus the members travelling
    // on that guest's package.
    final guestCount = widget.reservation.guests.fold<int>(
      0,
      (sum, guest) => sum + 1 + guest.accompanyingMembers.length,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
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
                  style: const pw.TextStyle(fontSize: 16, color: PdfColors.white),
                ),
                pw.Text(
                  'Manual No: ${widget.reservation.reservationnewnumber ?? 'N/A'}',
                  style: const pw.TextStyle(fontSize: 16, color: PdfColors.white),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          sectionHeader('Member Details'),
          pw.SizedBox(height: 4),
          kv('Member ID', widget.reservation.mid),
          kv('Member Name', widget.reservation.mName),
          // kv('Rating', widget.reservation.gRating ?? 'N/A'),
          kv(
            'Requested By',
            widget.reservation.reqBy.trim().isNotEmpty ? widget.reservation.reqBy : 'N/A',
          ),
          kv('Reservation Date', _fmtDate(widget.reservation.reservDate)),
          // kv(
          //   'Package Amount',
          //   widget.reservation.packageAmountDisplay.trim().isNotEmpty
          //       ? widget.reservation.packageAmountDisplay
          //       : 'N/A',
          // ),
          kv(
            'Air Ticket',
            widget.reservation.airticketReservationStatus.trim().isNotEmpty
                ? widget.reservation.airticketReservationStatus
                : 'N/A',
          ),
          kv(
            'Remarks',
            widget.reservation.remarks.trim().isNotEmpty
                ? widget.reservation.remarks
                : 'N/A',
          ),
          divider(),

          if (widget.reservation.guests.isNotEmpty) ...[
            sectionHeader(
              guestCount > 1 ? 'Guest Details ($guestCount)' : 'Guest Details',
            ),
            pw.SizedBox(height: 2),
            ...guestCards(),
            divider(),
          ],

          sectionHeader('Hotel & Room Details'),
          pw.SizedBox(height: 2),
          ...hotelCards(),
          divider(),

          sectionHeader('Stay Dates'),
          pw.SizedBox(height: 2),
          kv('Arrival Date', _fmtDate(widget.reservation.arrDate)),
          kv('Departure Date', _fmtDate(widget.reservation.depDate)),
          divider(),

          if (widget.flights.isNotEmpty) ...[
            sectionHeader('Air Ticket Details'),
            pw.SizedBox(height: 2),
            ...flightCards(),
            divider(),
          ],

          sectionHeader('Approval Information'),
          pw.SizedBox(height: 4),
          kv('Approved By', widget.reservation.approvedBy ?? widget.reservation.isAppBy ?? 'N/A'),
          kv(
            'Approved On',
            widget.reservation.approvedTime != null
                ? _fmt(widget.reservation.approvedTime!)
                : _fmt(widget.reservation.isAppTime),
          ),
          kv(
            'Approval Remarks',
            (widget.reservation.approvedRemark ?? widget.reservation.isAppRemarks)
                    .trim()
                    .isNotEmpty
                ? (widget.reservation.approvedRemark ?? widget.reservation.isAppRemarks)
                : 'N/A',
          ),
          divider(),

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
      final doc = await _buildPdf();
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
          _fontsReady ? 'SEND RESERVATION DETAILS VIA WHATSAPP' : 'PREPARING...',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF25D366),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF25D366).withOpacity(0.6),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
        onPressed: _fontsReady ? () => _sharePdfToWhatsApp(context) : null,
      ),
    );
  }
}

/// One printed guest row: either a guest standing on their own or a member
/// travelling on that guest's package. Flattened out of
/// `ReservationBallys.guests` so every person on the reservation gets a card.
class _PdfGuestCard {
  final String mid;
  final String name;
  final String package;
  final bool hasFamilyMembers;

  /// The guest's own stay, or null when it matches the reservation's.
  final String? stay;

  /// Name of the guest whose package this member is on; null for a guest
  /// standing on their own.
  final String? sharesWith;

  /// "Yes" / "No" for a guest; null for a member, whose tickets sit on the
  /// package owner.
  final String? airTicket;

  final String remarks;

  const _PdfGuestCard({
    required this.mid,
    required this.name,
    required this.package,
    required this.hasFamilyMembers,
    required this.stay,
    required this.sharesWith,
    required this.airTicket,
    required this.remarks,
  });
}
