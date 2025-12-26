import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';

class AddPhoneDialog extends StatefulWidget {
  final String memberId;
  final Function(String)? onPhoneAdded;

  const AddPhoneDialog({
    Key? key,
    required this.memberId,
    this.onPhoneAdded,
  }) : super(key: key);

  @override
  State<AddPhoneDialog> createState() => _AddPhoneDialogState();
}

class _AddPhoneDialogState extends State<AddPhoneDialog> {
  final TextEditingController phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Country selectedCountry = Country(
    phoneCode: "1",
    countryCode: "US",
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: "United States",
    example: "2012345678",
    displayName: "United States (US) [+1]",
    displayNameNoCountryCode: "United States (US)",
    e164Key: "",
  );

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      onSelect: (Country country) {
        setState(() {
          selectedCountry = country;
        });
      },
      countryListTheme: CountryListThemeData(
        borderRadius: BorderRadius.circular(8),
        inputDecoration: InputDecoration(
          labelText: 'Search',
          hintText: 'Start typing to search',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      final phone = phoneController.text.trim();
      final fullPhoneNumber = '+${selectedCountry.phoneCode}$phone';

      // TODO: Add API call to save new phone number
      // await ref.read(yourProvider.notifier).addPhoneNumber(widget.memberId, fullPhoneNumber);

      if (widget.onPhoneAdded != null) {
        widget.onPhoneAdded!(fullPhoneNumber);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Phone number added: $fullPhoneNumber'),
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
        padding: const EdgeInsets.all(15.0), // Increased from 10.0 to 20.0
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add New Phone Number',
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Country Selector and Phone Input in one row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Country Selector
                   GestureDetector(
                    onTap: _showCountryPicker,
                    child: Container(
                      width: 60,
                      height: 56, // Match TextFormField height (14 vertical padding * 2 + content)
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            selectedCountry.flagEmoji,
                            style: const TextStyle(fontSize: 10),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+${selectedCountry.phoneCode}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  
                  // Phone Input
                  Expanded(
                    child: TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                      decoration: InputDecoration(
                        labelText: 'Phone Number *',
                        labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                        hintText: 'Enter phone number',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Phone number is required';
                        }
                        if (value.trim().length < 5) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {}); // Update full number preview
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Full Number Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        phoneController.text.isEmpty
                            ? 'Full number will appear here'
                            : 'Full number: +${selectedCountry.phoneCode} ${phoneController.text}',
                        style: TextStyle(
                          fontSize: 13,
                          color: phoneController.text.isEmpty
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