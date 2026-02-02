import 'package:ballys_reservation_app/components/guest_deatils_view_spGift.dart';
import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/gift/birthday_gift_request.dart';
import 'package:ballys_reservation_app/models/gift/special_gift_request.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/providers/BirthdayGiftIncreesNotifier.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/birthday_gift_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/providers/special_gift_provider.dart';
import 'package:ballys_reservation_app/utils/formatter.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ViewBirthdayGiftRequest extends ConsumerStatefulWidget {
  final GiftsRepository giftsRepository;
  final BirthdayIncressGiftRequest? gift;
  final bool isPending;
  final bool isApproved;
  
  const ViewBirthdayGiftRequest({
    super.key,
    required this.giftsRepository,
    this.gift,
    this.isPending = false,
    this.isApproved = false,
  });

  @override
  ConsumerState<ViewBirthdayGiftRequest> createState() =>
      _ViewBirthdayGiftRequestState();
}

class _ViewBirthdayGiftRequestState extends ConsumerState<ViewBirthdayGiftRequest> {
  final TextEditingController _memberIdController = TextEditingController();
  final TextEditingController _memberNameController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  final TextEditingController _arrivalDateController = TextEditingController();
  final TextEditingController _departureDateController = TextEditingController();
  final TextEditingController _chipController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _previousGiftAmountController = TextEditingController();

  String? _selectedGift;
  String? _chipType;
  String _remarks = "";
  String? userName = "";
  double drop = 0.0;
  double cashout = 0.0;
  double res = 0.0;
  double actdrop = 0.0;
  double mcoupen = 0.0;
  double paidcom = 0.0;
  double gpoints = 0.0;
  double gflushcoupen = 0.0;
  double tcoupon = 0.0;
  double flushactdrop = 0.0;
  double avgbet = 0.0;
  int? _selectedValidDays;
bool _hasGiftAppPermission = false;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditable = false;

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
 _checkGiftAppPermission();

    if (widget.gift != null) {
      final g = widget.gift!;
      _memberIdController.text = g.mid ?? "";
      _memberNameController.text = g.mname ?? "";
      _fromDateController.text = _formatDateandTime(g.dateFrom) ?? "";
      _toDateController.text = _formatDateandTime(g.dateTo);
      _arrivalDateController.text = _formatDate(g.arrDate);
      _departureDateController.text = _formatDate(g.dptDate);
      _selectedGift = "BIRTHDAY_GIFT";
      _chipController.text = g.chipType.replaceAll("_", " ");
      _amountController.text = formatNumber(g.giftDesc.toString()) ?? "";
      _remarksController.text = g.giftCategory ?? "";
      _previousGiftAmountController.text = g.prvGiftAmount ?? "0";
      
      drop = g.mdrop;
      cashout = g.cashout;
      res = g.res;
      actdrop = g.actDrop;
      mcoupen = g.mCoupon;
      paidcom = g.paidComm;
      gpoints = g.gPoints;
      gflushcoupen = g.flushCoupon;
      tcoupon = g.mCoupon + g.flushCoupon;
      flushactdrop = g.flushActDrop;
      avgbet = g.avebet;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadGuestDataForCard();
      });
    }
  }
