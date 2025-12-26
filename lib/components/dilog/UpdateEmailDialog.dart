import 'package:flutter/material.dart';

class AddEmailDialog extends StatefulWidget {
  final String memberId;
  final String? currentEmail;
  final Function(String)? onEmailAdded;

  const AddEmailDialog({
    Key? key,
    required this.memberId,
    this.currentEmail,
    this.onEmailAdded,
  }) : super(key: key);

  @override
  State<AddEmailDialog> createState() => _AddEmailDialogState();
}

class _AddEmailDialogState extends State<AddEmailDialog> {
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

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      final email = emailController.text.trim();

      // TODO: Add API call to save email
      // await ref.read(yourProvider.notifier).updateEmail(widget.memberId, email);

      if (widget.onEmailAdded != null) {
        widget.onEmailAdded!(email);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Email updated: $email'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double dialogWidth = screenWidth * 0.95; // Increased from 0.99 to 0.95 for better margins

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 10), // Reduced from default
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(20.0), // Increased from 16.0 to 20.0
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Email Address',
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Email Input
              TextFormField(
               // controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                decoration: InputDecoration(
                  labelText: 'Email Address *',
                  labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                  hintText: 'Enter email address',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.email),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
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
                            ? 'Email will be Add for member ${widget.memberId}'
                            : 'Add email to: ${emailController.text}',
                        style: TextStyle(
                          fontSize: 13,
                          color: emailController.text.isEmpty
                              ? Colors.grey.shade500
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.w400,
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
                      foregroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 16),
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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