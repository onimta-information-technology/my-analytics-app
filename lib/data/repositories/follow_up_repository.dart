import 'dart:convert';
import 'dart:io';

import 'package:ballys_reservation_app/data/services/api_service.dart';
// import 'package:ballys_reservation_app/models/reservation.dart';
import 'package:ballys_reservation_app/models/follow_up_item.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

/// Repository for the follow-up (CRM) endpoint.
///
/// Posts a JSON payload to `savefollowUp`, which resolves against the current
/// CRM base URL — i.e. `https://api.ballyscolombo.com/api/Ballys/CRM/savefollowUp`.
class FollowUpRepository {
  final ApiService apiService;

  FollowUpRepository(this.apiService);

  /// Saves a follow-up record.
  ///
  /// [photo] is optional and, when present, is sent as a base64 string so the
  /// payload stays pure JSON.
  Future<Map<String, dynamic>> saveFollowUp({
    required String memberId,
    required String memberName,
    required String description,
    required String contactStatus,
    String? responseType,
    String? customerResponse,
    String? remarks,
    List<String> checklistItems = const <String>[],
    String? positiveStatus,
    DateTime? plannedVisitDate,
    DateTime? followUpDate,
    File? photo,
  }) async {
    final deviceId = await DeviceId.get();
    final userName = await StorageUtil.getUserName();
    final salesCode = await StorageUtil.getSalesCode();
    final marketingCode = await StorageUtil.getMarketingCode();

    String? photoBase64;
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      photoBase64 = base64Encode(bytes);
    }

    final body = <String, Object?>{
      'MId': memberId,
      'MName': memberName,
      'Description': description,
      'ContactStatus': contactStatus,
      'ResponseType': responseType,
      'CustomerResponse': customerResponse,
      'Remarks': remarks,
      'ChecklistItems': checklistItems,
      'PositiveStatus': positiveStatus,
      'Photo': photoBase64,
      'DeviceId': deviceId,
      'Login_By': userName,
      'Sales_Code': salesCode,
      'Marketing_Code': marketingCode,
      'CreatedDate': DateTime.now().toIso8601String(),
    };
    // Log a readable copy: the full base64 photo would swamp the terminal, so
    // replace it with a short summary. The real request still sends everything.
    final logBody = Map<String, Object?>.from(body);
    if (photoBase64 != null) {
      logBody['Photo'] = '<base64 image, ${photoBase64.length} chars>';
    }
    print('Follow-up request body: ${jsonEncode(logBody)}');

    return apiService.post('followup_Insert', body);
  }

  /// Fetches every saved follow-up from `GetAllFollowup`.
  ///
  /// The endpoint answers `{ "Status": true, "Data": [ ... ] }`; a false or
  /// missing `Status` is treated as an empty list rather than an error, since
  /// the API has no error payload of its own.
  Future<List<FollowUpItem>> fetchAllFollowUps() async {
    final response = await apiService.get('GetAllFollowup');

    if (response['Status'] != true) return const <FollowUpItem>[];

    final data = response['Data'] as List<dynamic>? ?? const [];
    return data
        .map((e) => FollowUpItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns an ISO `yyyy-MM-dd` date string, or null when [date] is null.
  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}