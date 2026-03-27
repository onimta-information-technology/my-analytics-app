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
      "SpName": "sp_CRM_Common_API",
      "con": "1",
    });

    if (response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        (response['CommonResult']['Table'] as List).isNotEmpty) {
      final tableData = response['CommonResult']['Table'] as List;
      return tableData
          .map((item) => AirTicket.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    return [];
  }
}