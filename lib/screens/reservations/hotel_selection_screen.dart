// import 'package:ballys_reservation_app/core/constants.dart';
// import 'package:ballys_reservation_app/models/reservation/hotel_category_type.dart';
// import 'package:ballys_reservation_app/models/reservation/hotel_desc.dart';
// import 'package:ballys_reservation_app/providers/hotels_provider.dart';
// import 'package:ballys_reservation_app/providers/room_category_provider.dart';
// import 'package:ballys_reservation_app/providers/selected_hotel_provider.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:intl/intl.dart';
// import 'package:dropdown_search/dropdown_search.dart';

// class HotelAndRoomSelectionScreen extends ConsumerStatefulWidget {
//   final HotelCategory hotelCategory;
//   const HotelAndRoomSelectionScreen(this.hotelCategory, {super.key});

//   @override
//   ConsumerState<HotelAndRoomSelectionScreen> createState() =>
//       _HotelAndRoomSelectionBottomSheetState();
// }

// class _HotelAndRoomSelectionBottomSheetState
//     extends ConsumerState<HotelAndRoomSelectionScreen> {
//   final TextEditingController _hotelRoomController = TextEditingController();
//   final TextEditingController _dateRangeController = TextEditingController();

//   DateTimeRange? selectedDateRange;
//   double? selectedHotelId;
//   String? selectedHotelName;
//   double? selectedRoomCategoryId;
//   String? selectedRoomCategoryName;
//   int? selectedHotelAndRoom;
//   int? numberOfNights;

//   int numberOfAdults = 1;
//   int numberOfChildren = 0;
//   int numberOfRooms = 1;

//   // @override
//   // void initState() {
//   //   super.initState();

//   //   final hotelState = ref.read(selectedHotelProvider);

//   //   if (hotelState.selectedDateRange != null) {
//   //     selectedDateRange = hotelState.selectedDateRange;
//   //     numberOfNights = selectedDateRange?.duration.inDays ?? 0;
//   //     _dateRangeController.text =
//   //         "${DateFormat('yyyy-MM-dd').format(selectedDateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(selectedDateRange!.end)}";
//   //   }
//   // }

//   void _selectDateRange(BuildContext context) async {
//     DateTimeRange? pickedDateRange = await showDateRangePicker(
//       context: context,
//       firstDate: DateTime.now(),
//       lastDate: DateTime.now().add(const Duration(days: 365)),
//       builder: (context, child) {
//         return Theme(
//           data: Theme.of(context).copyWith(
//             colorScheme: const ColorScheme.light(
//               primary: Colors.blue,
//               onPrimary: Colors.white,
//               onSurface: Colors.black,
//             ),
//           ),
//           child: child!,
//         );
//       },
//     );

//     if (pickedDateRange != null) {
//       setState(() {
//         selectedDateRange = pickedDateRange;
//         numberOfNights = pickedDateRange.duration.inDays;

//         _dateRangeController.text =
//             "${DateFormat('yyyy-MM-dd').format(pickedDateRange.start)} - ${DateFormat('yyyy-MM-dd').format(pickedDateRange.end)}";
//       });
//     }
//   }

//   void _updateAdults(count) {
//     if (count >= 1) {
//       setState(() {
//         numberOfAdults = count;
//       });
//     }
//   }

//   void _updateChildren(count) {
//     if (count >= 0) {
//       setState(() {
//         numberOfChildren = count;
//       });
//     }
//   }

//   void _updateRooms(count) {
//     if (count >= 1) {
//       setState(() {
//         numberOfRooms = count;
//       });
//     }
//   }

//   Future<void> getSelectedHotelRoomCategories(double hotelId) async {
//     // try {
//     //   final response = await widget.hotelCategory
//     //       .getSelectedHotelRoomCategories(hotelId);
//     //   roomCategoriesNotifier.value =
//     //       response.map((category) => category.toJson()).toList();
//     // } catch (e) {
//     //   roomCategoriesNotifier.value = [];
//     // }
//   }

//   void _setHotel(selectedHotel) {
//     selectedHotelId = selectedHotel?['Hotel_IID'];
//     selectedHotelName = selectedHotel?['HotelName'] ?? '';
//     if (selectedHotelId != null) {
//       setState(() {
//         numberOfRooms = 0;
//         // selectedRoomCategoryId = 0;
//         // selectedRoomCategoryName = '';
//       });
//       // getSelectedHotelRoomCategories(selectedHotelId!);
//     } else {
//       // ref.read(roomCategoryProvider.notifier).state = []; // Reset categories
//     }
//   }

//   void _setRoomCategory(selectedRoomCategory) {
//     selectedRoomCategoryId = selectedRoomCategory?['CatCode'];
//     selectedRoomCategoryName = selectedRoomCategory?['CatName'] ?? '';
//     // if (selectedHotelId != null) {
//     //   getSelectedHotelRoomCategories(selectedHotelId!);
//     // } else {
//     //   // ref.read(roomCategoryProvider.notifier).state = []; // Reset categories
//     // }
//   }

