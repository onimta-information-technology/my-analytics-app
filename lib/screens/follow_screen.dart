import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/providers/follow_up_provider.dart';

/// Contact status options. The customer response section is only shown when
/// the status is [_kContacted].
const String _kContacted = 'Contacted';
const String _kNotReachable = 'Not Reachable';
const String _kNoAnswer = 'No Answer';
const List<String> _kContactStatuses = <String>[
  _kContacted,
  _kNotReachable,
  _kNoAnswer,
  'Wrong Number',
];

/// Statuses that require the marketer to keep following up. When one of these
/// is selected we surface a reminder to retry until Day 7.
const List<String> _kRetryStatuses = <String>[_kNotReachable, _kNoAnswer];

/// Positive customer responses (no mandatory remarks).
const List<String> _kPositiveResponses = <String>[
  'Interested in hearing promotions',
  'Interested in visiting',
];

/// Negative customer responses (remarks field is mandatory).
const List<String> _kNegativeResponses = <String>[
  'Not interested',
  'Bad experience',
  'Already visits another casino',
  'Financial reasons',
  'Health reasons',
  'Other',
];

/// Checklist items the marketer must confirm on a positive follow-up.
const List<String> _kPositiveChecklist = <String>[
  'Explained latest packages',
  'Explained promotions',
  'Discussed VIP benefits',
  'Proposed travel dates',
  'Planned visit date',
];

/// Status options for a positive follow-up.
const List<String> _kPositiveStatuses = <String>[
  'Visit Planned',
  'Package Opened',
  'Customer Confirmed',
];

class FollowScreen extends ConsumerStatefulWidget {
  final String memberId;
  final String memberName;
  final void Function(
    File? photo,
    String description,
    String contactStatus,
    String? customerResponse,
    String? remarks,
  )? onSubmit;

  const FollowScreen({
    super.key,
    required this.memberId,
    required this.memberName,
    this.onSubmit,
  });

  @override
  ConsumerState<FollowScreen> createState() => _FollowScreenState();
}

