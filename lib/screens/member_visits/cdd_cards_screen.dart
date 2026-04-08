// lib/screens/member/cdd_cards_screen.dart

import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/cdd/cdd_history_item.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CddCardsScreen extends StatelessWidget {
  final List<CddHistoryItem> items;
  const CddCardsScreen({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    // All items belong to same person
    final personName = items.isNotEmpty ? items.first.text6 : '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/memberMain'),
        ),
        title: Text(personName),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (context, index) =>
            _CddDetailCard(item: items[index]),
      ),
    );
  }
}

// ── Full detail card ──────────────────────────────────────────────────────────

class _CddDetailCard extends StatelessWidget {
  final CddHistoryItem item;
  const _CddDetailCard({required this.item});

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

  String _resolveLabel(String code, List<String> options) {
    final parts = code.split(' - ');
    if (parts.length == 2) {
      final idx = int.tryParse(parts.last.trim());
      if (idx != null && idx >= 1 && idx <= options.length) {
        return options[idx - 1];
      }
    }
    return code;
  }

  String _idTypeLabel(String code) {
    if (code == '1 - 1') return 'Passport';
    if (code == '1 - 2') return 'NIC';
    return code;
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy  hh:mm a').format(dt);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceLabel =
        _resolveLabel(item.text3, _sourceOfFundsOptions);
    final clientLabel =
        _resolveLabel(item.text4, _clientTypeOptions);
    final businessLabel =
        _resolveLabel(item.text5, _natureOfBusinessOptions);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 3,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () =>
            context.push('/memberMain/cdd/view', extra: item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: index badge + date + chevron ───────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Constants.kPrimaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '#${item.idNo}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Constants.kPrimaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.access_time,
                      size: 13, color: const Color.fromARGB(255, 0, 0, 0)),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(item.insertDate),
                    style: TextStyle(
                        fontSize: 15, color: const Color.fromARGB(255, 0, 0, 0)),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Color.fromARGB(255, 0, 0, 0)),
                ],
              ),

              const Divider(height: 20),

              // ── ID row ──────────────────────────────────────────────
              _InfoRow(
                icon: Icons.badge_outlined,
                label: '${_idTypeLabel(item.text1)} :',
                value: item.text2,
              ),

              const SizedBox(height: 10),

              // ── Source of Funds ─────────────────────────────────────
              _InfoRow(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Source of Funds :',
                value: sourceLabel,
              ),

              const SizedBox(height: 10),

              // ── Client Type ─────────────────────────────────────────
              _InfoRow(
                icon: Icons.person_outline,
                label: 'Client Type :',
                value: clientLabel,
              ),

             // const SizedBox(height: 10),

              // ── Nature of Business ──────────────────────────────────
              // _InfoRow(
              //   icon: Icons.business_center_outlined,
              //   label: 'Nature of Business',
              //   value: businessLabel,
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color.fromARGB(255, 0, 0, 0)),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  color: const Color.fromARGB(255, 0, 0, 0),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    color: const Color.fromARGB(255, 0, 0, 0),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}