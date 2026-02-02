import 'package:ballys_reservation_app/providers/phone_provider.dart';
import 'package:ballys_reservation_app/providers/selected_guest_provider.dart';
import 'package:ballys_reservation_app/providers/main_profile_details_provider.dart';
import 'package:ballys_reservation_app/providers/whatsapp_provider.dart';
import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddwhatsappPhoneDialog extends ConsumerStatefulWidget {
  final String memberId;
  final int phoneType;
  final String? currentPhone;
  final Function(String)? onPhoneAdded;

  const AddwhatsappPhoneDialog({
    Key? key,
    required this.memberId,
    required this.phoneType,
    this.currentPhone,
    this.onPhoneAdded,
  }) : super(key: key);

  @override
  ConsumerState<AddwhatsappPhoneDialog> createState() => _AddwhatsappPhoneDialogState();
}

class _AddwhatsappPhoneDialogState extends ConsumerState<AddwhatsappPhoneDialog> {
  final TextEditingController phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Country selectedCountry = Country(
    phoneCode: "91",
    countryCode: "IN",
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: "India",
    example: "9123456789",
    displayName: "India (IN) [+91]",
    displayNameNoCountryCode: "India (IN)",
    e164Key: "",
  );

  // Map of common country codes - same as in AddPhoneDialog
  final Map<String, Map<String, String>> countryCodeMap = {
    "1": {"code": "US", "name": "United States"},
    "7": {"code": "RU", "name": "Russia"},
    "20": {"code": "EG", "name": "Egypt"},
    "27": {"code": "ZA", "name": "South Africa"},
    "30": {"code": "GR", "name": "Greece"},
    "31": {"code": "NL", "name": "Netherlands"},
    "32": {"code": "BE", "name": "Belgium"},
    "33": {"code": "FR", "name": "France"},
    "34": {"code": "ES", "name": "Spain"},
    "36": {"code": "HU", "name": "Hungary"},
    "39": {"code": "IT", "name": "Italy"},
    "40": {"code": "RO", "name": "Romania"},
    "41": {"code": "CH", "name": "Switzerland"},
    "43": {"code": "AT", "name": "Austria"},
    "44": {"code": "GB", "name": "United Kingdom"},
    "45": {"code": "DK", "name": "Denmark"},
    "46": {"code": "SE", "name": "Sweden"},
    "47": {"code": "NO", "name": "Norway"},
    "48": {"code": "PL", "name": "Poland"},
    "49": {"code": "DE", "name": "Germany"},
    "51": {"code": "PE", "name": "Peru"},
    "52": {"code": "MX", "name": "Mexico"},
    "53": {"code": "CU", "name": "Cuba"},
    "54": {"code": "AR", "name": "Argentina"},
    "55": {"code": "BR", "name": "Brazil"},
    "56": {"code": "CL", "name": "Chile"},
    "57": {"code": "CO", "name": "Colombia"},
    "58": {"code": "VE", "name": "Venezuela"},
    "60": {"code": "MY", "name": "Malaysia"},
    "61": {"code": "AU", "name": "Australia"},
    "62": {"code": "ID", "name": "Indonesia"},
    "63": {"code": "PH", "name": "Philippines"},
    "64": {"code": "NZ", "name": "New Zealand"},
    "65": {"code": "SG", "name": "Singapore"},
    "66": {"code": "TH", "name": "Thailand"},
    "81": {"code": "JP", "name": "Japan"},
    "82": {"code": "KR", "name": "South Korea"},
    "84": {"code": "VN", "name": "Vietnam"},
    "86": {"code": "CN", "name": "China"},
    "90": {"code": "TR", "name": "Turkey"},
    "91": {"code": "IN", "name": "India"},
    "92": {"code": "PK", "name": "Pakistan"},
    "93": {"code": "AF", "name": "Afghanistan"},
    "94": {"code": "LK", "name": "Sri Lanka"},
    "95": {"code": "MM", "name": "Myanmar"},
    "98": {"code": "IR", "name": "Iran"},
    "212": {"code": "MA", "name": "Morocco"},
    "213": {"code": "DZ", "name": "Algeria"},
    "216": {"code": "TN", "name": "Tunisia"},
    "218": {"code": "LY", "name": "Libya"},
    "220": {"code": "GM", "name": "Gambia"},
    "221": {"code": "SN", "name": "Senegal"},
    "222": {"code": "MR", "name": "Mauritania"},
    "223": {"code": "ML", "name": "Mali"},
    "224": {"code": "GN", "name": "Guinea"},
    "225": {"code": "CI", "name": "Ivory Coast"},
    "226": {"code": "BF", "name": "Burkina Faso"},
    "227": {"code": "NE", "name": "Niger"},
    "228": {"code": "TG", "name": "Togo"},
    "229": {"code": "BJ", "name": "Benin"},
    "230": {"code": "MU", "name": "Mauritius"},
    "231": {"code": "LR", "name": "Liberia"},
    "232": {"code": "SL", "name": "Sierra Leone"},
    "233": {"code": "GH", "name": "Ghana"},
    "234": {"code": "NG", "name": "Nigeria"},
    "235": {"code": "TD", "name": "Chad"},
    "236": {"code": "CF", "name": "Central African Republic"},
    "237": {"code": "CM", "name": "Cameroon"},
    "238": {"code": "CV", "name": "Cape Verde"},
    "239": {"code": "ST", "name": "São Tomé and Príncipe"},
    "240": {"code": "GQ", "name": "Equatorial Guinea"},
    "241": {"code": "GA", "name": "Gabon"},
    "242": {"code": "CG", "name": "Republic of the Congo"},
    "243": {"code": "CD", "name": "Democratic Republic of the Congo"},
    "244": {"code": "AO", "name": "Angola"},
    "245": {"code": "GW", "name": "Guinea-Bissau"},
    "246": {"code": "IO", "name": "British Indian Ocean Territory"},
    "248": {"code": "SC", "name": "Seychelles"},
    "249": {"code": "SD", "name": "Sudan"},
    "250": {"code": "RW", "name": "Rwanda"},
    "251": {"code": "ET", "name": "Ethiopia"},
    "252": {"code": "SO", "name": "Somalia"},
    "253": {"code": "DJ", "name": "Djibouti"},
    "254": {"code": "KE", "name": "Kenya"},
    "255": {"code": "TZ", "name": "Tanzania"},
    "256": {"code": "UG", "name": "Uganda"},
    "257": {"code": "BI", "name": "Burundi"},
    "258": {"code": "MZ", "name": "Mozambique"},
    "260": {"code": "ZM", "name": "Zambia"},
    "261": {"code": "MG", "name": "Madagascar"},
    "262": {"code": "RE", "name": "Réunion"},
    "263": {"code": "ZW", "name": "Zimbabwe"},
    "264": {"code": "NA", "name": "Namibia"},
    "265": {"code": "MW", "name": "Malawi"},
    "266": {"code": "LS", "name": "Lesotho"},
    "267": {"code": "BW", "name": "Botswana"},
    "268": {"code": "SZ", "name": "Eswatini"},
    "269": {"code": "KM", "name": "Comoros"},
    "290": {"code": "SH", "name": "Saint Helena"},
    "291": {"code": "ER", "name": "Eritrea"},
    "297": {"code": "AW", "name": "Aruba"},
    "298": {"code": "FO", "name": "Faroe Islands"},
    "299": {"code": "GL", "name": "Greenland"},
    "350": {"code": "GI", "name": "Gibraltar"},
    "351": {"code": "PT", "name": "Portugal"},
    "352": {"code": "LU", "name": "Luxembourg"},
    "353": {"code": "IE", "name": "Ireland"},
    "354": {"code": "IS", "name": "Iceland"},
    "355": {"code": "AL", "name": "Albania"},
    "356": {"code": "MT", "name": "Malta"},
    "357": {"code": "CY", "name": "Cyprus"},
    "358": {"code": "FI", "name": "Finland"},
    "359": {"code": "BG", "name": "Bulgaria"},
    "370": {"code": "LT", "name": "Lithuania"},
    "371": {"code": "LV", "name": "Latvia"},
    "372": {"code": "EE", "name": "Estonia"},
    "373": {"code": "MD", "name": "Moldova"},
    "374": {"code": "AM", "name": "Armenia"},
    "375": {"code": "BY", "name": "Belarus"},
    "376": {"code": "AD", "name": "Andorra"},
    "377": {"code": "MC", "name": "Monaco"},
    "378": {"code": "SM", "name": "San Marino"},
    "380": {"code": "UA", "name": "Ukraine"},
    "381": {"code": "RS", "name": "Serbia"},
    "382": {"code": "ME", "name": "Montenegro"},
    "383": {"code": "XK", "name": "Kosovo"},
    "385": {"code": "HR", "name": "Croatia"},
    "386": {"code": "SI", "name": "Slovenia"},
    "387": {"code": "BA", "name": "Bosnia and Herzegovina"},
    "389": {"code": "MK", "name": "North Macedonia"},
    "420": {"code": "CZ", "name": "Czech Republic"},
    "421": {"code": "SK", "name": "Slovakia"},
    "423": {"code": "LI", "name": "Liechtenstein"},
    "500": {"code": "FK", "name": "Falkland Islands"},
    "501": {"code": "BZ", "name": "Belize"},
    "502": {"code": "GT", "name": "Guatemala"},
    "503": {"code": "SV", "name": "El Salvador"},
    "504": {"code": "HN", "name": "Honduras"},
    "505": {"code": "NI", "name": "Nicaragua"},
    "506": {"code": "CR", "name": "Costa Rica"},
    "507": {"code": "PA", "name": "Panama"},
    "508": {"code": "PM", "name": "Saint Pierre and Miquelon"},
    "509": {"code": "HT", "name": "Haiti"},
    "590": {"code": "GP", "name": "Guadeloupe"},
    "591": {"code": "BO", "name": "Bolivia"},
    "592": {"code": "GY", "name": "Guyana"},
    "593": {"code": "EC", "name": "Ecuador"},
    "594": {"code": "GF", "name": "French Guiana"},
    "595": {"code": "PY", "name": "Paraguay"},
    "596": {"code": "MQ", "name": "Martinique"},
    "597": {"code": "SR", "name": "Suriname"},
    "598": {"code": "UY", "name": "Uruguay"},
    "599": {"code": "CW", "name": "Curaçao"},
    "670": {"code": "TL", "name": "East Timor"},
    "672": {"code": "NF", "name": "Norfolk Island"},
    "673": {"code": "BN", "name": "Brunei"},
    "674": {"code": "NR", "name": "Nauru"},
    "675": {"code": "PG", "name": "Papua New Guinea"},
    "676": {"code": "TO", "name": "Tonga"},
    "677": {"code": "SB", "name": "Solomon Islands"},
    "678": {"code": "VU", "name": "Vanuatu"},
    "679": {"code": "FJ", "name": "Fiji"},
    "680": {"code": "PW", "name": "Palau"},
    "681": {"code": "WF", "name": "Wallis and Futuna"},
    "682": {"code": "CK", "name": "Cook Islands"},
    "683": {"code": "NU", "name": "Niue"},
    "685": {"code": "WS", "name": "Samoa"},
    "686": {"code": "KI", "name": "Kiribati"},
    "687": {"code": "NC", "name": "New Caledonia"},
    "688": {"code": "TV", "name": "Tuvalu"},
    "689": {"code": "PF", "name": "French Polynesia"},
    "690": {"code": "TK", "name": "Tokelau"},
    "691": {"code": "FM", "name": "Micronesia"},
    "692": {"code": "MH", "name": "Marshall Islands"},
    "850": {"code": "KP", "name": "North Korea"},
    "852": {"code": "HK", "name": "Hong Kong"},
    "853": {"code": "MO", "name": "Macau"},
    "855": {"code": "KH", "name": "Cambodia"},
    "856": {"code": "LA", "name": "Laos"},
    "880": {"code": "BD", "name": "Bangladesh"},
    "886": {"code": "TW", "name": "Taiwan"},
    "960": {"code": "MV", "name": "Maldives"},
    "961": {"code": "LB", "name": "Lebanon"},
    "962": {"code": "JO", "name": "Jordan"},
    "963": {"code": "SY", "name": "Syria"},
    "964": {"code": "IQ", "name": "Iraq"},
    "965": {"code": "KW", "name": "Kuwait"},
    "966": {"code": "SA", "name": "Saudi Arabia"},
    "967": {"code": "YE", "name": "Yemen"},
    "968": {"code": "OM", "name": "Oman"},
    "970": {"code": "PS", "name": "Palestine"},
    "971": {"code": "AE", "name": "United Arab Emirates"},
    "972": {"code": "IL", "name": "Israel"},
    "973": {"code": "BH", "name": "Bahrain"},
    "974": {"code": "QA", "name": "Qatar"},
    "975": {"code": "BT", "name": "Bhutan"},
    "976": {"code": "MN", "name": "Mongolia"},
    "977": {"code": "NP", "name": "Nepal"},
    "992": {"code": "TJ", "name": "Tajikistan"},
    "993": {"code": "TM", "name": "Turkmenistan"},
    "994": {"code": "AZ", "name": "Azerbaijan"},
    "995": {"code": "GE", "name": "Georgia"},
    "996": {"code": "KG", "name": "Kyrgyzstan"},
    "998": {"code": "UZ", "name": "Uzbekistan"},
  };

