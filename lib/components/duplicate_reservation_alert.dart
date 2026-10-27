import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ballys_reservation_app/models/reservation/reservation_duplicate_check.dart';

/// Lists the pending reservations a new one clashes with, guest by guest —
/// what `Reservation_CheckDuplicate` found, as the new reservation and quick
/// reservation screens both show it.
Future<void> showDuplicateReservationAlert(
  BuildContext context, {
  required String title,
  required String message,
  List<DuplicateMatch> hotels = const [],
  List<DuplicateMatch> tickets = const [],
}) {
  final dateFormat = DateFormat('dd/MM/yyyy');
  String dates(DuplicateMatch m, String from, String to) => [
        m.date(from),
        m.date(to),
      ].whereType<DateTime>().map(dateFormat.format).join(' – ');
  String route(DuplicateMatch m) => [
        '${m.field('matched_df_airport_code')} → '
            '${m.field('matched_dt_airport_code')}',
        if (m.field('matched_rf_airport_code').isNotEmpty)
          '${m.field('matched_rf_airport_code')} → '
              '${m.field('matched_rt_airport_code')}',
      ].join(', ');
  String reservation(DuplicateMatch m) =>
      '${m.field('reservation_status').isEmpty ? 'Reservation' : '${m.field('reservation_status')} reservation'} ${m.field('master_id')}'
      '${m.field('main_guest_name').isEmpty ? '' : ' — ${m.field('main_guest_name')}'}';

  Widget line(IconData icon, String bm, String text, String detail) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$bm — $text',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(detail,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      );

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            for (final m in hotels)
              line(
                Icons.hotel,
                m.bmNumber,
                '${m.field('matched_hotel_name')}, '
                    '${dates(m, 'matched_arrival_date', 'matched_departure_date')}',
                reservation(m),
              ),
            for (final m in tickets)
              line(
                Icons.flight,
                m.bmNumber,
                '${route(m)}, '
                    '${dates(m, 'matched_arrival_date', 'matched_departure_date')}',
                reservation(m),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