Future<void> _checkGiftAppPermission() async {
    final giftApp = await StorageUtil.getGiftApp();
    setState(() {
      _hasGiftAppPermission = giftApp ?? false;
    });
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
          'You do not have permission to Approve, Reject, or Reverse gift requests.'
          // 'Only users with gift approval permission can perform these actions.',
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
  Future<void> _loadGuestDataForCard() async {
    if (_memberIdController.text.isEmpty) return;

    try {
      setState(() {
        _isLoading = true;
      });

      GuestRepository guestRepository = GuestRepository(
        ApiService(const FlutterSecureStorage()),
      );

      List<GuestSearchResponse> guests = await guestRepository.searchGuest(
        9021,
        _memberIdController.text,
      );

      if (guests.isNotEmpty) {
        final guestResponse = guests.first;
        ref.read(selectedGuestProvider.notifier).setSelectedGuest(
          Guest(
            mid: guestResponse.mid ?? _memberIdController.text,
            memberName: guestResponse.mName ?? _memberNameController.text,
            country: "",
            lastVisitDate: guestResponse.lvd?.toString() ?? "",
            age: 0,
            gRating: guestResponse.gRating ?? "",
            mGroup: guestResponse.mGroup,
            gName: guestResponse.gName ?? "",
            memImage2: guestResponse.memImage2,
          ),
        );
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading guest data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserCredentials() async {
    final name = await StorageUtil.getUserName();
    setState(() {
      userName = name;
    });
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      return dateString;
    }
  }

  String _formatDateandTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd HH:mm a').format(date);
    } catch (_) {
      return dateString;
    }
  }

  String formatNumber(dynamic value) {
    if (value == null) return "";
    final num? number = num.tryParse(value.toString());
    if (number == null) return value.toString();
    return NumberFormat.decimalPattern().format(number);
  }

  TextStyle _inputTextStyle(FontSettings fontSettings) {
    return TextStyle(
      fontSize: fontSettings.fontSize,
      fontWeight: fontSettings.fontWeight,
    );
  }

  TextStyle _inputTextStyleForAmount(FontSettings fontSettings) {
    return TextStyle(
      fontSize: fontSettings.fontSize + 5,
      fontWeight: FontWeight.bold,
      color: const Color.fromARGB(255, 255, 0, 0)
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/menu');
            }
          },
        ),
        title: Text(
          'Birthday Gift Request',
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: fontSettings.fontWeight,
          ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (widget.isApproved)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (!_hasGiftAppPermission) {
                              _showAccessDeniedDialog();
                              return;
                            }
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Reverse Gift'),
                                content: const Text(
                                  'Are you sure you want to reverse this birthday gift?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Reverse'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed != true) return;

                            setState(() {
                              _isLoading = true;
                            });

                            try {
                              final success = await ref
                                  .read(birthdayGiftIncreesProvider.notifier)
                                  .reverseBirthdayGiftFromUI(
                                    reqid: widget.gift!.idNo,
                                    userName: userName ?? "",
                                  );

                              setState(() {
                                _isLoading = false;
                              });

                              if (!mounted) return;

                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Birthday gift reversed successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.of(context).pop(true);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to reverse birthday gift'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } catch (e) {
                              setState(() {
                                _isLoading = false;
                              });

                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.undo, size: 20),
                          label: Text(
                            'Reverse Gift',
                            style: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    
                    if (!widget.isApproved && !widget.isPending)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (!_hasGiftAppPermission) {
                              _showAccessDeniedDialog();
                              return;
                            }
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Reverse Gift'),
                                content: const Text(
                                  'Are you sure you want to reverse this rejected birthday gift?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Reverse'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed != true) return;

                            setState(() {
                              _isLoading = true;
                            });

                            try {
                              final success = await ref
                                  .read(birthdayGiftIncreesProvider.notifier)
                                  .reverseBirthdayGiftFromUIRejected(
                                    reqid: widget.gift!.idNo,
                                    userName: userName ?? "",
                                  );

                              setState(() {
                                _isLoading = false;
                              });

                              if (!mounted) return;

                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Birthday gift reversed successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.of(context).pop(true);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to reverse birthday gift'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } catch (e) {
                              setState(() {
                                _isLoading = false;
                              });

                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.undo, size: 20),
                          label: Text(
                            'Reverse Gift',
                            style: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 5.0),
                    TextFormField(
                      controller: _fromDateController,
                      readOnly: true,
                      style: _inputTextStyle(fontSettings),
                      decoration: InputDecoration(
                        labelText: "From Date & Time",
                        labelStyle: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: -5.0,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _toDateController,
                      readOnly: true,
                      style: _inputTextStyle(fontSettings),
                      decoration: InputDecoration(
                        labelText: "To Date & Time",
                        labelStyle: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: -5.0,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 5.0),
                    GuestDisplayCardSpecialGiftview(
                      memberIdText: _memberIdController.text,
                      memberNameText: _memberNameController.text,
                      showCard: _memberIdController.text.isNotEmpty &&
                          _memberNameController.text.isNotEmpty,
                      isLoading: _isLoading,
                      showLastVisitDate: true,
                    ),
                    
                    const SizedBox(height: 16.0),
                    Row(
                      children: [
                        // In ViewBirthdayGiftRequest, replace the profile navigation button code:
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.black,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 14,
    ),
  ),
  onPressed: _isLoading
      ? null
      : () async {
          final selectedGuest = ref.read(selectedGuestProvider);

          if (selectedGuest != null &&
              selectedGuest.mid == _memberIdController.text) {
            // ✅ Navigate to profile
            context.push('/home/profile');
            return;
          }

          try {
            setState(() {
              _isLoading = true;
            });

            GuestRepository guestRepository = GuestRepository(
              ApiService(const FlutterSecureStorage()),
            );

            List<GuestSearchResponse> guests =
                await guestRepository.searchGuest(
                  9021,
                  _memberIdController.text,
                );

            setState(() {
              _isLoading = false;
            });

            if (guests.isNotEmpty) {
              final guestResponse = guests.first;
              ref
                  .read(selectedGuestProvider.notifier)
                  .setSelectedGuest(
                    Guest(
                      mid: guestResponse.mid ?? _memberIdController.text,
                      memberName: guestResponse.mName ?? _memberNameController.text,
                      country: "",
                      lastVisitDate: guestResponse.lvd?.toString() ?? "",
                      age: 0,
                      gRating: guestResponse.gRating ?? "",
                      mGroup: guestResponse.mGroup,
                      gName: guestResponse.gName ?? "",
                      memImage2: guestResponse.memImage2,
                    ),
                  );
              context.push('/home/profile');
            }
          } catch (e) {
            setState(() {
              _isLoading = false;
            });
          }
        },
  child: _isLoading
      ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
      : const Icon(Icons.person_search, size: 25),
),
                         const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final memberId = _memberIdController.text
                                    .trim();

                                if (memberId.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Please enter a Member ID"),
                                    ),
                                  );
                                  return;
                                }

                                context.push(
                                  '/menu/approve-reject/birthday-gifts/prv-gifts/$memberId',
                                );
                              },
                              icon: const Icon(Icons.card_giftcard),
                              label: Text(
                                "Previous Gift",
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize,
                                  fontWeight: fontSettings.fontWeight,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        "Guest Gift Data",
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    Builder(
                      builder: (context) {
                        final rows = [
                          {"Field": "Drop (Est)", "Value": drop},
                          {"Field": "Cash Out (Est)", "Value": cashout},
                          {"Field": "Result (Est)", "Value": res},
                          {"Field": "Actual Drop (Est)", "Value": actdrop},
                          {"Field": "Coupons (Est)", "Value": mcoupen},
                          {"Field": "Commission Paid (Est)", "Value": paidcom},
                          {"Field": "Points (Est)", "Value": gpoints},
                          {"Field": "Flush Coupon (Est)", "Value": gflushcoupen},
                          {"Field": "Total Coupon (Est)", "Value": tcoupon},
                          {"Field": "Flush Actual Drop (Est)", "Value": flushactdrop},
                          {"Field": "Avg Bet (Est)", "Value": avgbet},
                        ];

                        return Container(
                          margin: const EdgeInsets.only(top: 5),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: DataTable(
                            dataRowMinHeight: 48,
                            dataRowMaxHeight: 56,
                            headingRowColor: WidgetStateProperty.all(
                              Colors.amber.shade100,
                            ),
                            border: TableBorder.all(color: Colors.grey.shade300),
                            columns: [
                              DataColumn(
                                label: Text(
                                  "Field",
                                  style: TextStyle(
                                    fontSize: fontSettings.fontSize,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Value",
                                  style: TextStyle(
                                    fontSize: fontSettings.fontSize,
                                    fontWeight: fontSettings.fontWeight,
                                  ),
                                ),
                              ),
                            ],
                            rows: rows.map((row) {
                              final shouldHighlight = [
                                "Actual Drop (Est)",
                                "Result (Est)",
                                "Coupons (Est)",
                                "Points (Est)",
                                "Avg Bet (Est)",
                              ].contains(row["Field"]);
                              return DataRow(
                                color: shouldHighlight
                                    ? WidgetStateProperty.all(Color(0xFFCCFFCC))
                                    : null,
                                cells: [
                                  DataCell(
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        row["Field"].toString(),
                                        style: TextStyle(
                                          fontSize: fontSettings.fontSize,
                                          fontWeight: shouldHighlight
                                              ? FontWeight.bold
                                              : fontSettings.fontWeight,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        formatNumber(row["Value"]),
                                        style: TextStyle(
                                          fontSize: fontSettings.fontSize,
                                          fontWeight: shouldHighlight
                                              ? FontWeight.bold
                                              : fontSettings.fontWeight,
                                          fontFamily: 'monospace',
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16.0),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _arrivalDateController,
                            readOnly: true,
                            style: _inputTextStyle(fontSettings),
                            decoration: InputDecoration(
                              labelText: "Arrival Date",
                              labelStyle: TextStyle(
                                fontSize: fontSettings.fontSize,
                                fontWeight: fontSettings.fontWeight,
                              ),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: -5.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _departureDateController,
                            readOnly: true,
                            style: _inputTextStyle(fontSettings),
                            decoration: InputDecoration(
                              labelText: "Departure Date",
                              labelStyle: TextStyle(
                                fontSize: fontSettings.fontSize,
                                fontWeight: fontSettings.fontWeight,
                              ),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: -5.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      readOnly: true,
                      controller: TextEditingController(text: "Birthday Gift"),
                      decoration: InputDecoration(
                        labelText: "Gift For",
                        labelStyle: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: -5.0,
                        ),
                      ),
                      style: _inputTextStyle(fontSettings),
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _chipController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: "Chip Type",
                        labelStyle: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: -5.0,
                        ),
                      ),
                      style: _inputTextStyle(fontSettings),
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _previousGiftAmountController,
                      readOnly: true,
                      style: _inputTextStyleForAmount(fontSettings),
                      decoration: InputDecoration(
                        labelText: "Previous Gift Amount",
                        labelStyle: TextStyle(
                          color: const Color.fromARGB(255, 255, 0, 0),
                          fontSize: fontSettings.fontSize + 2,
                          fontWeight: fontSettings.fontWeight,
                        ),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: -5.0,
                        ),
                      ),
                    ),

                    if (widget.isPending)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Amount & Remarks",
                            style: TextStyle(
                              fontSize: fontSettings.fontSize + 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              setState(() {
                                _isEditable = !_isEditable;
                              });
                            },
                          ),
                        ],
                      ),

                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _amountController,
                      readOnly: !_isEditable,
                      style: _inputTextStyleForAmount(fontSettings),
                      decoration: InputDecoration(
                        labelText: "Increase gift Amount",
                        labelStyle: TextStyle(
                          fontSize: fontSettings.fontSize + 2,
                          fontWeight: fontSettings.fontWeight,
                        ),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: -5.0,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        ThousandsSeparatorInputFormatter(),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter amount";
                        }
                        return null;
                      },
                    ),

                    if (widget.isPending) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: _selectedValidDays,
                        style: TextStyle(
                          fontSize: fontSettings.fontSize + 2,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          labelText: "Valid Days",
                          labelStyle: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 30,
                            child: Text(
                              "30 Days",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 60,
                            child: Text(
                              "60 Days",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 90,
                            child: Text(
                              "90 Days",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedValidDays = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return "Please select valid days";
                          }
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _remarksController,
                      readOnly: !_isEditable,
                      style: _inputTextStyle(fontSettings),
                      decoration: InputDecoration(
                        alignLabelWithHint: true,
                        labelText: "Remarks",
                        labelStyle: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                        hintText: "Enter additional details...",
                        hintStyle: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: fontSettings.fontWeight,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      onChanged: (value) => _remarks = value,
                    ),

                    const SizedBox(height: 16.0),
                    if (widget.isPending)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                if (!_hasGiftAppPermission) {
                                  _showAccessDeniedDialog();
                                  return;
                                }
                                if (widget.gift == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Gift request not found"),
                                    ),
                                  );
                                  return;
                                }

                                if (_selectedValidDays == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Please select valid days"),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                final reqid = widget.gift!.idNo;
                                final remarks = _remarksController.text;
                                final amount = _amountController.text;
                                final uname = userName ?? "";

                                setState(() {
                                  _isLoading = true;
                                });

                                try {
                                  final success = await ref
                                      .read(birthdayGiftIncreesProvider.notifier)
                                      .sendApprovedBirthdayGiftFromUI(
                                        reqid: reqid,
                                        remarks: remarks,
                                        amount: amount,
                                        userName: uname,
                                        validDates: _selectedValidDays.toString(),
                                      );

                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Request Approved Successfully"),
                                      ),
                                    );
                                    Navigator.of(context).pop(true);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Approval Failed"),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Error: $e")),
                                  );
                                } finally {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                }
                              },
                              icon: const Icon(Icons.check),
                              label: const Text("APPROVE"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                 if (!_hasGiftAppPermission) {
                                  _showAccessDeniedDialog();
                                  return;
                                }
                                if (widget.gift == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Gift request not found"),
                                    ),
                                  );
                                  return;
                                }

                                final reqid = widget.gift!.idNo;
                                final uname = userName ?? "";

                                setState(() {
                                  _isLoading = true;
                                });

                                try {
                                  final success = await ref
                                      .read(birthdayGiftIncreesProvider.notifier)
                                      .rejectBirthdayGiftFromUI(
                                        reqid: reqid,
                                        userName: uname,
                                      );

                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Request Rejected Successfully"),
                                      ),
                                    );
                                    Navigator.of(context).pop(true);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Rejection Failed"),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Error: $e")),
                                  );
                                } finally {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                }
                              },
                              icon: const Icon(Icons.close),
                              label: const Text("REJECT"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
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