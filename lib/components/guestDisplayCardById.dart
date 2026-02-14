import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:intl/intl.dart';

class GuestDisplayCardById extends ConsumerStatefulWidget {
  final String memberId;
  final bool showLastVisitDate;
  final VoidCallback? onImageTap;

  const GuestDisplayCardById({
    super.key,
    required this.memberId,
    this.showLastVisitDate = false,
    this.onImageTap,
  });

  @override
  ConsumerState<GuestDisplayCardById> createState() => _GuestDisplayCardByIdState();
}

class _GuestDisplayCardByIdState extends ConsumerState<GuestDisplayCardById> {
  bool _isLoading = false;
  Guest? _localGuestData;
  String? _errorMessage;
  String? _lastFetchedMemberId;

  static const Map<String, String> ratingImageMap = {
    "CLASSIC": "assets/images/ratings/CLASSIC.png",
    "DIAMOND": "assets/images/ratings/DIAMOND.png",
    "GOLD": "assets/images/ratings/GOLD.png",
    "INFINITY": "assets/images/ratings/INFINITY.png",
    "PLATINUM": "assets/images/ratings/PLATINUM.png",
    "SILVER": "assets/images/ratings/SILVER.png",
  };

  @override
  void initState() {
    super.initState();
    if (widget.memberId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchGuestData();
      });
    }
  }

  @override
  void didUpdateWidget(GuestDisplayCardById oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.memberId != oldWidget.memberId && widget.memberId.isNotEmpty) {
      _fetchGuestData();
    }
  }

  Future<void> _fetchGuestData() async {
  if (widget.memberId.isEmpty) return;
  
  if (_lastFetchedMemberId == widget.memberId && _localGuestData != null) {
    return;
  }

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    print('Fetching guest data for Member ID: ${widget.memberId}');
    
    // Fetch basic guest data
    await ref.read(selectedGuestProvider.notifier).setSelectedGuestWithId(widget.memberId);
    
    // Fetch guest image
    await ref.read(selectedGuestProvider.notifier).getGuestImage(9022, widget.memberId);
    
    // Wait a bit for the state to update
    await Future.delayed(const Duration(milliseconds: 100));
    
    final guest = ref.read(selectedGuestProvider);
    
    print('Guest data received: ${guest?.mid}');
    print('Guest name: ${guest?.memberName}');
    print('Has image: ${guest?.memImage2 != null}');
    print('Guest last visit: ${guest?.lastVisitDate}');

    if (guest != null) {
      setState(() {
        _localGuestData = guest;
        _lastFetchedMemberId = widget.memberId;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = "Guest not found";
        _isLoading = false;
      });
    }
  } catch (e, stackTrace) {
    print('Error fetching guest data: $e');
    print('Stack trace: $stackTrace');
    setState(() {
      _errorMessage = "Failed to load guest data";
      _isLoading = false;
    });
  }
}

  Widget _buildPlaceholderAvatar() {
    return Container(
      color: Colors.grey.shade300,
      child: Icon(Icons.person, size: 40, color: Colors.grey.shade600),
    );
  }

  Color _getRatingColor(String rating) {
    switch (rating.toLowerCase()) {
      case 'vip':
      case 'classic':
        return const Color.fromARGB(255, 170, 41, 36);
      case 'gold':
        return Colors.amber.shade600;
      case 'silver':
        return Colors.grey.shade600;
      case 'infinity':
        return Colors.brown.shade600;
      case 'diamond':
        return Colors.blue.shade600;
      default:
        return Colors.green.shade600;
    }
  }
