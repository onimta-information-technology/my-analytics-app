// lib/screens/follow_up_view_screen.dart

import 'package:ballys_reservation_app/components/follow_up_pdf_button.dart';
import 'package:ballys_reservation_app/components/guestDisplayCardById.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/follow_up_item.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Read-only view of a saved follow-up. Mirrors the Add Follow-up form field
/// for field — same photo box, description, contact status, response and
/// positive-follow-up sections — but nothing here can be changed.
///
/// Contact statuses, checklist items and positive statuses are listed in full,
/// with the saved values marked, so the screen reads exactly like the form the
/// marketer filled in.
const List<String> _kContactStatuses = <String>[
  'Contacted',
  'Not Reachable',
  'No Answer',
  'Wrong Number',
];

const List<String> _kPositiveChecklist = <String>[
  'Explained latest packages',
  'Explained promotions',
  'Discussed VIP benefits',
  'Proposed travel dates',
  'Planned visit date',
];

const List<String> _kPositiveStatuses = <String>[
  'Visit Planned',
  'Package Opened',
  'Customer Confirmed',
];

class FollowUpViewScreen extends StatefulWidget {
  final FollowUpItem item;

  const FollowUpViewScreen({super.key, required this.item});

  @override
  State<FollowUpViewScreen> createState() => _FollowUpViewScreenState();
}

class _FollowUpViewScreenState extends State<FollowUpViewScreen> {
  /// Text size multiplier picked from the 1x / 1.2x / 1.3x selector.
  double _textScale = 1.0;

  FollowUpItem get item => widget.item;

  bool get _isContacted => item.contactStatus == 'Contacted';

  bool get _hasRange =>
      (item.dateRange?.isNotEmpty ?? false) ||
      (item.buyInRange?.isNotEmpty ?? false);

