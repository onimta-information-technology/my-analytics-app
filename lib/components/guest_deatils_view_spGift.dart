import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:intl/intl.dart';

class GuestDisplayCardSpecialGiftview extends ConsumerWidget {
  final String memberIdText;
  final String memberNameText;
  final bool showCard;
  final bool isLoading;
  final VoidCallback? onImageTap;
  final bool showLastVisitDate;

  const GuestDisplayCardSpecialGiftview({
    super.key,
    required this.memberIdText,
    required this.memberNameText,
    required this.showCard,
    this.isLoading = false,
    this.onImageTap,
    this.showLastVisitDate = false,
  });

  Widget _buildPlaceholderAvatar() {
    return Container(
      color: Colors.grey.shade300,
      child: Icon(Icons.person, size: 40, color: Colors.grey.shade600),
    );
  }

  Color _getRatingColor(String rating) {
    switch (rating.toUpperCase()) {
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
        return Colors.grey;
    }
  }

  String _formatLastVisitDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      return dateString;
    }
  }

  void _showFullScreenImage(BuildContext context, Guest selectedGuest) {
    if (selectedGuest.memImage2 == null || selectedGuest.memImage2!.isEmpty) {
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
                base64Decode(selectedGuest.memImage2!),
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
  Widget build(BuildContext context, WidgetRef ref) {
    if (!showCard) {
      return const SizedBox.shrink();
    }

    final fontSettings = ref.watch(fontSettingsProvider);

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
          child: isLoading
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
                            final selectedGuest = ref.read(selectedGuestProvider);
                            if (selectedGuest != null) {
                              if (onImageTap != null) {
                                onImageTap!();
                              } else {
                                _showFullScreenImage(context, selectedGuest);
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
                              child: Consumer(
                                builder: (context, ref, child) {
                                  final selectedGuest = ref.watch(
                                    selectedGuestProvider,
                                  );

                                  if (selectedGuest?.memImage2 != null &&
                                      selectedGuest!.memImage2!.isNotEmpty) {
                                    try {
                                      return Image.memory(
                                        base64Decode(selectedGuest.memImage2!),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return _buildPlaceholderAvatar();
                                        },
                                      );
                                    } catch (e) {
                                      return _buildPlaceholderAvatar();
                                    }
                                  }
                                  return _buildPlaceholderAvatar();
                                },
                              ),
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
                              if (memberIdText.isNotEmpty)
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
                                        "ID: $memberIdText",
                                        style: TextStyle(
                                          fontSize: fontSettings.fontSize,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              const Color.fromARGB(255, 0, 0, 0),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Member Name
                              if (memberNameText.isNotEmpty)
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
                                          memberNameText,
                                          style: TextStyle(
                                            fontSize: fontSettings.fontSize,
                                            fontWeight: FontWeight.bold,
                                            color: const Color.fromARGB(
                                                255, 0, 0, 0),
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

                    // SECOND ROW: Additional Information
                    const SizedBox(height: 12),

                    // Guest Name (M P - Member Principal)
                    Consumer(
                      builder: (context, ref, child) {
                        final selectedGuest = ref.watch(selectedGuestProvider);

                        if (selectedGuest?.gName != null &&
                            selectedGuest!.gName!.isNotEmpty) {
                          return Padding(
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
                                    "M P: ${selectedGuest.gName!}",
                                    style: TextStyle(
                                      fontSize: fontSettings.fontSize + 1,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                    // Last Visit Date and Rating Badge in same row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Last Visit Date (Left)
                        if (showLastVisitDate)
                          Consumer(
                            builder: (context, ref, child) {
                              final selectedGuest =
                                  ref.watch(selectedGuestProvider);

                              return Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: Color.fromARGB(255, 0, 0, 0),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Last Visit On: ${_formatLastVisitDate(selectedGuest?.lastVisitDate)}",
                                    style: TextStyle(
                                      fontSize: fontSettings.fontSize + 1,
                                      fontWeight: fontSettings.fontWeight,
                                      color:
                                          const Color.fromARGB(255, 0, 0, 0),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                        // Rating Badge (Right)
                        Consumer(
                          builder: (context, ref, child) {
                            final selectedGuest =
                                ref.watch(selectedGuestProvider);

                            final ratingToUse =
                                (selectedGuest?.gRating ?? 'N/A').toUpperCase();

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getRatingColor(ratingToUse),
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
                                ratingToUse,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
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