//   void _saveHotelSelection() {
//     final hotel = HotelDescip(
//       hotelId: selectedHotelId,
//       hotelName: selectedHotelName,
//       roomCategoryId: null,
//       roomCategoryName: null,
//       roomTypeId: null,
//       roomTypeName: null,
//       guestCount: numberOfAdults,
//       selectedDateRange: null,
//       arrivalDate: null,
//       departureDate: null,
//       childrenCount: numberOfChildren,
//       roomCount: numberOfRooms,
//       noOfNights: numberOfNights,
//       selectedCost: 0,
//       costIndex: 0,
//     );

//     print("######################################");
//     print(hotel.toJson());

//     if (selectedDateRange == null || selectedHotelId == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Please complete all selections.")),
//       );
//       return;
//     }

//     // Add the new state to the provider
//     ref.read(selectedHotelProvider.notifier).addHotel(hotel);

//     // Close the bottom sheet
//     Navigator.pop(context);
//   }

//   void _showCostCalculator(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       builder: (BuildContext context) {
//         return CostCalculatorBottomSheet(
//           onBackPressed: () {
//             Navigator.pop(context); // Navigate back to the previous sheet
//           },
//           selectedHotelName: selectedHotelName ?? '',
//           numberOfNights: numberOfNights ?? 0,
//           numberOfRooms: numberOfRooms,
//         );
//       },
//     );
//   }

