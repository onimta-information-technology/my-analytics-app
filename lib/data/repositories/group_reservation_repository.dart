import 'dart:convert';
import 'dart:io';

import 'package:ballys_reservation_app/components/passport_upload_widget_ballys.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/reservation/group_guest_sheet.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

/// What came back from a group reservation save, in the two parts the screen
/// reacts to: whether to clear the form, and what to put in the snack.
class GroupReservationResult {
  final bool success;
  final String? message;

  const GroupReservationResult({required this.success, this.message});
}

/// The API side of the Ballys group reservation screen.
///
/// A group reservation is one lead guest plus an Excel sheet naming everybody
/// else travelling with them, and the passport pages for the party. The screen
/// hands over the form's contents and gets back a [GroupReservationResult].
class GroupReservationRepository {
  final ApiService apiService;

  GroupReservationRepository(this.apiService);

  /// Follows the `Reservation_*` naming the other reservation endpoints use.
  /// Confirm the exact name with the backend before shipping — the payload
  /// shape below mirrors `Reservation_InsertReservation`, so only this constant
  /// should need changing.
  static const String _endpoint = 'Reservation_InsertGroupReservation';

  Future<GroupReservationResult> saveGroupReservation({
    required String bmNumber,
    required String guestName,
    required GroupGuestSheet? guestSheet,
    required List<PassportFileBallys> passportFiles,
    String remarks = '',
    void Function(String label, Object? payload)? log,
  }) async {
    final body = await buildBody(
      bmNumber: bmNumber,
      guestName: guestName,
      guestSheet: guestSheet,
      passportFiles: passportFiles,
      remarks: remarks,
    );
    log?.call('Saving group reservation', _redacted(body));

    final response = await apiService.post(_endpoint, body);
    log?.call('Group reservation response', response);

    final success = response['Status'] as bool? ?? false;
    return GroupReservationResult(
      success: success,
      message: response['Message'] as String? ??
          (success ? null : 'Failed to save group reservation'),
    );
  }

  /// Built separately from the post so it can be inspected in tests without a
  /// live API.
  Future<Map<String, Object?>> buildBody({
    required String bmNumber,
    required String guestName,
    required GroupGuestSheet? guestSheet,
    required List<PassportFileBallys> passportFiles,
    String remarks = '',
  }) async {
    final sheetBase64 = await guestSheet?.toBase64();

    return {
      'master_id': DateTime.now().millisecondsSinceEpoch.toString(),
      'bm_number': bmNumber,
      'guest_name': guestName,
      'remarks': remarks,
      'sales_code': await StorageUtil.getSalesCode(),
      'user_name': await StorageUtil.getUserName(),
      'device_id': await DeviceId.get(),
      // The sheet the backend expands into individual guests. Null when the
      // form was submitted without one.
      'guest_sheet': sheetBase64 == null
          ? null
          : {
              'FileName': guestSheet!.fileName,
              'Base64Data': sheetBase64,
            },
      // Same per-file shape Reservation_InsertReservation takes, so the backend
      // can store group passports through the existing path. Files picked
      // before a BM number was entered are filed under the lead guest.
      'passport_images': await _encodePassports(passportFiles, bmNumber),
    };
  }

  Future<List<Map<String, Object?>>> _encodePassports(
    List<PassportFileBallys> files,
    String fallbackBmNumber,
  ) async {
    final encoded = <Map<String, Object?>>[];
    for (final file in files) {
      try {
        final bytes = await File(file.path).readAsBytes();
        encoded.add({
          'GuestBMNumber': file.guestBmNumber.isEmpty
              ? fallbackBmNumber
              : file.guestBmNumber,
          'FileName': file.fileName,
          'IsPdf': file.isPdf,
          'Base64Data': base64Encode(bytes),
        });
      } catch (_) {
        // A file that vanished between picking and saving is skipped rather
        // than failing the whole submission.
      }
    }
    return encoded;
  }

  /// The body with base64 payloads swapped for their length, so logging a save
  /// does not dump megabytes of image data into the console.
  Map<String, Object?> _redacted(Map<String, Object?> body) {
    final copy = Map<String, Object?>.from(body);

    final sheet = copy['guest_sheet'];
    if (sheet is Map) {
      final data = sheet['Base64Data'];
      copy['guest_sheet'] = {
        ...sheet,
        if (data is String) 'Base64Data': '<base64: ${data.length} chars>',
      };
    }

    final passports = copy['passport_images'];
    if (passports is List) {
      copy['passport_images'] = passports.map((p) {
        if (p is! Map) return p;
        final data = p['Base64Data'];
        return {
          ...p,
          if (data is String) 'Base64Data': '<base64: ${data.length} chars>',
        };
      }).toList();
    }

    return copy;
  }
}
