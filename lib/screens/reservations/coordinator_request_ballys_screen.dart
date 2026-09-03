import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// What the coordinator is being asked to book.
enum CoordinatorRequestType { airTicket, hotel, both }

extension CoordinatorRequestTypeX on CoordinatorRequestType {
  String get label => switch (this) {
        CoordinatorRequestType.airTicket => 'Air Ticket',
        CoordinatorRequestType.hotel => 'Hotel',
        CoordinatorRequestType.both => 'Both',
      };

  IconData get icon => switch (this) {
        CoordinatorRequestType.airTicket => Icons.flight,
        CoordinatorRequestType.hotel => Icons.hotel,
        CoordinatorRequestType.both => Icons.all_inclusive,
      };
}

/// A coordinator on the picker. Only [name] is shown; [id] is what the request
/// will be saved against once the backend exists.
class CoordinatorOption {
  const CoordinatorOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// Coordinator Request (Ballys only).
///
/// Executives who cannot key a reservation in themselves hand it to a
/// coordinator instead. This screen collects who should do it and what they
/// are being asked to book.
class CoordinatorRequestBallysScreen extends ConsumerStatefulWidget {
  const CoordinatorRequestBallysScreen({super.key});

  @override
  ConsumerState<CoordinatorRequestBallysScreen> createState() =>
      _CoordinatorRequestBallysScreenState();
}

class _CoordinatorRequestBallysScreenState
    extends ConsumerState<CoordinatorRequestBallysScreen>
    with ConnectivityMixin {
  final _formKey = GlobalKey<FormState>();

  /// TODO: replace with the coordinator list from the API. Hard-coded for now
  /// so the form can be used before that endpoint exists.
  static const List<CoordinatorOption> _coordinators = [
    CoordinatorOption(id: '1', name: 'Coordinator One'),
    CoordinatorOption(id: '2', name: 'Coordinator Two'),
  ];

  CoordinatorOption? _selectedCoordinator;
  CoordinatorRequestType? _requestType;

  final TextEditingController _remarksController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedCoordinator == null) {
      _showMessage('Select a coordinator', isError: true);
      return;
    }
    if (_requestType == null) {
      _showMessage('Select what the coordinator should book', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    // TODO: post the request once the endpoint is available. Until then the
    // form only confirms what was captured.
    final coordinator = _selectedCoordinator!;
    debugPrint(
      'Coordinator request → coordinator: ${coordinator.id} '
      '(${coordinator.name}), type: ${_requestType!.label}, '
      'remarks: ${_remarksController.text.trim()}',
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    _showMessage('Request sent to ${coordinator.name}');
    _resetForm();
  }

  void _resetForm() {
    setState(() {
      _selectedCoordinator = null;
      _requestType = null;
      _remarksController.clear();
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Coordinator Request'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/reservationMain');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _intro(fontSettings),
                  const SizedBox(height: 20),
                  _sectionTitle('Coordinator'),
                  const SizedBox(height: 10),
                  _coordinatorField(fontSettings),
                  const SizedBox(height: 20),
                  _sectionTitle('Request Type'),
                  const SizedBox(height: 4),
                  Text(
                    'What should the coordinator book?',
                    style: TextStyle(
                      fontSize: fontSettings.fontSize - 4,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _requestTypeSelector(fontSettings),
                  const SizedBox(height: 20),
                  _remarksField(fontSettings),
                  const SizedBox(height: 24),
                  _submitButton(fontSettings),
                ],
              ),
            ),
            if (_isSaving)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _intro(FontSettings fontSettings) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.support_agent, color: Colors.indigo.shade400),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ask a coordinator to make the reservation on your behalf. '
              'Pick who should handle it and what needs to be booked.',
              style: TextStyle(
                fontSize: fontSettings.fontSize - 4,
                color: Colors.indigo.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      );

  /// An InputDecorator wrapping a plain DropdownButton rather than a
  /// DropdownButtonFormField: the field is fully controlled, so clearing it on
  /// reset actually empties it — the FormField's initialValue would not.
  Widget _coordinatorField(FontSettings fontSettings) {
    return InputDecorator(
      isEmpty: _selectedCoordinator == null,
      decoration: InputDecoration(
        labelText: 'Select Coordinator *',
        labelStyle: TextStyle(
          fontSize: fontSettings.fontSize,
          fontWeight: fontSettings.fontWeight,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        prefixIcon: const Icon(Icons.person_outline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CoordinatorOption>(
          value: _selectedCoordinator,
          isExpanded: true,
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: fontSettings.fontWeight,
            color: Colors.black,
          ),
          items: _coordinators
              .map(
                (c) => DropdownMenuItem<CoordinatorOption>(
                  value: c,
                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedCoordinator = value),
        ),
      ),
    );
  }

  Widget _requestTypeSelector(FontSettings fontSettings) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CoordinatorRequestType.values.map((type) {
        final selected = _requestType == type;
        return ChoiceChip(
          avatar: Icon(
            type.icon,
            size: 18,
            color: selected ? Colors.white : Colors.black54,
          ),
          label: Text(type.label),
          selected: selected,
          selectedColor: Constants.kPrimaryColor,
          labelStyle: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontSize: fontSettings.fontSize - 4,
            fontWeight: selected ? FontWeight.bold : fontSettings.fontWeight,
          ),
          onSelected: (_) => setState(() => _requestType = type),
        );
      }).toList(),
    );
  }

  Widget _remarksField(FontSettings fontSettings) {
    return TextFormField(
      controller: _remarksController,
      maxLines: 4,
      style: TextStyle(
        fontSize: fontSettings.fontSize,
        fontWeight: fontSettings.fontWeight,
      ),
      decoration: InputDecoration(
        labelText: 'Remarks',
        hintText: 'Dates, flight or hotel preferences, anything else',
        labelStyle: TextStyle(
          fontSize: fontSettings.fontSize,
          fontWeight: fontSettings.fontWeight,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      ),
    );
  }

  Widget _submitButton(FontSettings fontSettings) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _submit,
        icon: const Icon(Icons.send),
        label: Text(
          'Send Request',
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Constants.kPrimaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
