import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/pendingCounts.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class PendingCountRepository {
  final ApiService apiService;

  PendingCountRepository(this.apiService);

  Future<PendingCounts> getPendingCounts() async {
    print('Fetching pending counts from API...');
     final spName = await StorageUtil.getStoredProcedureName();
    final apiUrl = await StorageUtil.getCurrentApiUrl() ?? '';
    final isBellagio = apiUrl.contains('bty.world');

    // Bellagio runs its own stored-procedure branch; Ballys stays on 88965.
    final iid = isBellagio ? 8896590 : 88965;

    final response = await apiService.post('CommonExecute', {
      "HasReturnData": "T",
      "Parameters": [
        {
          "Para_Data": iid,
          "Para_Direction": "Input",
          "Para_Lenth": 1,
          "Para_Name": "@Iid",
          "Para_Type": "int",
        }
      ],
      "SpName": spName,
      "con": "1",
    });
print('API response for pending counts: $response');
    var counts = const PendingCounts();
    if (response['strRturnRes'] == true &&
        response['CommonResult'] != null &&
        response['CommonResult']['Table'] is List &&
        (response['CommonResult']['Table'] as List).isNotEmpty) {
      final tableData = response['CommonResult']['Table'][0];
      counts = PendingCounts.fromJson(tableData);
    }

    // Ballys takes its reservation counts from StatusCounts/Get; OTP and
    // birthday gift counts stay on the stored procedure above.
    final location = await StorageUtil.getCurrentLocation();
    final isBallys =
        location?.code.split('_').first.toUpperCase() == 'BALLYS';
    if (isBallys) {
      try {
        counts = await _applyStatusCounts(counts);
      } catch (e) {
        print('StatusCounts/Get failed: $e');
      }
    }

    return counts;
  }

  /// GET `{baseUrl}/StatusCounts/Get` — `{ success, counts: [{ feature,
  /// pending, ... }], totals: { pending, ... } }`.
  Future<PendingCounts> _applyStatusCounts(PendingCounts counts) async {
    final response = await apiService.get('StatusCounts/Get');
    if (response['success'] != true) return counts;

    final featurePending = <String, int>{};
    final rows = response['counts'];
    if (rows is List) {
      for (final row in rows.whereType<Map>()) {
        final feature = row['feature']?.toString();
        if (feature == null) continue;
        featurePending[feature] = (row['pending'] as num?)?.toInt() ?? 0;
      }
    }

    final totals = response['totals'];
    final totalPending = totals is Map
        ? (totals['pending'] as num?)?.toInt()
        : null;

    return counts.copyWith(
      reservation: totalPending ??
          featurePending.values.fold<int>(0, (sum, n) => sum + n),
      featurePending: featurePending,
    );
  }
}