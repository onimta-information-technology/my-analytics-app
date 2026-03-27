import 'package:ballys_reservation_app/data/repositories/air_ticket_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import '../models/air_ticket.dart';


class AirTicketState {
  final List<AirTicket> recent;
  final List<AirTicket> past;

  const AirTicketState({
    this.recent = const [],
    this.past = const [],
  });

  AirTicketState copyWith({
    List<AirTicket>? recent,
    List<AirTicket>? past,
  }) {
    return AirTicketState(
      recent: recent ?? this.recent,
      past: past ?? this.past,
    );
  }
}

class AirTicketNotifier extends StateNotifier<AirTicketState> {
  final AirTicketRepository repository;

  AirTicketNotifier(this.repository) : super(const AirTicketState());

  void clear() {
    state = const AirTicketState();
  }

  Future<AirTicketState> fetchAll() async {
    try {
      final results = await Future.wait([
        repository.getRecentAirTickets(),
        repository.getPastAirTickets(),
      ]);
      state = AirTicketState(
        recent: results[0],
        past: results[1],
      );
      return state;
    } catch (e) {
      state = const AirTicketState();
      return state;
    }
  }

  Future<AirTicketState> fetchRecent() async {
    try {
      final recent = await repository.getRecentAirTickets();
      state = state.copyWith(recent: recent);
      return state;
    } catch (e) {
      return state;
    }
  }

  Future<AirTicketState> fetchPast() async {
    try {
      final past = await repository.getPastAirTickets();
      state = state.copyWith(past: past);
      return state;
    } catch (e) {
      return state;
    }
  }
}

// ── Providers ──────────────────────────────────────────────────────────────

final _secureStorageProvider = Provider((_) => const FlutterSecureStorage());

final _apiServiceProvider = Provider((ref) {
  final storage = ref.read(_secureStorageProvider);
  return ApiService(storage);
});

final airTicketRepositoryProvider = Provider((ref) {
  final apiService = ref.read(_apiServiceProvider);
  return AirTicketRepository(apiService);
});

final airTicketProvider =
    StateNotifierProvider<AirTicketNotifier, AirTicketState>((ref) {
  final repo = ref.read(airTicketRepositoryProvider);
  return AirTicketNotifier(repo);
});