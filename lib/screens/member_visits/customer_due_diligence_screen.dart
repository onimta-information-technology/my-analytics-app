// lib/screens/member/customer_due_diligence_screen.dart

import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/providers/cdd_history_provider.dart';
import 'package:ballys_reservation_app/providers/customer_due_diligence_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CustomerDueDiligenceScreen extends ConsumerStatefulWidget {
  const CustomerDueDiligenceScreen({super.key});

  @override
  ConsumerState<CustomerDueDiligenceScreen> createState() =>
      _CustomerDueDiligenceScreenState();
}

class _CustomerDueDiligenceScreenState
    extends ConsumerState<CustomerDueDiligenceScreen> {
  final _idController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ── Source of Funds options (section 2) ──────────────────────────────────
  static const _sourceOfFundsOptions = [
    'Salary Receipts',
    'Business Income',
    'Sale of Assets',
    'Casino Jackpot Win',
    'Gift from parents / inheritance',
  ];

  // ── Client Type options (section 3.1) ────────────────────────────────────
  static const _clientTypeOptions = [
    'Salaried Individual',
    'Businessmen',
    'Self Employed',
    'not clear',
  ];

  // ── Nature of Business options (section 3.2) ─────────────────────────────
  static const _natureOfBusinessOptions = [
    ('BS', 'BS - Bank Staff'),
    ('NES', 'NES - Non executive staff of state owned enterprises'),
    (
      'CLSE',
      'CLSE - Companies listed in stock exchange and not involve in business under high risk category'
    ),
    (
      'HRNB',
      'HRNB - High Risk nature business such as money changers, night clubs, casinos, supply of firearms and ammuntions ect.'
    ),
    ('ESHR', 'ESHR - Employees of such high risk companies'),
    ('OLR', 'OLR - Other low risk nature business profession'),
  ];

  @override
  void initState() {
    super.initState();
    // Rebuild button state whenever the ID text field changes
    _idController.addListener(() => setState(() {}));
    // Pre-select Passport when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cddFormProvider.notifier).setIdType('1 - 1');
    });
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  /// Returns true only when every required field is filled.
  bool _isFormComplete(cddState) {
    return cddState.idType != null &&
        _idController.text.trim().isNotEmpty &&
        cddState.sourceOfFunds != null &&
        cddState.clientType != null &&
        cddState.natureOfBusiness != null;
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final notifier = ref.read(cddFormProvider.notifier);
    notifier.setIdentificationNumber(_idController.text.trim());

    final success = await notifier.submit();

    if (!mounted) return;

    if (false == success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer Due Diligence submitted successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      notifier.reset();
      _idController.clear();
      ref.read(cddHistoryProvider.notifier).refresh();
      if (context.canPop()) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final cddState = ref.watch(cddFormProvider);
    final notifier = ref.read(cddFormProvider.notifier);

    final formReady = _isFormComplete(cddState);

    final labelStyle = TextStyle(
      fontSize: fontSettings.fontSize,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    );
    final optionStyle = TextStyle(
      fontSize: fontSettings.fontSize,
      fontWeight: fontSettings.fontWeight,
      color: Colors.black87,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/memberMain');
            }
          },
        ),
        title: const Text('Customer Due Diligence'),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ────────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Constants.kPrimaryColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Constants.kPrimaryColor.withAlpha(80),
                      ),
                    ),
                    child: Text(
                      'Customer Due Diligence - Source of funds Details collects from Marketing Officer',
                      style: TextStyle(
                        fontSize: fontSettings.fontSize + 2,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Section 1: Identification ─────────────────────────────
                  const _SectionHeader(title: '1. Identification Details'),
                  const SizedBox(height: 10),
                  _buildSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Passport / NIC No', style: labelStyle),
                        const SizedBox(height: 8),
                        // Radio buttons: Passport | NIC
                        Row(
                          children: [
                            _RadioChip(
                              label: 'Passport',
                              value: '1 - 1',
                              groupValue: cddState.idType,
                              onChanged: notifier.setIdType,
                            ),
                            const SizedBox(width: 12),
                            _RadioChip(
                              label: 'NIC',
                              value: '1 - 2',
                              groupValue: cddState.idType,
                              onChanged: notifier.setIdType,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // ID number text field
                        TextFormField(
                          controller: _idController,
                          decoration: InputDecoration(
                            hintText: cddState.idType == null
                                ? 'Select Passport or NIC first'
                                : 'Enter ${cddState.idType == "PASSPORT" ? "Passport" : "NIC"} Number',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          enabled: cddState.idType != null,
                          style: optionStyle,
                          validator: (v) {
                            if (cddState.idType == null) {
                              return 'Please select Passport or NIC';
                            }
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter identification number';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Section 2: Source of Funds ────────────────────────────
                  const _SectionHeader(title: '2. Source of Funds'),
                  const SizedBox(height: 10),
                  _buildSectionCard(
                    highlighted: true,
                    child: Column(
                     // children: _sourceOfFundsOptions.map((option) {
                     children: _sourceOfFundsOptions.asMap().entries.map((entry) {
      final index = '2 - ${entry.key + 1}';
      final label = entry.value;
                        return _RadioListItem(
                          label: label,
                          value: index,
                          groupValue: cddState.sourceOfFunds,
                          onChanged: notifier.setSourceOfFunds,
                          optionStyle: optionStyle,
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Section 3.1: Client Type ──────────────────────────────
                  const _SectionHeader(title: '3.1 Client Type'),
                  const SizedBox(height: 10),
                  _buildSectionCard(
                    // child: Column(
                    //   children: _clientTypeOptions.map((option) {
                    //     return _RadioListItem(
                    //       label: option,
                    //       value: option,
                    //       groupValue: cddState.clientType,
                    //       onChanged: notifier.setClientType,
                    //       optionStyle: optionStyle,
                    //     );
                    //   }).toList(),
                    // ),
                    child: Column(
  children: _clientTypeOptions.asMap().entries.map((entry) {
    final index ='3.1 - ${entry.key + 1}';
    final label = entry.value;
    return _RadioListItem(
      label: label,
      value: index,
      groupValue: cddState.clientType,
      onChanged: notifier.setClientType,
      optionStyle: optionStyle,
    );
  }).toList(),
),
                  ),

                  const SizedBox(height: 20),

                  // ── Section 3.2: Nature of Business ───────────────────────
                  const _SectionHeader(
                    title:
                        '3.2 Nature Of Business /Profession of the customer',
                  ),
                  const SizedBox(height: 10),
                  _buildSectionCard(
                    // child: Column(
                    //   children: _natureOfBusinessOptions.expand((entry) {
                    //     final (value, label) = entry;
                    //     return [
                    //       _RadioListItem(
                    //         label: label,
                    //         value: value,
                    //         groupValue: cddState.natureOfBusiness,
                    //         onChanged: notifier.setNatureOfBusiness,
                    //         optionStyle: optionStyle,
                    //       ),
                    //       const SizedBox(height: 13),
                    //     ];
                    //   }).toList(),
                    // ),
                    child: Column(
  children: _natureOfBusinessOptions.asMap().entries.expand((entry) {
    final index = '3.2 - ${entry.key + 1}';
    final (_, label) = entry.value;
    return [
      _RadioListItem(
        label: label,
        value: index,
        groupValue: cddState.natureOfBusiness,
        onChanged: notifier.setNatureOfBusiness,
        optionStyle: optionStyle,
      ),
      const SizedBox(height: 13),
    ];
  }).toList(),
),
                  ),

                  const SizedBox(height: 16),

                  // ── Error message ─────────────────────────────────────────
                  if (cddState.errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        cddState.errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: fontSettings.fontSize,
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // ── Submit Button ─────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          cddState.isSubmitting || !formReady ? null : _onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: formReady
                            ? Constants.kPrimaryColor
                            : Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        // Keep the same colour even when disabled
                        disabledBackgroundColor: Colors.grey.shade400,
                        disabledForegroundColor: Colors.white,
                      ),
                      child: cddState.isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Submit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // ── Loading overlay ───────────────────────────────────────────────
          if (cddState.isSubmitting)
            Container(
              color: const Color.fromARGB(100, 0, 0, 0),
              child: Center(
                child: RefreshProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Constants.kSecondaryColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required Widget child, bool highlighted = false}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFFF8E1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}

// ─── Reusable Widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Constants.kPrimaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

class _RadioChip extends StatelessWidget {
  final String label;
  final String value;
  final String? groupValue;
  final ValueChanged<String> onChanged;

  const _RadioChip({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = groupValue == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Constants.kPrimaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Constants.kPrimaryColor : Colors.grey.shade400,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioListItem extends StatelessWidget {
  final String label;
  final String value;
  final String? groupValue;
  final ValueChanged<String> onChanged;
  final TextStyle optionStyle;

  const _RadioListItem({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.optionStyle,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = groupValue == value;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              activeColor: Constants.kPrimaryColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: optionStyle.copyWith(
                  fontWeight:
                      isSelected ? FontWeight.bold : optionStyle.fontWeight,
                  color: isSelected ? Constants.kPrimaryColor : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}