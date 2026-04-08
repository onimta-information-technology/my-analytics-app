// lib/screens/member/cdd_view_screen.dart

import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/cdd/cdd_history_item.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CddViewScreen extends ConsumerWidget {
  final CddHistoryItem item;
  const CddViewScreen({super.key, required this.item});

  static const _sourceOfFundsOptions = [
    'Salary Receipts',
    'Business Income',
    'Sale of Assets',
    'Casino Jackpot Win',
    'Gift from parents / inheritance',
  ];

  static const _clientTypeOptions = [
    'Salaried Individual',
    'Businessmen',
    'Self Employed',
    'not clear',
  ];

  static const _natureOfBusinessOptions = [
    'BS - Bank Staff',
    'NES - Non executive staff of state owned enterprises',
    'CLSE - Companies listed in stock exchange and not involve in business under high risk category',
    'HRNB - High Risk nature business such as money changers, night clubs, casinos, supply of firearms and ammuntions ect.',
    'ESHR - Employees of such high risk companies',
    'OLR - Other low risk nature business profession',
  ];

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy  hh:mm a').format(dt);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSettings = ref.watch(fontSettingsProvider);

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
    final subtitleStyle = TextStyle(
      fontSize: fontSettings.fontSize - 1,
      color: Colors.grey.shade700,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/memberMain'),
        ),
        title: const Text('CDD Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header banner ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Constants.kPrimaryColor.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Constants.kPrimaryColor.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Due Diligence',
                    style: TextStyle(
                      fontSize: fontSettings.fontSize + 2,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Submitted by ${item.text6}  •  ${_formatDate(item.insertDate)}',
                    style: subtitleStyle,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Section 1 ────────────────────────────────────────────────
            const _SectionHeader(title: '1. Identification Details'),
            const SizedBox(height: 10),
            _ViewCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Passport / NIC No', style: labelStyle),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _ReadOnlyChip(
                        label: 'Passport',
                        isSelected: item.text1 == '1 - 1',
                        fontSize: fontSettings.fontSize,
                      ),
                      const SizedBox(width: 12),
                      _ReadOnlyChip(
                        label: 'NIC',
                        isSelected: item.text1 == '1 - 2',
                        fontSize: fontSettings.fontSize,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(item.text2, style: optionStyle),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Section 2 ────────────────────────────────────────────────
            const _SectionHeader(title: '2. Source of Funds'),
            const SizedBox(height: 10),
            _ViewCard(
              highlighted: true,
              child: Column(
                children: _sourceOfFundsOptions.asMap().entries.map((e) {
                  final code = '2 - ${e.key + 1}';
                  return _ReadOnlyRadioItem(
                    label: e.value,
                    isSelected: item.text3 == code,
                    optionStyle: optionStyle,
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // ── Section 3.1 ──────────────────────────────────────────────
            const _SectionHeader(title: '3.1 Client Type'),
            const SizedBox(height: 10),
            _ViewCard(
              child: Column(
                children: _clientTypeOptions.asMap().entries.map((e) {
                  final code = '3.1 - ${e.key + 1}';
                  return _ReadOnlyRadioItem(
                    label: e.value,
                    isSelected: item.text4 == code,
                    optionStyle: optionStyle,
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // ── Section 3.2 ──────────────────────────────────────────────
            const _SectionHeader(
              title: '3.2 Nature Of Business / Profession of the customer',
            ),
            const SizedBox(height: 10),
            _ViewCard(
              child: Column(
                children:
                    _natureOfBusinessOptions.asMap().entries.expand((e) {
                  final code = '3.2 - ${e.key + 1}';
                  return [
                    _ReadOnlyRadioItem(
                      label: e.value,
                      isSelected: item.text5 == code,
                      optionStyle: optionStyle,
                    ),
                    const SizedBox(height: 13),
                  ];
                }).toList(),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable read-only widgets ───────────────────────────────────────────────

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

class _ViewCard extends StatelessWidget {
  final Widget child;
  final bool highlighted;
  const _ViewCard({required this.child, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
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
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _ReadOnlyChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final double fontSize;
  const _ReadOnlyChip({
    required this.label,
    required this.isSelected,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration.zero,
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
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyRadioItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final TextStyle optionStyle;
  const _ReadOnlyRadioItem({
    required this.label,
    required this.isSelected,
    required this.optionStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Radio<bool>(
            value: true,
            groupValue: isSelected ? true : null,
            onChanged: null,
            activeColor: Constants.kPrimaryColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: optionStyle.copyWith(
                fontWeight: isSelected ? FontWeight.bold : optionStyle.fontWeight,
                color: isSelected ? Constants.kPrimaryColor : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}