  void _openPhoto(BuildContext context) {
    final bytes = item.photoBytes;
    if (bytes == null) return;

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(bytes),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Text scale (1x / 1.2x / 1.3x) selector ──────────────────────────────
  Widget _buildTextScaleSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          "Text Size",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Color.fromARGB(255, 0, 0, 0),
          ),
        ),
        const SizedBox(width: 10),
        ...[1.0, 1.2, 1.3].map((scale) {
          final bool selected = _textScale == scale;
          return Padding(
            padding: const EdgeInsets.only(left: 6.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _textScale = scale),
              child: Container(
                width: 44,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? Constants.kSecondaryColor
                      : Colors.transparent,
                  border: Border.all(color: Constants.kSecondaryColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${scale.toDouble()}x",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : Constants.kSecondaryColor,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final photo = item.photoBytes;
    final bool isNegative = item.isNegative;
    final Color responseColor = isNegative ? Colors.red : Colors.green;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Follow-up Details'),
        backgroundColor: Constants.kPrimaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/inctiveMemberMain/followups'),
        ),
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(_textScale)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Text size selector (1x / 1.2x / 1.3x) ───────────────────
                  MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.noScaling),
                    child: _buildTextScaleSelector(),
                  ),
                  const SizedBox(height: 12),

                  // ── Search range the follow-up was saved under ───────────────
                  if (_hasRange) ...[
                    _RangeBanner(
                      dateRange: item.dateRange,
                      buyInRange: item.buyInRange,
                    ),
                    const SizedBox(height: 6),
                  ],

                  // ── Member ───────────────────────────────────────────────────
                  GuestDisplayCardById(
                    memberId: item.memberId,
                    showLastVisitDate: true,
                  ),
                  if (item.createdDate != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat(
                            'dd MMM yyyy  hh:mm a',
                          ).format(item.createdDate!),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ── Photo ────────────────────────────────────────────────────
                  GestureDetector(
                    onTap: photo == null ? null : () => _openPhoto(context),
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: photo != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                photo,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const _NoPhotoPlaceholder(),
                              ),
                            )
                          : const _NoPhotoPlaceholder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Description ──────────────────────────────────────────────
                  _ReadOnlyField(
                    label: 'Description',
                    value: item.description,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),

                  // ── Contact status ───────────────────────────────────────────
                  const Text(
                    'Contact Status',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      children: _kContactStatuses
                          .map(
                            (status) => _ReadOnlyRadioItem(
                              label: status,
                              selected: status == item.contactStatus,
                            ),
                          )
                          .toList(),
                    ),
                  ),

                  if (_isContacted) ...[
                    const SizedBox(height: 16),

                    // ── Response type ──────────────────────────────────────────
                    if (item.responseType != null &&
                        item.responseType!.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: responseColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: responseColor, width: 2),
                          ),
                          child: Text(
                            item.responseType!,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: responseColor,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Customer response ──────────────────────────────────────
                    _ReadOnlyField(
                      label: 'Customer Response',
                      value: item.customerResponse ?? '',
                    ),

                    if (item.remarks != null && item.remarks!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _ReadOnlyField(
                        label: 'Remarks',
                        value: item.remarks!,
                        maxLines: 3,
                      ),
                    ],

                    if (item.isPositive) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Positive Follow-up',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._kPositiveChecklist.map(
                        (checklistItem) => _ReadOnlyCheckItem(
                          label: checklistItem,
                          checked: item.checklistItems.contains(checklistItem),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Status',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Column(
                          children: _kPositiveStatuses
                              .map(
                                (status) => _ReadOnlyRadioItem(
                                  label: status,
                                  selected: status == item.positiveStatus,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ],

                  // ── Share (AD001, or the user who saved it) ──────────────────
                  const SizedBox(height: 24),
                  FollowUpPdfButton(item: item),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Highlighted strip showing the inactive-members search filters the
/// follow-up was saved under.
class _RangeBanner extends StatelessWidget {
  final String? dateRange;
  final String? buyInRange;

  const _RangeBanner({this.dateRange, this.buyInRange});

  @override
  Widget build(BuildContext context) {
    final hasDate = dateRange?.isNotEmpty ?? false;
    final hasBuyIn = buyInRange?.isNotEmpty ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Constants.kPrimaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Constants.kPrimaryColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          if (hasDate)
            Expanded(
              child: _RangeItem(
                icon: Icons.date_range,
                label: 'Date Range',
                value: dateRange!,
              ),
            ),
          if (hasDate && hasBuyIn)
            Container(
              width: 1,
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: Constants.kPrimaryColor.withOpacity(0.3),
            ),
          if (hasBuyIn)
            Expanded(
              child: _RangeItem(
                icon: Icons.attach_money,
                label: 'Buy-in Range',
                value: buyInRange!,
              ),
            ),
        ],
      ),
    );
  }
}

class _RangeItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RangeItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 26, color: Constants.kPrimaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoPhotoPlaceholder extends StatelessWidget {
  const _NoPhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.image_not_supported_outlined,
          size: 36,
          color: Colors.grey.shade500,
        ),
        const SizedBox(height: 8),
        Text('No photo', style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }
}

/// A boxed, non-editable field styled like the form's [TextField]s.
class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final int maxLines;

  const _ReadOnlyField({
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black, fontSize: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      child: Text(
        value.isEmpty ? '-' : value,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 20, color: Colors.black87),
      ),
    );
  }
}

/// A radio row that shows its state but cannot be changed.
class _ReadOnlyRadioItem extends StatelessWidget {
  final String label;
  final bool selected;

  const _ReadOnlyRadioItem({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? Constants.kPrimaryColor : Colors.grey.shade400,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Constants.kPrimaryColor : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A checklist row that shows its state but cannot be changed.
class _ReadOnlyCheckItem extends StatelessWidget {
  final String label;
  final bool checked;

  const _ReadOnlyCheckItem({required this.label, required this.checked});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            checked ? Icons.check_box : Icons.check_box_outline_blank,
            color: checked ? Constants.kPrimaryColor : Colors.grey.shade400,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: checked ? Colors.black87 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
