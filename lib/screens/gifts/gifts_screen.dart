import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class GiftsScreen extends ConsumerStatefulWidget {
  final GiftsRepository giftsRepository;

  const GiftsScreen({super.key, required this.giftsRepository});

  @override
  ConsumerState<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends ConsumerState<GiftsScreen> with ConnectivityMixin{
  String selectedDateOption = "1";
  String selectedBuyInOption = "1";
  bool _isLoading = false;

  List<Guest> originalMembers = [];
  List<Guest> inactiveMembers = [];

  Map<String, List<Guest>> _marketingPersons = {};
  List<MapEntry<String, List<Guest>>> _filteredMarketingPersons = [];
  String? _selectedMGroup;
  String? _selectedGName;
  final TextEditingController _searchController = TextEditingController();

  String? _salesCode;

  @override
  void initState() {
    super.initState();
    _applyFilter();
    _loadSalesCode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSalesCode() async {
    final salesCode = await StorageUtil.getSalesCode();
    setState(() {
      _salesCode = salesCode;
    });
  }

  void _applyFilter() async {
    setState(() {
      _isLoading = true;
    });
    final giftMembers_ = await widget.giftsRepository.getGiftMembers();

    setState(() {
      originalMembers = giftMembers_;
      _computeMarketingPersons();
      inactiveMembers = [];
      _isLoading = false;
    });
  }

  void _computeMarketingPersons() {
    final Map<String, List<Guest>> grouped = {};
    for (final guest in originalMembers) {
      final key = (guest.mGroup ?? '').isEmpty ? 'UNASSIGNED' : guest.mGroup!;
      grouped.putIfAbsent(key, () => []).add(guest);
    }
    _marketingPersons = Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length)),
    );
    _filteredMarketingPersons = _marketingPersons.entries.toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      if (_selectedMGroup == null) {
        if (value.isEmpty) {
          _filteredMarketingPersons = _marketingPersons.entries.toList();
        } else {
          _filteredMarketingPersons = _marketingPersons.entries.where((entry) {
            final gName = entry.value.isNotEmpty
                ? (entry.value.first.gName ?? '')
                : '';
            return gName.toLowerCase().contains(value.toLowerCase());
          }).toList();
        }
      } else {
        final groupGuests = _marketingPersons[_selectedMGroup] ?? [];
        if (value.isEmpty) {
          inactiveMembers = List<Guest>.from(groupGuests);
        } else {
          inactiveMembers = groupGuests.where((guest) {
            return guest.memberName.toLowerCase().contains(
                  value.toLowerCase(),
                ) ||
                guest.mid.toLowerCase().contains(value.toLowerCase());
          }).toList();
        }
      }
    });
  }

  void _selectMarketingPerson(String mGroupKey) {
    final groupGuests = _marketingPersons[mGroupKey] ?? [];
    _searchController.clear();
    setState(() {
      _selectedMGroup = mGroupKey;
      _selectedGName = groupGuests.isNotEmpty
          ? (groupGuests.first.gName ?? 'Unassigned')
          : 'Unassigned';
      inactiveMembers = List<Guest>.from(groupGuests);
    });
  }

  void _backToMarketingPersons() {
    _searchController.clear();
    setState(() {
      _selectedMGroup = null;
      _selectedGName = null;
      _filteredMarketingPersons = _marketingPersons.entries.toList();
    });
  }

  String _formatLastVisitDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '-';
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  Color _getRatingColor(String? rating) {
    switch ((rating ?? '').toUpperCase()) {
      case 'GOLD':
        return const Color(0xFFDAA520);
      case 'PLATINUM':
        return const Color(0xFF707070);
      case 'DIAMOND':
        return const Color(0xFF1565C0);
      case 'SILVER':
        return const Color(0xFF9E9E9E);
      case 'INFINITY':
        return const Color(0xFF4A148C);
      case 'PREMIER':
        return const Color(0xFF1B5E20);
      case 'RAFFELS CLUB':
        return const Color(0xFF880E4F);
      case 'CLASSIC':
        return const Color(0xFF5D4037);
      default:
        return const Color(0xFF5D4037);
    }
  }

  void _showAccessDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red),
            SizedBox(width: 10),
            Text('Access Denied'),
          ],
        ),
        content: const Text(
          'You do not have permission to view guest gifts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: _selectedMGroup != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _backToMarketingPersons,
              )
            : null,
        title: Text(_selectedMGroup != null ? (_selectedGName ?? 'Gifts') : 'Gifts'),
        actions: _selectedMGroup != null
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Center(
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          const Color.fromARGB(255, 152, 98, 6).withAlpha(90),
                      child: Text(
                        (_marketingPersons[_selectedMGroup]?.length ?? 0)
                            .toString(),
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: _selectedMGroup == null
                        ? 'Search marketing person'
                        : 'Search',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _selectedMGroup == null
                    ? (_filteredMarketingPersons.isEmpty
                        ? const Center(
                            child: Text("No marketing persons available"),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ListView.builder(
                              itemCount: _filteredMarketingPersons.length,
                              itemBuilder: (context, index) {
                                final entry = _filteredMarketingPersons[index];
                                final guests = entry.value;
                                final gName = guests.isNotEmpty
                                    ? (guests.first.gName ?? 'Unassigned')
                                    : 'Unassigned';
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 5.0,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  elevation: 2,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 8.0,
                                    ),
                                    title: Text(
                                      gName,
                                      style: TextStyle(
                                        fontSize: fontSettings.fontSize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    trailing: CircleAvatar(
                                      radius: 18,
                                      backgroundColor:
                                          const Color.fromARGB(255, 152, 98, 6)
                                              .withAlpha(90),
                                      child: Text(
                                        guests.length.toString(),
                                        style: TextStyle(
                                          fontSize: fontSettings.fontSize,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    onTap: () =>
                                        _selectMarketingPerson(entry.key),
                                  ),
                                );
                              },
                            ),
                          ))
                    : (inactiveMembers.isEmpty
                    ? const Center(child: Text("No gifts available"))
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
                                  onTap: () async {
                                    // Check sales code permission
                                    if (_salesCode != 'AD001') {
                                      _showAccessDeniedDialog();
                                      return;
                                    }

                                    // Show loading indicator
                                    setState(() {
                                      _isLoading = true;
                                    });

                                    try {
                                      // Set the selected guest first
                                      ref
                                          .read(selectedGuestProvider.notifier)
                                          .setSelectedGuest(guest);

                                      // Load the guest image and wait for it to complete
                                      await ref
                                          .read(selectedGuestProvider.notifier)
                                          .getGuestImage(9021, guest.mid);

                                      // Hide loading
                                      setState(() {
                                        _isLoading = false;
                                      });

                                      // Navigate to guest gifts screen
                                      if (mounted) {
                                        context.push(
                                          '/gifts/event-gifts/guest-gifts/${guest.mid}',
                                        );
                                      }
                                    } catch (e) {
                                      // Hide loading on error
                                      setState(() {
                                        _isLoading = false;
                                      });

                                      // Still navigate even if image loading fails
                                      if (mounted) {
                                        context.push(
                                          '/gifts/event-gifts/guest-gifts/${guest.mid}',
                                        );
                                      }
                                    }
                                  },
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 7.0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    elevation: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        left: 16.0,
                                        right: 16.0,
                                        top: 28.0,
                                        bottom: 16.0,
                                      ),
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
                                              const SizedBox(width: 8),
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor:
                                                    const Color.fromARGB(
                                                      255,
                                                      152,
                                                      98,
                                                      6,
                                                    ).withAlpha(90),
                                                child: Text(
                                                  "${guest.rc ?? 0}",
                                                  style: TextStyle(
                                                    fontSize:
                                                        fontSettings.fontSize,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                "Last Visit: ${_formatLastVisitDate(guest.lastVisitDate)}",
                                                style: TextStyle(
                                                  fontSize:
                                                      fontSettings.fontSize,
                                                  color: const Color.fromARGB(255, 2, 2, 2),
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
                                  right: 3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getRatingColor(guest.gRating),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.25),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      guest.gRating ?? 'N/A',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      )),
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
                      Constants.kSecondaryColor,
                    ),
                  ),
                ),
              ),
            ),
          const Watermark(),
        ],
      ),
    );
  }
}