import 'package:ballys_reservation_app/components/passport_upload_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the passport bio-page files picked in the air-ticket screen so they
/// survive navigation back to the reservation form and can be attached to the
/// current guest when snapshotting.
class SelectedPassportNotifier extends StateNotifier<List<PassportFile>> {
  SelectedPassportNotifier() : super([]);

  void setFiles(List<PassportFile> files) {
    state = [...files];
  }
}

final selectedPassportProvider =
    StateNotifierProvider<SelectedPassportNotifier, List<PassportFile>>(
        (ref) => SelectedPassportNotifier());
