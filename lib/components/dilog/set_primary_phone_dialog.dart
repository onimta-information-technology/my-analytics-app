import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/providers/main_profile_details_provider.dart';
import 'package:ballys_reservation_app/providers/primary_contact_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SetPrimaryPhoneDialog extends ConsumerStatefulWidget {
  final String memberId;
  final List<String> availablePhones;

  const SetPrimaryPhoneDialog({
    Key? key,
    required this.memberId,
    required this.availablePhones,
  }) : super(key: key);

  @override
  ConsumerState<SetPrimaryPhoneDialog> createState() => _SetPrimaryPhoneDialogState();
}

class _SetPrimaryPhoneDialogState extends ConsumerState<SetPrimaryPhoneDialog> {
  String? selectedPhone;

  Future<void> _handleSubmit() async {
    if (selectedPhone == null || selectedPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a phone number'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final guest = ref.read(selectedGuestProvider);
    if (guest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guest information not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final success = await ref.read(primaryContactProvider.notifier).setPrimaryPhone(
            memberId: widget.memberId,
            phoneNumber: selectedPhone!,
            memberName: guest.memberName,
          );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (success) {
        // Refresh profile details to show updated primary
        await ref.read(mainProfileDetailsProvider.notifier).getMemberMainProfileDetails(guest.mid);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Primary phone set to: $selectedPhone'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to set primary phone: ${ref.read(primaryContactProvider).error ?? "Unknown error"}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double dialogWidth = screenWidth * 0.95;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.phone_android,
                  color: Constants.kPrimaryColor,
                  size: 28,
                ),
                SizedBox(width: 10),
                Text(
                  'Set Primary Phone',
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              'Select a phone number to set as primary:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 15),

            // Phone selection list
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: widget.availablePhones.map((phone) {
                  return RadioListTile<String>(
                    title: Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    value: phone,
                    groupValue: selectedPhone,
                    activeColor: Constants.kPrimaryColor,
                    onChanged: (value) {
                      setState(() {
                        selectedPhone = value;
                      });
                    },
                  );
                }).toList(),
              ),
            ),

            if (widget.availablePhones.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'No phone numbers available. Please add a phone number first.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: widget.availablePhones.isEmpty ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Constants.kPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Set Primary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}