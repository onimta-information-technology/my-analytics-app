import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/guest_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/group_reservation.dart';
import 'package:ballys_reservation_app/models/marketer_change.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/group_reservation_provider.dart';
import 'package:ballys_reservation_app/screens/reservations/transport_view_screen.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ballys-only list of marketer-change requests already submitted. Reached
/// from the Change Marketer card on the Members main screen; the + button
/// opens the change form.
class MarketerChangeListScreen extends ConsumerStatefulWidget {
  const MarketerChangeListScreen({super.key});

  @override
  ConsumerState<MarketerChangeListScreen> createState() =>
      _MarketerChangeListScreenState();
}

class _MarketerChangeListScreenState
    extends ConsumerState<MarketerChangeListScreen> {
  static const double _tileSize = 64;

  final GuestRepository _guestRepository = GuestRepository(
    ApiService(SecureStorage.instance),
  );

  List<MarketerChange> _items = const [];
  // Starts true so the overlay is up from the first frame on open.
  bool _isLoading = true;
  bool _hasError = false;
  double _textScale = 1.0;

  double get _fs => ref.watch(fontSettingsProvider).fontSize;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Keeps the last-known list on screen while a refresh runs, so the
  /// loading overlay sits on top of the cards instead of replacing them.
  Future<void> _refresh() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    await _load();
  }

  Future<void> _load() async {
    try {
      final items = await _guestRepository.getAllMarketerChanges();
      if (!mounted) return;
      setState(() {
        _items = items;
        _hasError = false;
      });
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openForm() async {
    final submitted =
        await context.push<bool>('/memberMain/change-marketing-person/new');
    if (submitted == true && mounted) _refresh();
  }

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
    ref.watch(fontSettingsProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Change Marketer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/memberMain'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 30),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 30),
            tooltip: 'New marketer change',
            onPressed: _openForm,
          ),
        ],
      ),
      body: Stack(
        children: [
          MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(_textScale)),
            child: Column(
              children: [
                MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.noScaling),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: _buildTextScaleSelector(),
                  ),
                ),
                Expanded(child: _buildContent()),
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
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_items.isEmpty) {
      // Must fill the body: a 0x0 child shrinks the Stack and hides the overlay.
      if (_isLoading) return const SizedBox.expand();
      if (_hasError) return _buildError();
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 40),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _buildCard(_items[index]),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            'Failed to load marketer changes.',
            style: TextStyle(fontSize: _fs - 2, color: Colors.red),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    // Scrollable so pull-to-refresh still works on an empty list.
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        children: [
          const SizedBox(height: 160),
          Icon(Icons.person_search_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No marketer change requests.\nTap + to add one.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: _fs - 2, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(MarketerChange item) {
    final date = item.insertDate == null
        ? '-'
        : DateFormat('dd MMM yyyy, hh:mm a').format(item.insertDate!);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.mId,
                        style: TextStyle(
                          fontSize: _fs - 1,
                          fontWeight: FontWeight.bold,
                          color: Constants.kPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.mName,
                        style: TextStyle(
                          fontSize: _fs - 2,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _statusChip(item.approvalStatus),
              ],
            ),
            const Divider(height: 20),
            _infoRow('Current Marketer', _withGroup(item)),
            _infoRow('Requested By', item.reqMPerson),
            _infoRow('Remark', item.remark),
            _infoRow('Requested On', date),
            if (item.images.isNotEmpty) ...[
              const SizedBox(height: 8),
              _imageTiles(item.images),
            ],
          ],
        ),
      ),
    );
  }

  String _withGroup(MarketerChange item) {
    if (item.prvMGroup.isEmpty) return item.prvMPerson;
    if (item.prvMPerson.isEmpty) return item.prvMGroup;
    return '${item.prvMPerson} (${item.prvMGroup})';
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontSize: _fs - 4, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: TextStyle(fontSize: _fs - 3, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final lower = status.toLowerCase();
    final Color color;
    if (lower.contains('approve')) {
      color = Colors.green.shade600;
    } else if (lower.contains('reject')) {
      color = Colors.red.shade400;
    } else {
      color = Colors.orange.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        status.isEmpty ? 'Pending' : status,
        style: TextStyle(
          fontSize: _fs - 5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // ── Images ──────────────────────────────────────────────────────────────

  /// Files are served from the host root, not under `/api/Ballys/CRM`.
  Widget _imageTiles(List<MarketerChangeImage> images) {
    final host = ref.watch(groupReservationFileHostProvider).valueOrNull;
    if (host == null) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: images.map((image) {
        final url = groupReservationFileUrl(host, image.filePath);
        final name = image.fileName.isNotEmpty ? image.fileName : 'Image';
        if (url == null) return _placeholderTile(Icons.broken_image_outlined);
        if (image.isPdf) {
          return GestureDetector(
            onTap: () => _openFile(url, name),
            child: _placeholderTile(Icons.picture_as_pdf, Colors.red),
          );
        }
        return GestureDetector(
          onTap: () => showDialog(
            context: context,
            barrierColor: Colors.black87,
            builder: (_) => PassportImageDialog(url: url, fileName: name),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: _tileSize,
              height: _tileSize,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : _placeholderTile(Icons.image_outlined),
              errorBuilder: (_, __, ___) =>
                  _placeholderTile(Icons.broken_image_outlined),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _placeholderTile(IconData icon, [Color? color]) {
    return Container(
      width: _tileSize,
      height: _tileSize,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color ?? Colors.grey.shade500),
    );
  }

  Future<void> _openFile(String url, String fileName) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open $fileName'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