class _FollowScreenState extends ConsumerState<FollowScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _packageOfferedController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isSubmitting = false;
  String? _contactStatus;
  // Response type toggle: true = Negative, false = Positive.
  bool _isNegativeType = false;
  String? _customerResponse;

  // Positive follow-up fields.
  final Set<String> _checkedItems = <String>{};
  DateTime? _plannedVisitDate;
  DateTime? _followUpDate;
  String? _positiveStatus;

  bool get _isContacted => _contactStatus == _kContacted;
  bool get _isRetryStatus =>
      _contactStatus != null && _kRetryStatuses.contains(_contactStatus);
  bool get _isNegativeResponse =>
      _customerResponse != null && _kNegativeResponses.contains(_customerResponse);
  bool get _isPositiveResponse =>
      _customerResponse != null && _kPositiveResponses.contains(_customerResponse);

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_descriptionController.text.trim().isEmpty) {
      _showError('Please add a description');
      return;
    }

    if (_contactStatus == null) {
      _showError('Please select a contact status');
      return;
    }

    if (_isContacted && _customerResponse == null) {
      _showError('Please select a customer response');
      return;
    }

    if (_isContacted && _isNegativeResponse &&
        _remarksController.text.trim().isEmpty) {
      _showError('Please add remarks for a negative response');
      return;
    }

    if (_isContacted && _isPositiveResponse) {
      if (_checkedItems.length != _kPositiveChecklist.length) {
        _showError('Please confirm all positive follow-up items');
        return;
      }
      if (_positiveStatus == null) {
        _showError('Please select a status');
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final String? customerResponse = _isContacted ? _customerResponse : null;
    final String? remarks =
        _isContacted && _isNegativeResponse ? _remarksController.text.trim() : null;
    final String? responseType =
        _isContacted ? (_isNegativeType ? 'Negative' : 'Positive') : null;
    final List<String> checklistItems =
        _isContacted && _isPositiveResponse ? _checkedItems.toList() : const <String>[];
    final String? positiveStatus =
        _isContacted && _isPositiveResponse ? _positiveStatus : null;

    try {
      await ref.read(followUpRepositoryProvider).saveFollowUp(
            memberId: widget.memberId,
            memberName: widget.memberName,
            description: _descriptionController.text.trim(),
            contactStatus: _contactStatus!,
            responseType: responseType,
            customerResponse: customerResponse,
            remarks: remarks,
            checklistItems: checklistItems,
            positiveStatus: positiveStatus,
            plannedVisitDate: _plannedVisitDate,
            followUpDate: _followUpDate,
            photo: _selectedImage,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError('Failed to save follow-up: $e');
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    widget.onSubmit?.call(
      _selectedImage,
      _descriptionController.text.trim(),
      _contactStatus!,
      customerResponse,
      remarks,
    );

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Follow-up saved'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Opens the response picker. The Positive/Negative toggle sits at the top
  /// of the sheet and switches which options are listed below it.
  Future<void> _showResponsePicker() async {
    // Local copies so the sheet's toggle updates instantly without touching
    // the dialog state until the user actually picks a value.
    bool sheetIsNegative = _isNegativeType;

    final String? picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final List<String> options =
                sheetIsNegative ? _kNegativeResponses : _kPositiveResponses;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Response',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildResponseTypeButton(
                            label: 'Positive',
                            selected: !sheetIsNegative,
                            selectedColor: Colors.green,
                            onTap: () => setSheetState(() => sheetIsNegative = false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildResponseTypeButton(
                            label: 'Negative',
                            selected: sheetIsNegative,
                            selectedColor: Colors.red,
                            onTap: () => setSheetState(() => sheetIsNegative = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: options
                            .map((option) => ListTile(
                                  title: Text(option),
                                  trailing: _customerResponse == option &&
                                          _isNegativeType == sheetIsNegative
                                      ? const Icon(Icons.check, color: Colors.green)
                                      : null,
                                  onTap: () => Navigator.of(context).pop(option),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // The toggle position may have changed even without a selection.
    if (!mounted) return;
    setState(() {
      _isNegativeType = sheetIsNegative;
      if (picked != null) {
        _customerResponse = picked;
        if (_isNegativeResponse) {
          // A negative response was chosen; drop any positive follow-up data.
          _resetPositiveFollowUp();
        } else {
          _remarksController.clear();
        }
      }
    });
  }

  Widget _buildResponseTypeButton({
    required String label,
    required bool selected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? selectedColor.withValues(alpha: 0.12) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? selectedColor : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: selected ? selectedColor : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  /// Clears every field in the positive follow-up section.
  void _resetPositiveFollowUp() {
    _checkedItems.clear();
    _plannedVisitDate = null;
    _followUpDate = null;
    _positiveStatus = null;
    _packageOfferedController.clear();
  }

  /// Opens a date picker and returns the selected date via [onPicked].
  Future<void> _pickDate(DateTime? current, ValueChanged<DateTime> onPicked) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  /// A tappable, dropdown-styled field that shows a picked date or a hint.
  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null ? 'Select date' : _formatDate(value),
                style: TextStyle(
                  color: value == null ? Colors.grey.shade600 : Colors.black87,fontSize: 20
                ),
              ),
            ),
            const Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _remarksController.dispose();
    _packageOfferedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add Follow-up'),
        backgroundColor: Constants.kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _showImageSourceSheet,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_selectedImage!, fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 36, color: const Color.fromARGB(255, 0, 0, 0)),
                            const SizedBox(height: 8),
                            Text('Tap to add a photo', style: TextStyle(color: const Color.fromARGB(255, 0, 0, 0))),
                          ],
                        ),
                ),
              ),
              if (_selectedImage != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _selectedImage = null),
                    icon: const Icon(Icons.close, size: 18, color: Colors.red),
                    label: const Text('Remove photo', style: TextStyle(color: Colors.red)),
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Add description',
                  hintStyle: TextStyle(color: const Color.fromARGB(255, 0, 0, 0), fontSize: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Contact Status *',
                style: TextStyle(
                  color: Color.fromARGB(255, 0, 0, 0),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  children: _kContactStatuses
                      .map((status) => _RadioListItem(
                            label: status,
                            value: status,
                            groupValue: _contactStatus,
                            onChanged: (value) {
                              setState(() {
                                _contactStatus = value;
                                // Reset the customer response section when
                                // leaving "Contacted".
                                if (value != _kContacted) {
                                  _customerResponse = null;
                                  _isNegativeType = false;
                                  _remarksController.clear();
                                  _resetPositiveFollowUp();
                                }
                              });
                            },
                          ))
                      .toList(),
                ),
              ),
              if (_isRetryStatus) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.amber.shade800),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Please retry until Day 7.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Minimum 3 call attempts (optional).',
                              style: TextStyle(color: Colors.amber.shade900),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_isContacted) ...[
                const SizedBox(height: 16),
                // Dropdown-style field; the Positive/Negative toggle lives
                // inside the picker that opens on tap.
                InkWell(
                  onTap: _showResponsePicker,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Customer Response *',
                      labelStyle: TextStyle(color: const Color.fromARGB(255, 0, 0, 0), fontSize: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _customerResponse ?? 'Select a response',
                            style: TextStyle(
                              color: _customerResponse == null
                                  ? Colors.grey.shade600
                                  : Colors.black87,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                if (_isNegativeResponse) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _remarksController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Remarks *',
                      hintText: 'Add remarks for the negative response',
                      labelStyle: TextStyle(color: const Color.fromARGB(255, 0, 0, 0), fontSize: 20),

                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                if (_isPositiveResponse) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Positive Follow-up',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Please update the following:',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ..._kPositiveChecklist.map(
                    (item) => CheckboxListTile(
                      value: _checkedItems.contains(item),
                      title: Text(item, style: const TextStyle(fontSize: 16)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _checkedItems.add(item);
                          } else {
                            _checkedItems.remove(item);
                          }
                        });
                      },
                    ),
                  ),
                  // const SizedBox(height: 12),
                  // _buildDateField(
                  //   label: 'Planned Visit Date',
                  //   value: _plannedVisitDate,
                  //   onTap: () => _pickDate(
                  //     _plannedVisitDate,
                  //     (d) => _plannedVisitDate = d,
                  //   ),
                  // ),
                  // const SizedBox(height: 16),
                  // TextField(
                  //   controller: _packageOfferedController,
                  //   decoration: InputDecoration(
                  //     labelText: 'Package Offered',
                  //     hintText: 'Enter the package offered',
                  //     border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  //   ),
                  // ),
                  // const SizedBox(height: 16),
                  // _buildDateField(
                  //   label: 'Follow-up Date',
                  //   value: _followUpDate,
                  //   onTap: () => _pickDate(
                  //     _followUpDate,
                  //     (d) => _followUpDate = d,
                  //   ),
                  // ),
                  // const SizedBox(height: 16),
                  const Text(
                    'Status',
                    style: TextStyle(
                      color: Color.fromARGB(255, 0, 0, 0),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      children: _kPositiveStatuses
                          .map((status) => _RadioListItem(
                                label: status,
                                value: status,
                                groupValue: _positiveStatus,
                                onChanged: (value) =>
                                    setState(() => _positiveStatus = value),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Constants.kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit'),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single radio option row, matching the style used on the
/// Customer Due Diligence screen.
class _RadioListItem extends StatelessWidget {
  final String label;
  final String value;
  final String? groupValue;
  final ValueChanged<String> onChanged;

  const _RadioListItem({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = groupValue == value;
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
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