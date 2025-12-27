// import 'package:ballys_reservation_app/providers/phone_provider.dart';
// import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
// import 'package:ballys_reservation_app/providers/main_profile_details_provider.dart';
// import 'package:flutter/material.dart';
// import 'package:country_picker/country_picker.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// class AddPhone2Dialog extends ConsumerStatefulWidget {
//   final String memberId;
//   final Function(String)? onPhoneAdded;

//   const AddPhone2Dialog({
//     Key? key,
//     required this.memberId,
//     this.onPhoneAdded,
//   }) : super(key: key);

//   @override
//   ConsumerState<AddPhone2Dialog> createState() => _AddPhone2DialogState();
// }

// class _AddPhone2DialogState extends ConsumerState<AddPhone2Dialog> {
//   final TextEditingController phoneController = TextEditingController();
//   final _formKey = GlobalKey<FormState>();

//   Country selectedCountry = Country(
//     phoneCode: "91",
//     countryCode: "IN",
//     e164Sc: 0,
//     geographic: true,
//     level: 1,
//     name: "India",
//     example: "9123456789",
//     displayName: "India (IN) [+91]",
//     displayNameNoCountryCode: "India (IN)",
//     e164Key: "",
//   );

//   @override
//   void dispose() {
//     phoneController.dispose();
//     super.dispose();
//   }

//   void _showCountryPicker() {
//     showCountryPicker(
//       context: context,
//       showPhoneCode: true,
//       onSelect: (Country country) {
//         setState(() {
//           selectedCountry = country;
//         });
//       },
//       countryListTheme: CountryListThemeData(
//         borderRadius: BorderRadius.circular(8),
//         inputDecoration: InputDecoration(
//           labelText: 'Search',
//           hintText: 'Start typing to search',
//           prefixIcon: const Icon(Icons.search),
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(8),
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _handleSubmit() async {
//     if (_formKey.currentState!.validate()) {
//       final phone = phoneController.text.trim();
//       final fullPhoneNumber = '+${selectedCountry.phoneCode}$phone';

//       // Get guest information
//       final guest = ref.read(selectedGuestProvider);
      
//       if (guest == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Guest information not found'),
//             backgroundColor: Colors.red,
//           ),
//         );
//         return;
//       }

//       // Show loading
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (context) => const Center(
//           child: CircularProgressIndicator(),
//         ),
//       );

//       try {
//         // Call API to add phone number
//         final success = await ref.read(phoneProvider.notifier).addPhone2Number(
//               memberId: widget.memberId,
//               phoneNumber: fullPhoneNumber,
//               memberName: guest.memberName,
//             );

//         // Close loading dialog
//         if (mounted) Navigator.pop(context);

//         if (success) {
//           final phoneResponse = ref.read(phoneProvider).phone2Response;
//           final addedPhone = phoneResponse?.phone2 ?? fullPhoneNumber;
          
//           // Update the profile details in provider with the new phone number
//           ref.read(mainProfileDetailsProvider.notifier)
//               .updatePhoneNumber(addedPhone);
          
//           if (widget.onPhoneAdded != null) {
//             widget.onPhoneAdded!(addedPhone);
//           }

//           if (mounted) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text('Phone number added: $addedPhone'),
//                 backgroundColor: Colors.green,
//                 duration: const Duration(seconds: 2),
//               ),
//             );
//             Navigator.pop(context);
//           }
//         } else {
//           if (mounted) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text(
//                   'Failed to add phone number: ${ref.read(phoneProvider).error ?? "Unknown error"}',
//                 ),
//                 backgroundColor: Colors.red,
//               ),
//             );
//           }
//         }
//       } catch (e) {
//         // Close loading dialog
//         if (mounted) Navigator.pop(context);
        
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Error: $e'),
//               backgroundColor: Colors.red,
//             ),
//           );
//         }
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     double screenWidth = MediaQuery.of(context).size.width;
//     double dialogWidth = screenWidth * 0.95;

//     return Dialog(
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       insetPadding: const EdgeInsets.symmetric(horizontal: 10),
//       child: Container(
//         width: dialogWidth,
//         padding: const EdgeInsets.all(15.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Add New Phone Number',
//                 style: TextStyle(
//                   fontSize: 20.0,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 20),

//               // Country Selector and Phone Input in one row
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Country Selector
//                   GestureDetector(
//                     onTap: _showCountryPicker,
//                     child: Container(
//                       width: 60,
//                       height: 56,
//                       padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
//                       decoration: BoxDecoration(
//                         border: Border.all(color: Colors.grey),
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Text(
//                             selectedCountry.flagEmoji,
//                             style: const TextStyle(fontSize: 10),
//                           ),
//                           const SizedBox(height: 4),
//                           Text(
//                             '+${selectedCountry.phoneCode}',
//                             style: const TextStyle(
//                               fontSize: 14,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                           const Icon(Icons.arrow_drop_down, size: 20),
//                         ],
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 4),

//                   // Phone Input
//                   Expanded(
//                     child: TextFormField(
//                       controller: phoneController,
//                       keyboardType: TextInputType.phone,
//                       style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
//                       decoration: InputDecoration(
//                         labelText: 'Phone Number *',
//                         labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
//                         hintText: 'Enter phone number',
//                         hintStyle: TextStyle(color: Colors.grey.shade400),
//                         border: const OutlineInputBorder(),
//                         contentPadding: const EdgeInsets.symmetric(
//                           horizontal: 12.0,
//                           vertical: 14.0,
//                         ),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return 'Phone number is required';
//                         }
//                         if (value.trim().length < 5) {
//                           return 'Please enter a valid phone number';
//                         }
//                         return null;
//                       },
//                       onChanged: (value) {
//                         setState(() {});
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),

//               // Full Number Preview
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade100,
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
//                     const SizedBox(width: 8),
//                     Expanded(
//                       child: Text(
//                         phoneController.text.isEmpty
//                             ? 'Full number will appear here'
//                             : 'Full number: +${selectedCountry.phoneCode} ${phoneController.text}',
//                         style: TextStyle(
//                           fontSize: 13,
//                           color: phoneController.text.isEmpty
//                               ? Colors.grey.shade500
//                               : Colors.grey.shade700,
//                           fontWeight: FontWeight.w400,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 24),

//               // Buttons
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   TextButton(
//                     onPressed: () => Navigator.pop(context),
//                     style: TextButton.styleFrom(
//                       foregroundColor: Colors.grey.shade700,
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 20,
//                         vertical: 12,
//                       ),
//                     ),
//                     child: const Text(
//                       'Cancel',
//                       style: TextStyle(fontSize: 16),
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   ElevatedButton(
//                     onPressed: _handleSubmit,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: const Color.fromARGB(255, 114, 6, 100),
//                       foregroundColor: Colors.white,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 24,
//                         vertical: 12,
//                       ),
//                       elevation: 0,
//                     ),
//                     child: const Text(
//                       'Add',
//                       style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }