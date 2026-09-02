import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/air_ticket.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class AirTicketRepository {
  final ApiService apiService;

  AirTicketRepository(this.apiService);

  /// Fetches recent air ticket reservations (iid: 7576)
  Future<List<AirTicket>> getRecentAirTickets() async {
    return _fetchAirTickets(iid: 7576);
  }

  /// Fetches past air ticket reservations (iid: 7577)
  Future<List<AirTicket>> getPastAirTickets() async {
    return _fetchAirTickets(iid: 7577);
  }

  Future<List<AirTicket>> _fetchAirTickets({required int iid}) async {
    final salesCode = await StorageUtil.getSalesCode();
    final deviceId = await DeviceId.get();
  final spName = await StorageUtil.getStoredProcedureName();

  print('SP me packages $spName');
    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": iid,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int",
        },
        {
          "Para_Data": salesCode,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text1",
          "Para_Type": "varchar",
        },
        {
          "Para_Data": deviceId,
          "Para_Direction": "Input",
          "Para_Lenth": 100,
          "Para_Name": "@Text30",
          "Para_Type": "varchar",
        },
      ],
      "SpName": spName,
      "con": "1",
    });
    print('packages data $response');
     print('packages body $iid , $salesCode');

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        (response['CommonResult']['Table'] as List).isNotEmpty) {
      final tableData = response['CommonResult']['Table'] as List;
      print("tableData,$tableData");
      return tableData
          .map((item) => AirTicket.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    return [];
  }

  /// POST `{baseUrl}/Air_Ticket_Amendment_Insert` — submits an air ticket
  /// amendment built by [AirTicketAmendmentBallysScreen].
  Future<AirTicketAmendmentResult> submitAmendment(
    Map<String, Object?> payload,
  ) async {
    final userName = await StorageUtil.getUserName();
    final deviceId = await DeviceId.get();

    final body = <String, Object?>{
      ...payload,
      'user_name': userName,
      'device_id': deviceId,
      'status': 'Pending',
    };

    //print('submitAmendment payload: $body');
    final response = await apiService.post(
      'AmendmentAir/Insert',
      body,
    );
print('submitAmendment response: $response');
    return AirTicketAmendmentResult(
      success: _insertSucceeded(response),
      message: _insertMessage(response),
      masterRowId: (response['MasterRowId'] as num?)?.toInt(),
    );
  }

  /// The insert endpoint answers `{success: true, MasterRowId: n}`; older
  /// builds of it answered `Status`. Accept either, so one shape changing
  /// does not read as a failed submit. A row id coming back is itself proof
  /// the amendment was written.
  static bool _insertSucceeded(Map<String, dynamic> response) {
    if (response['success'] == true || response['Status'] == true) return true;
    final rowId = (response['MasterRowId'] as num?)?.toInt();
    return rowId != null && rowId > 0;
  }

  static String? _insertMessage(Map<String, dynamic> response) =>
      (response['Message'] ?? response['message'] ?? response['statusMsg'])
          ?.toString();
}

/// Outcome of an `Air_Ticket_Amendment_Insert` call.
class AirTicketAmendmentResult {
  final bool success;
  final String? message;

  /// The row the amendment was written as, when the endpoint names it.
  final int? masterRowId;

  const AirTicketAmendmentResult({
    required this.success,
    this.message,
    this.masterRowId,
  });
}