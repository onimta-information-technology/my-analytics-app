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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Phone Number'),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SizedBox(
        height: 100,
        width: MediaQuery.of(context).size.width * 0.98, // 90% of screen width
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Row(
            children: [
              // Country Code Selector Button
              InkWell(
                onTap: _showCountryPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Text(
                        selectedCountry.flagEmoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+${selectedCountry.phoneCode}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Phone Number Input
              Expanded(
                child: TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: 'Phone number',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Preview of complete phone number
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Full number: +${selectedCountry.phoneCode} ${phoneController.text}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
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
          onPressed: () async {
            final phone = phoneController.text.trim();
            if (phone.isNotEmpty) {
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
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a phone number'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}