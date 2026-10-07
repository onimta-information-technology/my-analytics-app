import 'dart:convert';

import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/guest_search_response.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Ballys-only screen for moving a member to a different marketing person.
/// Reached from the Change Marketer card on the Members main screen.
class ChangeMarketingPersonScreen extends ConsumerStatefulWidget {
  const ChangeMarketingPersonScreen({super.key});

  @override
  ConsumerState<ChangeMarketingPersonScreen> createState() =>
      _ChangeMarketingPersonScreenState();
}

class _ChangeMarketingPersonScreenState
    extends ConsumerState<ChangeMarketingPersonScreen> {
  // TODO: replace with the marketer list API once it is available.
  static const List<({String code, String name})> _marketers = [
    (code: '1001', name: 'Marketer One'),
    (code: '1002', name: 'Marketer Two'),
    (code: '1003', name: 'Marketer Three'),
  ];

  static const List<String> _prefixes = ['BM', 'BL', 'BN'];

  final GuestRepository _guestRepository = GuestRepository(
    ApiService(SecureStorage.instance),
  );
  final TextEditingController _memberIdController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  final FocusNode _memberIdFocusNode = FocusNode();

  String _selectedPrefix = 'BM';
  bool _isLoading = false;
  GuestSearchResponse? _member;
  String? _searchError;
  String? _selectedMarketerCode;

  /// Base text size from the user's font setting; every size on this screen
  /// is offset from it.
  double get _fs => ref.watch(fontSettingsProvider).fontSize;

  @override
  void dispose() {
    _memberIdController.dispose();
    _memberIdFocusNode.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _searchMember() async {
    final number = _memberIdController.text.trim();
    if (number.isEmpty) return;
    _memberIdFocusNode.unfocus();

    setState(() {
      _isLoading = true;
      _member = null;
      _searchError = null;
      _selectedMarketerCode = null;
    });

    try {
      final results = await _guestRepository.searchGuest(
        8002,
        '$_selectedPrefix$number',
      );
      if (!mounted) return;
      setState(() => _member = results.first);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _searchError = 'No member found for $_selectedPrefix $number',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearSearch() {
    setState(() {
      _memberIdController.clear();
      _remarkController.clear();
      _member = null;
      _searchError = null;
      _selectedMarketerCode = null;
    });
  }

  // ── Submit ──────────────────────────────────────────────────────────────

  Future<void> _onSubmit(GuestSearchResponse member) async {
    final marketer = _marketers
        .where((m) => m.code == _selectedMarketerCode)
        .firstOrNull;
    if (marketer == null) return;

    final confirmed = await _confirmSubmit(member, marketer.name);
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _submitMarketerChange(
        member,
        marketer.code,
        _remarkController.text.trim(),
      );
      if (!mounted) return;
      _showSnackBar(
        '${member.mid} moved to ${marketer.name}',
        Colors.green.shade600,
      );
      _clearSearch();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        e is UnimplementedError
            ? 'Submit API is not connected yet'
            : 'Could not change marketer. Please try again.',
        Colors.red.shade400,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // TODO: call the change-marketer API once it is available.
  Future<void> _submitMarketerChange(
    GuestSearchResponse member,
    String marketerCode,
    String remark,
  ) async {
    throw UnimplementedError();
  }

  Future<bool?> _confirmSubmit(GuestSearchResponse member, String newName) {
    final current = (member.gName ?? '').isEmpty ? '-' : member.gName!;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Change Marketer',
          style: TextStyle(fontSize: _fs - 1, fontWeight: FontWeight.bold),
        ),
        content: Text.rich(
          TextSpan(
            style: TextStyle(fontSize: _fs - 3, color: Colors.black87),
            children: [
              const TextSpan(text: 'Move '),
              TextSpan(
                text: '${member.mid} (${member.mName})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' from '),
              TextSpan(
                text: current,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' to '),
              TextSpan(
                text: newName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '?'),
              if (_remarkController.text.trim().isNotEmpty) ...[
                const TextSpan(text: '\n\nRemark: '),
                TextSpan(
                  text: _remarkController.text.trim(),
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: _fs - 3, color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.kPrimaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Submit', style: TextStyle(fontSize: _fs - 3)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: _fs - 3)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Search ──────────────────────────────────────────────────────────────

  Widget _buildSearchCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find Member',
              style: TextStyle(
                fontSize: _fs - 2,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _prefixes.map((prefix) {
                final selected = prefix == _selectedPrefix;
                return ChoiceChip(
                  label: Text(
                    prefix,
                    style: TextStyle(
                      fontSize: _fs - 3,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.black87,
                    ),
                  ),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: Constants.kPrimaryColor,
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: selected
                          ? Constants.kPrimaryColor
                          : Colors.grey.shade300,
                    ),
                  ),
                  onSelected: (_) => setState(() => _selectedPrefix = prefix),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    focusNode: _memberIdFocusNode,
                    controller: _memberIdController,
                    keyboardType: const TextInputType.numberWithOptions(),
                    textInputAction: TextInputAction.search,
                    onFieldSubmitted: (_) => _searchMember(),
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      fontSize: _fs + 2,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Member number',
                      hintStyle: TextStyle(
                        fontSize: _fs - 2,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.normal,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 6),
                        child: Text(
                          _selectedPrefix,
                          style: TextStyle(
                            fontSize: _fs + 2,
                            fontWeight: FontWeight.bold,
                            color: Constants.kPrimaryColor,
                          ),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(),
                      suffixIcon: _memberIdController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _clearSearch,
                            ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Constants.kPrimaryColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 54,
                  width: 54,
                  child: ElevatedButton(
                    onPressed: _searchMember,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Constants.kPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.search, size: 28),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty / not found ───────────────────────────────────────────────────

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String subtitle,
    Color color = Constants.kPrimaryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: _fs, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: _fs - 3, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ── Member ──────────────────────────────────────────────────────────────

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Constants.kPrimaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: Constants.kPrimaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: _fs - 5,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value.isEmpty ? '-' : value,
                  style: TextStyle(
                    fontSize: _fs - 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Same colours as the rating label on the guest gifts screen.
  Color _getRatingColor(String rating) {
    switch (rating.toUpperCase()) {
      case 'GOLD':
        return const Color(0xFFDAA520);
      case 'PLATINUM':
        return const Color(0xFF707070);
      case 'DIAMOND':
        return const Color(0xFF1565C0);
      case 'SILVER':
        return const Color(0xFF9E9E9E);
      case 'INFINITY':
        return const Color(0xFF4A148C);
      case 'PREMIER':
        return const Color(0xFF1B5E20);
      case 'RAFFELS CLUB':
        return const Color(0xFF880E4F);
      default:
        return const Color(0xFF5D4037);
    }
  }

  /// Full-screen, zoomable member photo — same popup as the guest gifts
  /// screen. Tapping anywhere closes it.
  void _showImagePopup(String memImage2) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(dialogContext).pop(),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
                    maxHeight: MediaQuery.of(dialogContext).size.height * 0.8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: Image.memory(
                      base64Decode(memImage2),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.person,
                        size: 120,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMemberCard(GuestSearchResponse member) {
    final lvd = member.lvd != null
        ? DateFormat('dd MMM yyyy').format(member.lvd!)
        : '';
    // Same fallback as the gift screen: a missing rating reads as CLASSIC.
    final rawRating = (member.gRating ?? '').trim();
    final rating = rawRating.isEmpty || rawRating.toUpperCase() == 'NULL'
        ? 'CLASSIC'
        : rawRating;

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Constants.kPrimaryColor,
                  Color.fromARGB(255, 230, 190, 110),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: member.memImage2.isEmpty
                      ? null
                      : () => _showImagePopup(member.memImage2),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: member.memImage2.isNotEmpty
                          ? MemoryImage(base64Decode(member.memImage2))
                          : null,
                      child: member.memImage2.isEmpty
                          ? const Icon(Icons.person, size: 34)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.mid,
                        style: TextStyle(
                          fontSize: _fs + 2,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.mName,
                        style: TextStyle(
                          fontSize: _fs - 3,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getRatingColor(rating),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          rating,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: _fs - 6,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                _buildInfoTile(
                  Icons.support_agent,
                  'Current Marketer',
                  member.gName ?? '',
                ),
                _buildInfoTile(
                  Icons.groups_outlined,
                  'Marketing Group',
                  member.mGroup ?? '',
                ),
                _buildInfoTile(Icons.event_outlined, 'Last Visit', lvd),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── New marketer ────────────────────────────────────────────────────────

  Widget _buildMarketerCard(GuestSearchResponse member) {
    final current = (member.gName ?? '').isEmpty ? '-' : member.gName!;
    final selected = _marketers
        .where((m) => m.code == _selectedMarketerCode)
        .map((m) => m.name)
        .firstOrNull;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Assign New Marketer',
              style: TextStyle(
                fontSize: _fs - 2,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // Keyed on the member so a new search starts with nothing
              // selected.
              key: ValueKey(member.mid),
              initialValue: _selectedMarketerCode,
              isExpanded: true,
              style: TextStyle(fontSize: _fs - 2, color: Colors.black),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              decoration: InputDecoration(
                hintText: 'Select marketer',
                hintStyle: TextStyle(
                  fontSize: _fs - 2,
                  color: Colors.grey.shade500,
                ),
                prefixIcon: const Icon(
                  Icons.person_search_outlined,
                  color: Constants.kPrimaryColor,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Constants.kPrimaryColor,
                    width: 1.5,
                  ),
                ),
              ),
              items: _marketers
                  .map(
                    (m) => DropdownMenuItem<String>(
                      value: m.code,
                      child: Text(m.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _selectedMarketerCode = value),
            ),
            if (selected != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildChangeSide(
                        'From',
                        current,
                        Colors.grey.shade700,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.green.shade700,
                      ),
                    ),
                    Expanded(
                      child: _buildChangeSide(
                        'To',
                        selected,
                        Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _remarkController,
              minLines: 2,
              maxLines: 4,
              maxLength: 250,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: _fs - 2),
              decoration: InputDecoration(
                labelText: 'Remark',
                labelStyle: TextStyle(fontSize: _fs - 2),
                hintText: 'Reason for the change (optional)',
                hintStyle: TextStyle(
                  fontSize: _fs - 3,
                  color: Colors.grey.shade500,
                ),
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Icon(
                    Icons.notes_rounded,
                    color: Constants.kPrimaryColor,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Constants.kPrimaryColor,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: selected == null || _isLoading
                    ? null
                    : () => _onSubmit(member),
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  'Submit',
                  style: TextStyle(
                    fontSize: _fs - 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.kPrimaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangeSide(String label, String name, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: _fs - 6, color: Colors.grey.shade600),
        ),
        Text(
          name,
          style: TextStyle(
            fontSize: _fs - 3,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(fontSettingsProvider);
    final member = _member;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Change Marketer'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/memberMain'),
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchCard(),
                  const SizedBox(height: 8),
                  if (member != null) ...[
                    _buildMemberCard(member),
                    const SizedBox(height: 8),
                    _buildMarketerCard(member),
                  ] else if (_searchError != null)
                    _buildMessage(
                      icon: Icons.person_off_outlined,
                      title: _searchError!,
                      subtitle: 'Check the member number and try again.',
                      color: Colors.red.shade400,
                    )
                  else if (!_isLoading)
                    _buildMessage(
                      icon: Icons.manage_accounts_outlined,
                      title: 'Search a member',
                      subtitle:
                          'Enter a member number to view their details and '
                          'assign a new marketer.',
                    ),
                ],
              ),
            ),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: const Color.fromARGB(135, 117, 115, 115),
                  child: const Center(
                    child: RefreshProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Constants.kSecondaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            // const Watermark(),
          ],
        ),
      ),
    );
  }
}
