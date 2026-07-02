import 'package:ballys_reservation_app/components/passport_upload_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the passport bio-data files picked in the air-ticket screen so they
/// survive the navigation back to the reservation screen and get included in
/// the save payload.
class SelectedPassportNotifier extends StateNotifier<List<PassportFile>> {
  SelectedPassportNotifier() : super([]);

  void setFiles(List<PassportFile> files) {
    state = [...files];
  }

  void clear() {
    state = [];
  }
}

final selectedPassportProvider =
    StateNotifierProvider<SelectedPassportNotifier, List<PassportFile>>(
        (ref) => SelectedPassportNotifier());
