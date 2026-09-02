import 'package:ballys_reservation_app/data/repositories/amendment_repository.dart';
import 'package:ballys_reservation_app/models/amendment_ballys.dart';
import 'package:ballys_reservation_app/providers/reservation_provider_ballys.dart'
    show apiServiceProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The four buckets the amendments screen shows, in tab order.
const List<String> kAmendmentStatuses = [
  'Pending',
  'Checked',
  'Approved',
  'Rejected',
];

/// Holds every raised amendment — air ticket and hotel together — bucketed by
/// status the same way [reservationBallysProvider] buckets reservations.
class AmendmentBallysNotifier
    extends StateNotifier<Map<String, List<AmendmentBallys>>> {
  final AmendmentRepository amendmentRepository;

  AmendmentBallysNotifier(this.amendmentRepository) : super(_emptyBuckets());

  static Map<String, List<AmendmentBallys>> _emptyBuckets() => {
    for (final status in kAmendmentStatuses) status: <AmendmentBallys>[],
  };

  /// Pulls both feeds, merges them newest-first and re-buckets by status.
  ///
  /// The two calls run together — neither feed depends on the other, and the
  /// screen only draws once both have landed.
  Future<void> getAmendments() async {
    final results = await Future.wait([
      amendmentRepository.getAirAmendments(),
      amendmentRepository.getHotelAmendments(),
    ]);

    final all = [...results[0], ...results[1]]
      ..sort((a, b) {
        final aDate = a.createdDate;
        final bDate = b.createdDate;
        if (aDate == null && bDate == null) return b.rowId.compareTo(a.rowId);
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    final buckets = _emptyBuckets();
    for (final amendment in all) {
      // An unknown status still has to be reachable, so it lands in Pending.
      final bucket = buckets.containsKey(amendment.status)
          ? amendment.status
          : 'Pending';
      buckets[bucket]!.add(amendment);
    }
    state = buckets;
  }

  void clearAmendments() => state = _emptyBuckets();

  /// Checks / approves / rejects [amendment], refreshing the list on success.
  Future<AmendmentStatusResult> updateAmendmentStatus({
    required AmendmentBallys amendment,
    required String status,
    required String remarks,
  }) async {
    try {
      final result = await amendmentRepository.updateStatus(
        amendment: amendment,
        status: status,
        remarks: remarks,
      );
      if (result.success) await getAmendments();
      return result;
    } catch (e) {
      return AmendmentStatusResult(success: false, message: e.toString());
    }
  }
}

final amendmentRepositoryProvider = Provider((ref) {
  return AmendmentRepository(ref.read(apiServiceProvider));
});

final amendmentBallysProvider =
    StateNotifierProvider<
      AmendmentBallysNotifier,
      Map<String, List<AmendmentBallys>>
    >((ref) {
      return AmendmentBallysNotifier(ref.read(amendmentRepositoryProvider));
    });
