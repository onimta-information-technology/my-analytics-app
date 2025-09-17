import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/inactive_members_repository.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/app_mode_setting_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class InactiveMembersScreen extends ConsumerStatefulWidget {
  final InactiveMembersRepository inactiveMembersRepository;

  const InactiveMembersScreen(
      {super.key, required this.inactiveMembersRepository});

  @override
  ConsumerState<InactiveMembersScreen> createState() =>
      _InactiveMembersScreenState();
}

class _InactiveMembersScreenState extends ConsumerState<InactiveMembersScreen> {
  String selectedDateOption = "1";
  String selectedBuyInOption = "1";
  bool _isLoading = false;

  List<Guest> originalMembers = [];
  List<Guest> inactiveMembers = [];

@override
  void initState() {
    super.initState();
    // ADD THIS BLOCK
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppMode();
    });
  }
  Future<void> _initializeAppMode() async {
    try {
      final salesCode = await StorageUtil.getSalesCode();
      if (salesCode != null) {
        ref.read(appmodeSettingsProvider.notifier).setSalesCode(salesCode);
      }
    } catch (e) {
      print('Error initializing app mode: $e');
    }
  }

  void _applyFilter() async {
    setState(() {
      _isLoading = true;
    });
    final appMode = ref.read(appmodeSettingsProvider).appMode;
    final salesCode = await StorageUtil.getSalesCode();

    final inactiveMembers_ = await widget.inactiveMembersRepository
        .getInactiveMembers(selectedDateOption, selectedBuyInOption, appMode,salesCode!);

    setState(() {
      originalMembers = inactiveMembers_;
      inactiveMembers = List<Guest>.from(originalMembers);
      _isLoading = false;
    });
  }

  final Map<String, String> ratingImageMap = {
    "CLASSIC": "assets/images/ratings/CLASSIC.png",
    "DIAMOND": "assets/images/ratings/DIAMOND.png",
    "GOLD": "assets/images/ratings/GOLD.png",
    "INFINITY": "assets/images/ratings/INFINITY.png",
    "PLATINUM": "assets/images/ratings/PLATINUM.png",
    "SILVER": "assets/images/ratings/SILVER.png",
  };

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);
    ref.listen<AppModeSettings>(appmodeSettingsProvider, (prev, next) {
      if (prev?.appMode != next.appMode) {
        _applyFilter(); 
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inactive Members'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      if (value.isEmpty) {
                        inactiveMembers = List<Guest>.from(originalMembers);
                      } else {
                        inactiveMembers = originalMembers.where((guest) {
                          return guest.memberName
                                  .toLowerCase()
                                  .contains(value.toLowerCase()) ||
                              guest.mid
                                  .toLowerCase()
                                  .contains(value.toLowerCase());
                        }).toList();
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.filter_list),
                      onPressed: () => _showFilterDialog(context),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: inactiveMembers.isEmpty
                    ? const Center(
                        child: Text("No inactive members available"),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ListView.builder(
                          itemCount: inactiveMembers.length,
                          itemBuilder: (context, index) {
                            final guest = inactiveMembers[index];
                            return Stack(
                              children: [
                                InkWell(
                                  key: ValueKey(guest.mid),
                                  splashColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () {
                                    ref
                                        .read(selectedGuestProvider.notifier)
                                        .setSelectedGuest(guest);
                                    context.push('/home/profile');
                                  },
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 5.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    elevation: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                          left: 16.0,
                                          right: 16.0,
                                          top: 28.0,
                                          bottom: 16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  "${guest.mid} - ${guest.memberName}",
                                                  style: TextStyle(
                                                    fontSize:
                                                        fontSettings.fontSize,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.calendar_today,
                                                color: Colors.grey,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Last visit on ${DateFormat('dd MMM yyyy').format(DateTime.parse(guest.lastVisitDate))}',
                                                style: TextStyle(
                                                  fontSize:
                                                      fontSettings.fontSize,
                                                  fontWeight:
                                                      fontSettings.fontWeight,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: -2,
                                  child: Padding(
                                    padding: const EdgeInsets.all(0),
                                    child: SizedBox(
                                      width: 80,
                                      height: 26,
                                      child: ratingImageMap[guest.gRating] !=
                                              null
                                          ? Hero(
                                              tag: "rating-image-${guest.mid}",
                                              child: Image.asset(
                                                ratingImageMap[guest.gRating]!,
                                                fit: BoxFit.contain,
                                              ),
                                            )
                                          : Hero(
                                              tag: "rating-image-${guest.mid}",
                                              child: Image.asset(
                                                "assets/images/ratings/CLASSIC.png",
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color.fromARGB(135, 117, 115, 115),
                ),
                child: const Center(
                  child: RefreshProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Constants.kSecondaryColor),
                  ),
                ),
              ),
            ),
            const Watermark(), 
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              title: const Text('Filter'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                   // mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Date (Months)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            RadioListTile(
                                title: const Text('1'),
                                value: '1',
                                groupValue: selectedDateOption,
                                onChanged: (value) {
                                  setState(() {
                                    selectedDateOption = value!;
                                  });
                                }),
                            RadioListTile(
                                title: const Text('03'),
                                value: '2',
                                groupValue: selectedDateOption,
                                onChanged: (value) {
                                  setState(() {
                                    selectedDateOption = value!;
                                  });
                                }),
                            RadioListTile(
                                title: const Text('06'),
                                value: '3',
                                groupValue: selectedDateOption,
                                onChanged: (value) {
                                  setState(() {
                                    selectedDateOption = value!;
                                  });
                                }),
                            RadioListTile(
                                title: const Text('12'),
                                value: '4',
                                groupValue: selectedDateOption,
                                onChanged: (value) {
                                  setState(() {
                                    selectedDateOption = value!;
                                  });
                                }),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Buy In',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            RadioListTile(
                                title: const Text('1M'),
                                value: '1',
                                groupValue: selectedBuyInOption,
                                onChanged: (value) {
                                  setState(() {
                                    selectedBuyInOption = value!;
                                  });
                                }),
                            RadioListTile(
                                title: const Text('2.5M'),
                                value: '2',
                                groupValue: selectedBuyInOption,
                                onChanged: (value) {
                                  setState(() {
                                    selectedBuyInOption = value!;
                                  });
                                }),
                            RadioListTile(
                                title: const Text('5M'),
                                value: '3',
                                groupValue: selectedBuyInOption,
                                onChanged: (value) {
                                  setState(() {
                                    selectedBuyInOption = value!;
                                  });
                                }),
                            RadioListTile(
                                title: const Text('10M'),
                                value: '4',
                                groupValue: selectedBuyInOption,
                                onChanged: (value) {
                                  setState(() {
                                    selectedBuyInOption = value!;
                                  });
                                }),
                            RadioListTile(
                                title: const Text('20M'),
                                value: '5',
                                groupValue: selectedBuyInOption,
                                onChanged: (value) {
                                  setState(() {
                                    selectedBuyInOption = value!;
                                  });
                                }),
                            RadioListTile(
                                title: const Text('100M'),
                                value: '6',
                                groupValue: selectedBuyInOption,
                                onChanged: (value) {
                                  setState(() {
                                    selectedBuyInOption = value!;
                                  });
                                }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      setState(() {
                        selectedDateOption = "1";
                        selectedBuyInOption = "1";
                      });
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _applyFilter();
                    },
                    child: const Text('Apply Filter')),
              ],
            );
          },
        );
      },
    );
  }
}
