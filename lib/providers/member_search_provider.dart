import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MemberSearchNotifier extends StateNotifier<Guest> {
  MemberSearchNotifier()
      : super(
          Guest(
            mid: "",
            memberName: "",
            country: "",
            lastVisitDate: "1990-01-01",
            age: 0,
            gRating: "",
            mGroup: "",
            gName: "",
          ),
        );

  void updateMemberInfo(String mid, String mName) {
    state = Guest(
      mid: mid,
      memberName: mName ,
      country: "",
      lastVisitDate: "1990-01-01",
      age: 0,
      gRating: "",
      mGroup: "",
      gName: "",
    );
  }


  void resetState() {
    state = Guest(
      mid: "",
      memberName: "",
      country: "",
      lastVisitDate: "1990-01-01",
      age: 0,
      gRating: "",
      mGroup: "",
      gName: "",
    );
  }
}

final memberSearchProvider = StateNotifierProvider<MemberSearchNotifier, Guest>(
    (ref) => MemberSearchNotifier());
