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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Email Address'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,  // Increase width
        height: 90,                                     // Increase height
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              //controller: emailController,
             // keyboardType: TextInputType,
              decoration: const InputDecoration(
                hintText: 'Enter email address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final email = emailController.text.trim();
            if (email.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter an email address'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            if (!_isValidEmail(email)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a valid email address'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // widget.onEmailAdded?.call(email);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Email added: $email'),
                backgroundColor: Colors.green,
              ),
            );

            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