String _formatLastVisitDate(String? dateString) {
  if (dateString == null || dateString.isEmpty) return "N/A";
  try {
    final date = DateTime.parse(dateString);
    // Check if date is Unix epoch (1970-01-01) - treat as N/A
    if (date.year == 1970 && date.month == 1 && date.day == 1) {
      return "N/A";
    }
    return DateFormat('yyyy-MM-dd').format(date);
  } catch (_) {
    return dateString;
  }
}

  void _showFullScreenImage(BuildContext context, Guest guest) {
    if (guest.memImage2 == null || guest.memImage2!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No image available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Close",
      barrierColor: Colors.black87,
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                base64Decode(guest.memImage2!),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    width: 200,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.error, size: 50, color: Colors.red),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.memberId.isEmpty) {
      return const SizedBox.shrink();
    }

    final fontSettings = ref.watch(fontSettingsProvider);
    final guestData = _localGuestData;

    return Column(
      children: [
        const SizedBox(height: 10.0),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 30.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Loading guest details...",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade400,
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade600,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _fetchGuestData,
                              icon: const Icon(Icons.refresh),
                              label: const Text("Retry"),
                            ),
                          ],
                        ),
                      ),
                    )
                  : guestData == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                            child: Text(
                              "No guest data available",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // FIRST ROW: Profile Picture + Member Details
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Profile Picture (Left)
                                GestureDetector(
                                  onTap: () {
                                    if (guestData != null) {
                                      if (widget.onImageTap != null) {
                                        widget.onImageTap!();
                                      } else {
                                        _showFullScreenImage(context, guestData);
                                      }
                                    }
                                  },
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color.fromARGB(255, 59, 50, 50),
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: guestData.memImage2 != null &&
                                              guestData.memImage2!.isNotEmpty
                                          ? Image.memory(
                                              base64Decode(guestData.memImage2!),
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return _buildPlaceholderAvatar();
                                              },
                                            )
                                          : _buildPlaceholderAvatar(),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 16),

                                // Member Details (Right side of first row)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Member ID
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 6.0),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.badge,
                                              size: 20,
                                              color: Color.fromARGB(255, 0, 0, 0),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              "ID: ${guestData.mid}",
                                              style: TextStyle(
                                                fontSize: fontSettings.fontSize * 0.9,
                                                fontWeight: FontWeight.bold,
                                                color: const Color.fromARGB(255, 0, 0, 0),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Member Name
                                      if (guestData.memberName != null &&
                                          guestData.memberName!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 6.0),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.person,
                                                size: 20,
                                                color: Color.fromARGB(255, 0, 0, 0),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  guestData.memberName!,
                                                  style: TextStyle(
                                                    fontSize: fontSettings.fontSize * 0.9,
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color.fromARGB(255, 0, 0, 0),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 2,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // SECOND ROW: Additional Information (Left Aligned)
                            const SizedBox(height: 12),

                            // Guest Name (M P - Member Principal)
                            if (guestData.gName != null &&
                                guestData.gName!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.supervisor_account,
                                      size: 16,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        "M P: ${guestData.gName!}",
                                        style: TextStyle(
                                          fontSize: fontSettings.fontSize * 0.95,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Last Visit Date and Rating Image in same row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Last Visit Date (Left)
                                if (widget.showLastVisitDate)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 14,
                                        color: Color.fromARGB(255, 0, 0, 0),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Last Visit On: ${_formatLastVisitDate(guestData.lastVisitDate)}",
                                        style: TextStyle(
                                          fontSize: fontSettings.fontSize * 0.85,
                                          fontWeight: fontSettings.fontWeight,
                                          color: const Color.fromARGB(255, 0, 0, 0),
                                        ),
                                      ),
                                    ],
                                  ),

                                // Rating Image (Right)
                                Builder(
                                  builder: (context) {
                                    String ratingToUse = "CLASSIC";
                                    if (guestData.gRating != null &&
                                        guestData.gRating!.isNotEmpty &&
                                        ratingImageMap.containsKey(
                                          guestData.gRating!.toUpperCase(),
                                        )) {
                                      ratingToUse = guestData.gRating!.toUpperCase();
                                    }

                                    return Container(
                                      width: 80,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.asset(
                                          ratingImageMap[ratingToUse]!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey.shade200,
                                              child: Icon(
                                                Icons.star,
                                                color: _getRatingColor(ratingToUse),
                                                size: 16,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
        ),
      ],
    );
  }
}