//   Widget _buildCounter(
//       String label, int count, int type, Function(int) onCountChange) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(label,
//                 style:
//                     const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//             Row(
//               children: [
//                 GestureDetector(
//                   onTap: () => onCountChange(count - 1),
//                   child: Container(
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: Colors.grey,
//                       borderRadius: BorderRadius.circular(50),
//                     ),
//                     child: const Icon(Icons.remove, color: Colors.white),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 SizedBox(
//                   width: 40,
//                   child: Text(
//                     count.toString(),
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(fontSize: 18),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 GestureDetector(
//                   onTap: () => onCountChange(count + 1),
//                   child: Container(
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: Colors.grey,
//                       borderRadius: BorderRadius.circular(50),
//                     ),
//                     child: const Icon(Icons.add, color: Colors.white),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final hotelsAsMap = ref.watch(hotelsProvider.notifier).hotelsAsMap;
//     final hotelsDropDownKey = GlobalKey<DropdownSearchState>();
//     final roomCategoriesDropDownKey = GlobalKey<DropdownSearchState>();

//     print("################ state #########################");
//     print(roomCategories);
//     print("#########################################");

//     return Scaffold(
//       appBar: AppBar(),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               "Select Hotels & Rooms",
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             TextFormField(
//               controller: _dateRangeController,
//               readOnly: true,
//               decoration: InputDecoration(
//                 labelText: "Select Date Range",
//                 border: const OutlineInputBorder(),
//                 suffixIcon: IconButton(
//                   icon: const Icon(Icons.calendar_today),
//                   onPressed: () async {
//                     _selectDateRange(context);
//                   },
//                 ),
//               ),
//             ),
//             if (selectedDateRange != null) ...[
//               Align(
//                 alignment: Alignment.centerRight,
//                 child: Padding(
//                   padding: const EdgeInsets.only(top: 8.0),
//                   child: Text(
//                     "$numberOfNights night(s)",
//                     style: const TextStyle(
//                       fontSize: 14,
//                       fontStyle: FontStyle.italic,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//             const SizedBox(height: 16),
//             _buildCounter(
//                 "Adults", numberOfAdults, 1, (count) => _updateAdults(count)),
//             const SizedBox(height: 16),
//             _buildCounter("Children", numberOfChildren, 1,
//                 (count) => _updateChildren(count)),
//             const SizedBox(height: 16),
//             _buildCounter(
//                 "Rooms", numberOfRooms, 2, (count) => _updateRooms(count)),
//             const SizedBox(height: 16),
//             DropdownSearch<Map<String, dynamic>>(
//               key: hotelsDropDownKey,
//               items: (filter, infiniteScrollProps) =>
//                   ref.watch(hotelsProvider.notifier).hotelsAsMap,
//               itemAsString: (item) => item['HotelName'] ?? '',
//               compareFn: (item1, item2) =>
//                   item1['Hotel_IID'] == item2['Hotel_IID'],
//               decoratorProps: const DropDownDecoratorProps(
//                 decoration: InputDecoration(
//                   labelText: 'Select Hotel',
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//               onChanged: (selectedHotel) {
//                 _setHotel(selectedHotel);
//               },
//               // selectedItem: selectedHotelAndRoom,
//               popupProps: PopupProps.menu(
//                 fit: FlexFit.loose,
//                 constraints: const BoxConstraints(),
//                 showSearchBox: true,
//                 searchFieldProps: const TextFieldProps(autofocus: true),
//                 itemBuilder: (BuildContext context, Map<String, dynamic> item,
//                     bool isSelected, bool isFocused) {
//                   return Container(
//                     padding: const EdgeInsets.symmetric(
//                         vertical: 0.5), // Reduce padding further
//                     child: ListTile(
//                       minVerticalPadding: 0.2,
//                       // contentPadding: EdgeInsets.zero,
//                       title: Text(item['HotelName'] ?? ''),
//                       selected: isSelected,
//                       tileColor: isFocused
//                           ? Colors.grey.shade300
//                           : null, // Optional: highlight focused item
//                     ),
//                   );
//                 },
//                 onDismissed: () {
//                   // Prevent the bottom sheet from closing when dropdown is interacted with.
//                   // You can keep this empty or add custom behavior if needed.
//                 },
//               ),
//             ),
//             const SizedBox(height: 16),
//             DropdownSearch<Map<String, dynamic>>(
//               key: roomCategoriesDropDownKey,
//               items: (filter, infiniteScrollProps) => roomCategories,
//               itemAsString: (item) => item['CatName'] ?? '',
//               compareFn: (item1, item2) => item1['CatCode'] == item2['CatCode'],
//               decoratorProps: const DropDownDecoratorProps(
//                 decoration: InputDecoration(
//                   labelText: 'Select Category',
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//               onChanged: (selectedRoomCategory) {
//                 _setRoomCategory(selectedRoomCategory);
//               },
//               // selectedItem: selectedHotelAndRoom,
//               popupProps: PopupProps.menu(
//                 fit: FlexFit.loose,
//                 constraints: const BoxConstraints(),
//                 showSearchBox: true,
//                 searchFieldProps: const TextFieldProps(autofocus: true),
//                 itemBuilder: (BuildContext context, Map<String, dynamic> item,
//                     bool isSelected, bool isFocused) {
//                   return Container(
//                     padding: const EdgeInsets.symmetric(
//                         vertical: 0.5), // Reduce padding further
//                     child: ListTile(
//                       minVerticalPadding: 0.2,
//                       // contentPadding: EdgeInsets.zero,
//                       title: Text(item['CatName'] ?? ''),
//                       selected: isSelected,
//                       tileColor: isFocused
//                           ? Colors.grey.shade300
//                           : null, // Optional: highlight focused item
//                     ),
//                   );
//                 },
//                 onDismissed: () {
//                   // Prevent the bottom sheet from closing when dropdown is interacted with.
//                   // You can keep this empty or add custom behavior if needed.
//                 },
//               ),
//             ),
//             const SizedBox(height: 16),
//             Align(
//               alignment: Alignment.bottomCenter,
//               child: SizedBox(
//                 width: double.infinity, // Full-width button
//                 child: ElevatedButton(
//                   onPressed: _saveHotelSelection,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Constants.kSecondaryColor,
//                     foregroundColor: Colors.white, // Red color
//                     shape: RoundedRectangleBorder(
//                       borderRadius:
//                           BorderRadius.circular(12), // Slightly rounded corners
//                     ),
//                     padding: const EdgeInsets.symmetric(
//                         vertical: 16), // Button height
//                   ),
//                   child: const Text(
//                     "Save Selection",
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 _showCostCalculator(
//                     context); // Open the cost calculator bottom sheet
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Constants.kPrimaryColor,
//                 foregroundColor: Colors.white, // Red color
//                 shape: RoundedRectangleBorder(
//                   borderRadius:
//                       BorderRadius.circular(12), // Slightly rounded corners
//                 ),
//                 padding:
//                     const EdgeInsets.symmetric(vertical: 16), // Button height
//               ),
//               child: const Text("Open Cost Calculator"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class CostCalculatorBottomSheet extends StatelessWidget {
//   final Function onBackPressed;
//   final String selectedHotelName;
//   final int numberOfNights;
//   final int numberOfRooms;

//   const CostCalculatorBottomSheet({
//     required this.onBackPressed,
//     required this.selectedHotelName,
//     required this.numberOfNights,
//     required this.numberOfRooms,
//   });

//   @override
//   Widget build(BuildContext context) {
//     // Example cost calculation logic (replace with actual)
//     double costPerNight = 100.0; // Example cost per night
//     double totalCost = costPerNight * numberOfNights * numberOfRooms;

//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 "Cost Calculator",
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               IconButton(
//                 icon: const Icon(Icons.arrow_back),
//                 onPressed: () => onBackPressed(), // Back button
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           Text(
//             "Hotel: $selectedHotelName",
//             style: TextStyle(fontSize: 16),
//           ),
//           Text(
//             "Number of Nights: $numberOfNights",
//             style: TextStyle(fontSize: 16),
//           ),
//           Text(
//             "Number of Rooms: $numberOfRooms",
//             style: TextStyle(fontSize: 16),
//           ),
//           const SizedBox(height: 16),
//           Text(
//             "Total Cost: \$${totalCost.toStringAsFixed(2)}",
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//         ],
//       ),
//     );
//   }
// }
