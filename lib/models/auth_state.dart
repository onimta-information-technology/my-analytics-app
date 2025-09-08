import 'package:ballys_reservation_app/models/user_model.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  AuthState({this.user, this.isLoading = false, this.error});
}