  @override
  void initState() {
    super.initState();
    if (widget.currentPhone != null && widget.currentPhone!.isNotEmpty) {
      _parsePhoneNumber(widget.currentPhone!);
    }
  }

  void _parsePhoneNumber(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
      
      bool foundCountry = false;
      
      for (int length = 3; length >= 1; length--) {
        if (cleaned.length > length) {
          String potentialCode = cleaned.substring(0, length);
          
          if (countryCodeMap.containsKey(potentialCode)) {
            String countryCode = countryCodeMap[potentialCode]!['code']!;
            String countryName = countryCodeMap[potentialCode]!['name']!;
            String remainingNumber = cleaned.substring(length);
            
            phoneController.text = remainingNumber;
            
            try {
              final countries = CountryService().getAll();
              final matchedCountry = countries.firstWhere(
                (c) => c.countryCode == countryCode,
                orElse: () => selectedCountry,
              );
              
              setState(() {
                selectedCountry = matchedCountry;
              });
            } catch (e) {
              setState(() {
                selectedCountry = Country(
                  phoneCode: potentialCode,
                  countryCode: countryCode,
                  e164Sc: 0,
                  geographic: true,
                  level: 1,
                  name: countryName,
                  example: "",
                  displayName: "$countryName ($countryCode) [+$potentialCode]",
                  displayNameNoCountryCode: "$countryName ($countryCode)",
                  e164Key: "",
                );
              });
            }
            
            foundCountry = true;
            break;
          }
        }
      }
      
      if (!foundCountry) {
        phoneController.text = cleaned;
      }
    } else {
      phoneController.text = cleaned;
    }
  }

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

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      final phone = phoneController.text.trim();
      final fullPhoneNumber = '+${selectedCountry.phoneCode}$phone';

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

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final success = await ref.read(whatsappProvider.notifier).addWhatsAppNumber(
              memberId: widget.memberId,
              phoneNumber: fullPhoneNumber,
              memberName: guest.memberName,
              phoneType: widget.phoneType,
            );

        if (mounted) Navigator.pop(context);

        if (success) {
          final whatsappResponse = ref.read(whatsappProvider).whatsappResponse;
          final addedPhone = whatsappResponse?.phoneNumber ?? fullPhoneNumber;
          final phoneFieldName = whatsappResponse?.phoneFieldName ?? 'phone${widget.phoneType}';
          
          ref.read(mainProfileDetailsProvider.notifier)
              .updatePhoneNumber(addedPhone, phoneFieldName);
          
          if (widget.onPhoneAdded != null) {
            widget.onPhoneAdded!(addedPhone);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Phone number added: $addedPhone'),
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
                  'Failed to add phone number: ${ref.read(whatsappProvider).error ?? "Unknown error"}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
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
    
    String title = 'Add WhatsApp ${widget.phoneType}';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(15.0),
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

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _showCountryPicker,
                    child: Container(
                      width: 60,
                      height: 56,
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
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+${selectedCountry.phoneCode}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  Expanded(
                    child: TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Phone Number *',
                        labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        hintText: 'Enter phone number',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 14.0,
                        ),
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
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 18, color: const Color.fromARGB(255, 0, 0, 0)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        phoneController.text.isEmpty
                            ? 'Full number will appear here'
                            : 'Full number: +${selectedCountry.phoneCode} ${phoneController.text}',
                        style: TextStyle(
                          fontSize: 15,
                          color: phoneController.text.isEmpty
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