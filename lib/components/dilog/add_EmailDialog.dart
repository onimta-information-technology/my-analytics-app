import 'package:ballys_reservation_app/providers/email_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/providers/main_profile_details_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddEmailDialog extends ConsumerStatefulWidget {
  final String memberId;
  final int emailType; // 1 for Email1, 2 for Email2
  final String? currentEmail;
  final Function(String)? onEmailAdded;

  const AddEmailDialog({
    Key? key,
    required this.memberId,
    required this.emailType,
    this.currentEmail,
    this.onEmailAdded,
  }) : super(key: key);

  @override
  ConsumerState<AddEmailDialog> createState() => _AddEmailDialogState();
}

class _AddEmailDialogState extends ConsumerState<AddEmailDialog> {
  final TextEditingController emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    emailController.text = widget.currentEmail ?? '';
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      final email = emailController.text.trim();

      // Get guest information
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
        // Call API to add/update email
        final success = await ref.read(emailProvider.notifier).addOrUpdateEmail(
              memberId: widget.memberId,
              email: email,
              memberName: guest.memberName,
              emailType: widget.emailType,
            );

        // Close loading dialog
        if (mounted) Navigator.pop(context);

        if (success) {
          final emailResponse = ref.read(emailProvider).emailResponse;
          final addedEmail = emailResponse?.email ?? email;
          final emailFieldName = emailResponse?.emailFieldName ?? 'email${widget.emailType}';
          
          // Update the profile details in provider with the new email
          ref.read(mainProfileDetailsProvider.notifier)
              .updateEmail(addedEmail, emailFieldName);
          
          if (widget.onEmailAdded != null) {
            widget.onEmailAdded!(addedEmail);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Email updated: $addedEmail'),
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
                  'Failed to update email: ${ref.read(emailProvider).error ?? "Unknown error"}',
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
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double dialogWidth = screenWidth * 0.95;
    
    // Determine the title based on emailType
    String title = 'Add/Update Email ${widget.emailType}';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Email Input
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Email Address *',
                  labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  hintText: 'Enter email address',
                  hintStyle: TextStyle(color: const Color.fromARGB(255, 0, 0, 0)),
                  prefixIcon: const Icon(Icons.email),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 14.0,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email address is required';
                  }
                  if (!_isValidEmail(value.trim())) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),

              // Email Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        emailController.text.isEmpty
                            ? 'Email will be added for member ${widget.memberId}'
                            : 'Email to add: ${emailController.text}',
                        style: TextStyle(
                          fontSize: 15,
                          color: emailController.text.isEmpty
                              ? const Color.fromARGB(255, 0, 0, 0)
                              : const Color.fromARGB(255, 0, 0, 0),
                          fontWeight: FontWeight.bold,
                        ),
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
                      foregroundColor: const Color.fromARGB(255, 0, 0, 0),
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
                    onPressed: _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 114, 6, 100),
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
                      'Add',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}