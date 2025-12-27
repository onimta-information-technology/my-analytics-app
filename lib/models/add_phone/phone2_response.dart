// class Phone2Response {
//   final String phone2;

//   Phone2Response({
//     required this.phone2,
//   });

//   factory Phone2Response.fromJson(Map<String, dynamic> json) {
//     return Phone2Response(
//       phone2: json['Phone2'] as String? ?? '',
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'Phone2': phone2,
//     };
//   }

//   @override
//   String toString() {
//     return 'PhoneResponse(phone2: $phone2)';
//   }
// }