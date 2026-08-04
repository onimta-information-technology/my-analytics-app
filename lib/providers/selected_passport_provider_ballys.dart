
import 'package:ballys_reservation_app/components/passport_upload_widget_ballys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the passport bio-page files picked in the air-ticket screen so they
/// survive navigation back to the reservation form and can be attached to the
/// current guest when snapshotting.
class SelectedPassportBallysNotifier extends StateNotifier<List<PassportFileBallys>> {
  SelectedPassportBallysNotifier() : super([]);

  void setFiles(List<PassportFileBallys> files) {
    state = [...files];
  }
}

final selectedPassportBallysProvider =
    StateNotifierProvider<SelectedPassportBallysNotifier, List<PassportFileBallys>>(
        (ref) => SelectedPassportBallysNotifier());
