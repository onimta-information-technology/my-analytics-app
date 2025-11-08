import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/hotel_repository.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_cost_response.dart';
import 'package:ballys_reservation_app/models/reservation/hotel_desc.dart';
import 'package:ballys_reservation_app/providers/hotels_provider.dart';
import 'package:ballys_reservation_app/providers/selected_hotel_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';

class HotelAndRoomSelectionBottomSheet extends ConsumerStatefulWidget {
  final HotelRepository hotelRepository;
  const HotelAndRoomSelectionBottomSheet(this.hotelRepository, {super.key});

  @override
  ConsumerState<HotelAndRoomSelectionBottomSheet> createState() =>
      _HotelAndRoomSelectionBottomSheetState();
}

class _HotelAndRoomSelectionBottomSheetState
    extends ConsumerState<HotelAndRoomSelectionBottomSheet> {
  final TextEditingController _hotelRoomController = TextEditingController();
  final TextEditingController _dateRangeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final ValueNotifier<List<Map<String, dynamic>>> roomCategoriesNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  final ValueNotifier<List<Map<String, dynamic>>> roomTypesNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  final ValueNotifier<String> costNotifier = ValueNotifier<String>("0");

  @override
  void initState() {
    super.initState();
    hotelList = List.from(ref.read(selectedHotelProvider));
  }

  bool editMode = false;
  int? editIndex;

  DateTimeRange? selectedDateRange;
  DateTime? arrivalDate;
  DateTime? departureDate;

  double? selectedHotelId;
  String? selectedHotelName;
  Map<String, dynamic>? selectedHotel;

  int? selectedRoomCategoryId;
  String? selectedRoomCategoryName;
  Map<String, dynamic>? selectedRoomCategory;

  int? selectedRoomTypeId;
  String? selectedRoomTypeName;
  String? sRoomTypeName;
  String? sMealPlanName;
  Map<String, dynamic>? selectedRoomType;

  int? selectedHotelAndRoom;
  int? numberOfNights;

  dynamic selectedCost;
  int? costIndex;

  int numberOfAdults = 1;
  int numberOfChildren = 0;
  int numberOfRooms = 1;

  List<HotelDescip> hotelList = [];

  void _selectDateRange(BuildContext context) async {
    DateTimeRange? pickedDateRange = await showDateRangePicker(
      context: context,
      initialDateRange: selectedDateRange,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDateRange != null) {
      setState(() {
        selectedDateRange = pickedDateRange;
        numberOfNights = pickedDateRange.duration.inDays;

        arrivalDate = pickedDateRange.start;
        departureDate = pickedDateRange.end;

        _dateRangeController.text =
            "${DateFormat('yyyy-MM-dd').format(pickedDateRange.start)} - ${DateFormat('yyyy-MM-dd').format(pickedDateRange.end)}";
      });
      _clearSelectedCost();
    }
  }

  void _updateAdults(count) {
    if (count >= 1) {
      setState(() {
        numberOfAdults = count;
      });
      _clearSelectedCost();
    }
  }

  void _updateChildren(count) {
    if (count >= 0) {
      setState(() {
        numberOfChildren = count;
      });
      _clearSelectedCost();
    }
  }

  void _updateRooms(count) {
    if (count >= 1) {
      setState(() {
        numberOfRooms = count;
      });
      _clearSelectedCost();
    }
  }

  Future<void> getSelectedHotelRoomCategories(double hotelId,
      {bool clearSelection = true}) async {
    try {
      final response =
          await widget.hotelRepository.getSelectedHotelRoomCategories(hotelId);
      roomCategoriesNotifier.value =
          response.map((category) => category.toJson()).toList();

      if (clearSelection) {
        selectedRoomCategory = null;
        selectedRoomCategoryId = null;
        selectedRoomCategoryName = null;
        selectedRoomType = null;
        selectedRoomTypeId = null;
        selectedRoomTypeName = null;
        roomTypesNotifier.value = [];
      }
    } catch (e) {
      roomCategoriesNotifier.value = [];
    }
  }

  Future<void> getSelectedHotelCategoryRoomTypes(double hotelId, int categoryId,
      {bool clearSelection = true}) async {
    try {
      final response = await widget.hotelRepository
          .getSelectedHotelCategoryRoomTypes(hotelId, categoryId);
      roomTypesNotifier.value =
          response.map((category) => category.toJson()).toList();

      if (clearSelection) {
        selectedRoomType = null;
        selectedRoomTypeId = null;
        selectedRoomTypeName = null;
      }
    } catch (e) {
      roomTypesNotifier.value = [];
    }
  }

  Future<List<HotelCostResponse>?> getHotelCosts() async {
    try {
      final response = await widget.hotelRepository.getHotelCosts(
          hotelName: selectedHotelName!,
          roomCategory: selectedRoomCategoryName!,
          roomType: sRoomTypeName!,
          mealPlan: sMealPlanName!);
      return response;
    } catch (e) {
      return null;
    }
  }

  void _setHotel(hotel) {
    selectedHotel = hotel;
    selectedHotelId = hotel?['Hotel_IID'];
    selectedHotelName = hotel?['HotelName'] ?? '';
    _clearSelectedCost();

    if (selectedHotelId != null) {
      roomCategoriesNotifier.value = [];
      roomTypesNotifier.value = [];
      getSelectedHotelRoomCategories(selectedHotelId!);
    } else {
      // ref.read(roomCategoryProvider.notifier).state = []; // Reset categories
    }
  }

  void _setRoomCategory(roomCategory) {
    selectedRoomCategory = roomCategory;
    selectedRoomCategoryId = roomCategory?['CatCode'];
    selectedRoomCategoryName = roomCategory?['CatName'] ?? '';
    _clearSelectedCost();
    if (selectedHotelId != null && selectedRoomCategoryId != null) {
      roomTypesNotifier.value = [];
      getSelectedHotelCategoryRoomTypes(
          selectedHotelId!, selectedRoomCategoryId!);
    } else {
      // ref.read(roomCategoryProvider.notifier).state = []; // Reset categories
    }
  }

  void _setRoomType(roomtype) {
    selectedRoomType = roomtype;
    selectedRoomTypeId = roomtype?['ID'];
    sRoomTypeName = roomtype?['RoomType'] ?? '';
    sMealPlanName = roomtype?['MealPlan'] ?? '';
    selectedRoomTypeName = '$sRoomTypeName - $sMealPlanName';
    _clearSelectedCost();
  }

  void _handleItemSelected(HotelCostResponse cost, int index) {
    setState(() {
      costIndex = index;
      double calculation = ((cost.netRate! * numberOfNights!) * cost.usRate!) *
          numberOfAdults *
          numberOfRooms;

      costNotifier.value = NumberFormat().format(calculation.round());
    });
  }

  void __editHotel(HotelDescip hotel, int index) {
    setState(() {
      editMode = true;
      editIndex = index;
      numberOfAdults = hotel.guestCount!;
      numberOfChildren = hotel.childrenCount!;
      numberOfRooms = hotel.roomCount!;

      selectedDateRange = hotel.selectedDateRange;
      numberOfNights = hotel.noOfNights;
      arrivalDate = hotel.arrivalDate;
      departureDate = hotel.departureDate;
      _dateRangeController.text =
          "${DateFormat('yyyy-MM-dd').format(hotel.selectedDateRange.start)} - ${DateFormat('yyyy-MM-dd').format(hotel.selectedDateRange.end)}";

      selectedHotelId = hotel.hotel;
      selectedHotelName = hotel.hotelName;
      selectedHotel = {"Hotel_IID": hotel.hotel, "HotelName": hotel.hotelName};

      getSelectedHotelRoomCategories(selectedHotelId!, clearSelection: false);

      selectedRoomCategoryId = hotel.roomCategoryId;
      selectedRoomCategoryName = hotel.roomCategoryName;
      selectedRoomCategory = {
        "CatCode": hotel.roomCategoryId,
        "CatName": hotel.roomCategoryName
      };

      getSelectedHotelCategoryRoomTypes(
          selectedHotelId!, selectedRoomCategoryId!,
          clearSelection: false);

      selectedRoomTypeId = hotel.roomTypeId;
      selectedRoomTypeName = hotel.roomTypeName;
      List<String> parts = hotel.roomTypeName!.split("-");
      selectedRoomType = {
        "ID": hotel.roomTypeId,
        "RoomType": parts[0].trim(),
        "MealPlan": parts[1].trim()
      };
      sRoomTypeName = parts[0].trim();
      sMealPlanName = parts[1].trim();
      selectedCost = hotel.selectedCost;
      costNotifier.value = hotel.selectedCost;
      costIndex = hotel.costIndex;
    });

   
  }

  void _removeHotel(int index) {
    setState(() {
      hotelList.removeAt(index);
    });
  }

  void _saveHotelSelection() {
    final hotel = HotelDescip(
      hotel: selectedHotelId,
      hotelName: selectedHotelName,
      roomCategoryId: selectedRoomCategoryId,
      roomCategoryName: selectedRoomCategoryName,
      roomTypeId: selectedRoomTypeId,
      roomTypeName: selectedRoomTypeName,
      guestCount: numberOfAdults,
      selectedDateRange: selectedDateRange,
      arrivalDate: arrivalDate,
      departureDate: departureDate,
      childrenCount: numberOfChildren,
      roomCount: numberOfRooms,
      noOfNights: numberOfNights,
      selectedCost: costNotifier.value,
      costIndex: costIndex,
    );

    if (selectedDateRange == null ||
        selectedHotelId == null ||
        selectedRoomCategoryId == null ||
        selectedRoomTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all selections.")),
      );
      return;
    }

    if (costNotifier.value == "0") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please calculate the cost to proceed.")),
      );
      return;
    }

    setState(() {
      if (editMode) {
        hotelList[editIndex!] = hotel;
      } else {
        hotelList.add(hotel);
      }
    
    });

    _clearSelection();
  }

  void _acceptChanges() {
    ref.read(selectedHotelProvider.notifier).addHotels(hotelList);
    Navigator.pop(context);
  }

  void _clearSelectedCost() {
    costNotifier.value = "0";
    selectedCost = null;
    costIndex = null;
  }

  void _clearSelection() {
    setState(() {
      numberOfAdults = 1;
      numberOfChildren = 0;
      numberOfRooms = 1;

      selectedDateRange = null;
      arrivalDate = null;
      departureDate = null;
      numberOfNights = null;
      _dateRangeController.text = "";

      selectedHotelId = null;
      selectedHotelName = null;
      selectedHotel = null;

      selectedRoomCategory = null;
      selectedRoomCategoryId = null;
      selectedRoomCategoryName = null;
      roomCategoriesNotifier.value = [];

      selectedRoomType = null;
      selectedRoomTypeId = null;
      selectedRoomTypeName = null;
      sRoomTypeName = null;
      sMealPlanName = null;
      roomTypesNotifier.value = [];

      selectedCost = null;
      costNotifier.value = "0";
      costIndex = null;

      editMode = false;
      editIndex = null;
    });
  }

  void _showCostCalculator(BuildContext context) async {
    if (selectedHotelName == null ||
        selectedRoomCategoryName == null ||
        sRoomTypeName == null ||
        sMealPlanName == null ||
        numberOfNights == null ||
        selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please select Date range ,hotel, category and room type.")),
      );
      return;
    }
    final hotelCosts = await getHotelCosts();
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return CostCalculatorBottomSheet(
            onBackPressed: () {
              Navigator.pop(context);
            },
            onItemSelected: _handleItemSelected,
            hotelCosts: hotelCosts ?? []);
      },
    );
  }

  Widget _buildCounter(
      String label, int count, int type, Function(int) onCountChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                GestureDetector(
                  onTap: () => onCountChange(count - 1),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(Icons.remove, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 40,
                  child: Text(
                    count.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => onCountChange(count + 1),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // final roomCategories = ref.watch(roomCategoryProvider);
    final hotelsDropDownKey = GlobalKey<DropdownSearchState>();
    final roomCategoriesDropDownKey = GlobalKey<DropdownSearchState>();
    final roomTypeDropDownKey = GlobalKey<DropdownSearchState>();

    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setModalState) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Select Hotels & Rooms",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SizedBox(
                    height: 400,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height *
                              0.8, // Minimum height
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.only(top: 10),
                                child: TextFormField(
                                  controller: _dateRangeController,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: "Select Date Range",
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.calendar_today),
                                      onPressed: () async {
                                        _selectDateRange(context);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              if (selectedDateRange != null) ...[
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      "$numberOfNights night(s)",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              _buildCounter("Adults", numberOfAdults, 1,
                                  (count) => _updateAdults(count)),
                              const SizedBox(height: 16),
                              _buildCounter("Children", numberOfChildren, 1,
                                  (count) => _updateChildren(count)),
                              const SizedBox(height: 16),
                              _buildCounter("Rooms", numberOfRooms, 2,
                                  (count) => _updateRooms(count)),
                              const SizedBox(height: 16),
                              DropdownSearch<Map<String, dynamic>>(
                                key: hotelsDropDownKey,
                                selectedItem: selectedHotel,
                                items: (filter, infiniteScrollProps) => ref
                                    .watch(hotelsProvider.notifier)
                                    .hotelsAsMap,
                                itemAsString: (item) => item['HotelName'] ?? '',
                                compareFn: (item1, item2) =>
                                    item1['Hotel_IID'] == item2['Hotel_IID'],
                                decoratorProps: const DropDownDecoratorProps(
                                  decoration: InputDecoration(
                                    labelText: 'Select Hotel',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                onChanged: (selectedHotel) {
                                  _setHotel(selectedHotel);
                                },
                                // selectedItem: selectedHotelAndRoom,
                                popupProps: PopupProps.menu(
                                  fit: FlexFit.loose,
                                  constraints: const BoxConstraints(),
                                  showSearchBox: true,
                                  searchFieldProps:
                                      const TextFieldProps(autofocus: true),
                                  itemBuilder: (BuildContext context,
                                      Map<String, dynamic> item,
                                      bool isSelected,
                                      bool isFocused) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical:
                                              0.5), // Reduce padding further
                                      child: ListTile(
                                        minVerticalPadding: 0.2,
                                        // contentPadding: EdgeInsets.zero,
                                        title: Text(item['HotelName'] ?? ''),
                                        selected: isSelected,
                                        tileColor: isFocused
                                            ? Colors.grey.shade300
                                            : null, // Optional: highlight focused item
                                      ),
                                    );
                                  },
                                  onDismissed: () {
                                    // Prevent the bottom sheet from closing when dropdown is interacted with.
                                    // You can keep this empty or add custom behavior if needed.
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              ValueListenableBuilder<
                                  List<Map<String, dynamic>>>(
                                valueListenable: roomCategoriesNotifier,
                                builder: (context, roomCategories, child) {
                                  return DropdownSearch<Map<String, dynamic>>(
                                    key: roomCategoriesDropDownKey,
                                    selectedItem: selectedRoomCategory,
                                    items: (filter, infiniteScrollProps) =>
                                        roomCategories,
                                    itemAsString: (item) =>
                                        item['CatName'] ?? '',
                                    compareFn: (item1, item2) =>
                                        item1['CatCode'] == item2['CatCode'],
                                    decoratorProps:
                                        const DropDownDecoratorProps(
                                      decoration: InputDecoration(
                                        labelText: 'Select Category',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    onChanged: (selectedRoomCategory) {
                                      _setRoomCategory(selectedRoomCategory);
                                    },
                                    // selectedItem: selectedHotelAndRoom,
                                    popupProps: PopupProps.menu(
                                      fit: FlexFit.loose,
                                      constraints: const BoxConstraints(),
                                      showSearchBox: true,
                                      searchFieldProps:
                                          const TextFieldProps(autofocus: true),
                                      itemBuilder: (BuildContext context,
                                          Map<String, dynamic> item,
                                          bool isSelected,
                                          bool isFocused) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical:
                                                  0.5), // Reduce padding further
                                          child: ListTile(
                                            minVerticalPadding: 0.2,
                                            // contentPadding: EdgeInsets.zero,
                                            title: Text(item['CatName'] ?? ''),
                                            selected: isSelected,
                                            tileColor: isFocused
                                                ? Colors.grey.shade300
                                                : null, // Optional: highlight focused item
                                          ),
                                        );
                                      },
                                      onDismissed: () {
                                        // Prevent the bottom sheet from closing when dropdown is interacted with.
                                        // You can keep this empty or add custom behavior if needed.
                                      },
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              ValueListenableBuilder<
                                  List<Map<String, dynamic>>>(
                                valueListenable: roomTypesNotifier,
                                builder: (context, roomTypes, child) {
                                  return DropdownSearch<Map<String, dynamic>>(
                                    key: roomTypeDropDownKey,
                                    selectedItem: selectedRoomType,
                                    items: (filter, infiniteScrollProps) =>
                                        roomTypes,
                                    itemAsString: (item) {
                                      final roomType = item['RoomType'] ?? '';
                                      final mealPlan = item['MealPlan'] ?? '';
                                      return '$roomType - $mealPlan';
                                    },
                                    compareFn: (item1, item2) =>
                                        item1['ID'] == item2['ID'],
                                    decoratorProps:
                                        const DropDownDecoratorProps(
                                      decoration: InputDecoration(
                                        labelText: 'Select Room Type',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    onChanged: (selectedRoomType) {
                                      _setRoomType(selectedRoomType);
                                    },
                                    // selectedItem: selectedHotelAndRoom,
                                    popupProps: PopupProps.menu(
                                      fit: FlexFit.loose,
                                      constraints: const BoxConstraints(),
                                      showSearchBox: true,
                                      searchFieldProps:
                                          const TextFieldProps(autofocus: true),
                                      itemBuilder: (BuildContext context,
                                          Map<String, dynamic> item,
                                          bool isSelected,
                                          bool isFocused) {
                                        final roomType = item['RoomType'] ?? '';
                                        final mealPlan = item['MealPlan'] ?? '';
                                        dynamic text = '$roomType - $mealPlan';
                                        if (roomType == null) {
                                          text = '';
                                        }

                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical:
                                                  0.5), // Reduce padding further
                                          child: ListTile(
                                            minVerticalPadding: 0.2,
                                            // contentPadding: EdgeInsets.zero,
                                            title: Text(text),
                                            selected: isSelected,
                                            tileColor: isFocused
                                                ? Colors.grey.shade300
                                                : null, // Optional: highlight focused item
                                          ),
                                        );
                                      },
                                      onDismissed: () {
                                        // Prevent the bottom sheet from closing when dropdown is interacted with.
                                        // You can keep this empty or add custom behavior if needed.
                                      },
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    _showCostCalculator(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Constants.kPrimaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 20,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.calculate, size: 20),
                                      SizedBox(width: 10),
                                      Text(
                                        "Cost Calculator",
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  ValueListenableBuilder<String>(
                                    valueListenable: costNotifier,
                                    builder: (context, cost, child) {
                                      return Text(
                                        "Est. Cost LKR $cost",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: editMode
                                      ? OutlinedButton(
                                          onPressed: _saveHotelSelection,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.green,
                                            side: const BorderSide(
                                                color: Colors.green, width: 2),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16),
                                          ),
                                          child: const Text(
                                            "Update Hotel",
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        )
                                      : OutlinedButton(
                                          onPressed: _saveHotelSelection,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                Constants.kSecondaryColor,
                                            side: const BorderSide(
                                                color:
                                                    Constants.kSecondaryColor,
                                                width: 2),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16),
                                          ),
                                          child: const Text(
                                            "Add Hotel",
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: editMode
                                      ? OutlinedButton(
                                          onPressed: _clearSelection,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.grey,
                                            side: const BorderSide(
                                                color: Colors.grey, width: 2),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16),
                                          ),
                                          child: const Text(
                                            "Cancel",
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(
                                height: 16,
                              ),
                              hotelList.isEmpty
                                  ? const Center(
                                      heightFactor: 6.0,
                                      child: Text(
                                        'No hotels available.',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    )
                                  : Column(
                                      children: hotelList.map((hotel) {
                                        int index = hotelList.indexOf(hotel);
                                        return SizedBox(
                                          width: double.infinity,
                                          child: GestureDetector(
                                            onDoubleTap: () {
                                              if (_scrollController
                                                  .hasClients) {
                                                _scrollController.animateTo(
                                                  0,
                                                  duration: const Duration(
                                                      milliseconds: 300),
                                                  curve: Curves.easeInOut,
                                                );
                                              }
                                              __editHotel(hotel, index);
                                            },
                                            child: Card(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 3,
                                                      vertical: 8),
                                              child: Stack(
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12.0),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          hotel.hotelName!,
                                                          style: const TextStyle(
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                        RichText(
                                                          text: TextSpan(
                                                            children: [
                                                              const TextSpan(
                                                                text:
                                                                    "Category: ",
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 16,
                                                                  color: Colors
                                                                      .black,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                              TextSpan(
                                                                text: hotel
                                                                    .roomCategoryName,
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 16,
                                                                  color: Colors
                                                                      .black,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .normal,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 5),
                                                        RichText(
                                                          text: TextSpan(
                                                            children: [
                                                              const TextSpan(
                                                                text:
                                                                    "Room Type: ",
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 16,
                                                                  color: Colors
                                                                      .black,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                              TextSpan(
                                                                text: hotel
                                                                    .roomTypeName,
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 16,
                                                                  color: Colors
                                                                      .black,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .normal,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              "Guest Count: ${hotel.guestCount}",
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          14),
                                                            ),
                                                            const SizedBox(
                                                                width: 20),
                                                            Text(
                                                              "Nights: ${hotel.noOfNights}",
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          14),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                        Text(
                                                          "Estimated Cost: ${hotel.selectedCost}",
                                                          style: const TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Positioned(
                                                    bottom: 0,
                                                    right: 0,
                                                    child: IconButton(
                                                      icon: const Icon(
                                                          Icons.delete,
                                                          color: Colors.red),
                                                      onPressed: () {
                                                        _removeHotel(index);
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                              const SizedBox(
                                height: 16,
                              ),
                              AnimatedOpacity(
                                // opacity: hotelList.isNotEmpty ? 1.0 : 0.0,
                                opacity: 1.0,
                                duration: const Duration(milliseconds: 300),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _acceptChanges,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Constants.kSecondaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 20,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.save, size: 20),
                                        SizedBox(width: 10),
                                        Text(
                                          "Accept Changes",
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

class CostCalculatorBottomSheet extends StatefulWidget {
  final Function onBackPressed;
  final List<HotelCostResponse>? hotelCosts;
  final Function(HotelCostResponse, int) onItemSelected;

  const CostCalculatorBottomSheet({
    super.key,
    required this.onBackPressed,
    required this.hotelCosts,
    required this.onItemSelected,
  });

  @override
  _CostCalculatorBottomSheetState createState() =>
      _CostCalculatorBottomSheetState();
}

class _CostCalculatorBottomSheetState extends State<CostCalculatorBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header with Back Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Cost Calculator",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => widget.onBackPressed(),
              ),
            ],
          ),
          const SizedBox(height: 0),

          // Tabs
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: "General"),
              Tab(text: "Guest's Prev Data"),
            ],
            labelColor: Colors.black,
            indicatorColor: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 16),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                widget.hotelCosts == null || widget.hotelCosts!.isEmpty
                    ? const Center(
                        child: Text(
                          "No data available.",
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: widget.hotelCosts?.length ?? 0,
                        itemBuilder: (context, index) {
                          final cost = widget.hotelCosts![index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: ListTile(
                                onTap: () {
                                  widget.onItemSelected(cost, index);
                                  Navigator.pop(
                                      context); // Close the bottom sheet
                                },
                                title: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Check-In: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(cost.checkIn!))}",
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        Text(
                                          "Check-Out: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(cost.checkOut!))}",
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        const Text("Net Rate: "),
                                        Text(
                                          cost.netRate!.toStringAsFixed(2),
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                // Guest's Prev Data Tab
                const Center(
                  child: Text(
                    "No previous data available.",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
