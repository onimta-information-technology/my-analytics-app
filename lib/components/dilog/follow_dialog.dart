import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ballys_reservation_app/core/constants.dart';

/// Contact status options. The customer response section is only shown when
/// the status is [_kContacted].
const String _kContacted = 'Contacted';
const List<String> _kContactStatuses = <String>[
  _kContacted,
  'Not Reachable',
  'No Answer',
  'Wrong Number',
];

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

class FollowDialog extends StatefulWidget {
  final String memberId;
  final void Function(
    File? photo,
    String description,
    String contactStatus,
    String? customerResponse,
    String? remarks,
  )? onSubmit;

  const FollowDialog({
    super.key,
    required this.memberId,
    this.onSubmit,
  });

  @override
  State<FollowDialog> createState() => _FollowDialogState();
}

class _FollowDialogState extends State<FollowDialog> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isSubmitting = false;
  String? _contactStatus;
  String? _customerResponse;

  bool get _isContacted => _contactStatus == _kContacted;
  bool get _isNegativeResponse =>
      _customerResponse != null && _kNegativeResponses.contains(_customerResponse);

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

  /// Non-selectable group header shown inside the customer response dropdown.
  DropdownMenuItem<String> _buildResponseHeader(String label) {
    return DropdownMenuItem<String>(
      enabled: false,
      value: null,
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  DropdownMenuItem<String> _buildResponseItem(String value) {
    return DropdownMenuItem<String>(
      value: value,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Text(value),
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

    setState(() => _isSubmitting = true);

    // TODO: Replace this block with the real API call once the endpoint is ready.
    // Example:
    // await followRepository.submitFollow(
    //   memberId: widget.memberId,
    //   photo: _selectedImage,
    //   description: _descriptionController.text.trim(),
    // );
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() => _isSubmitting = false);

    final String? customerResponse = _isContacted ? _customerResponse : null;
    final String? remarks =
        _isContacted && _isNegativeResponse ? _remarksController.text.trim() : null;

    widget.onSubmit?.call(
      _selectedImage,
      _descriptionController.text.trim(),
      _contactStatus!,
      customerResponse,
      remarks,
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Follow-up saved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Follow-up',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
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
                            Icon(Icons.add_a_photo, size: 36, color: Colors.grey.shade500),
                            const SizedBox(height: 8),
                            Text('Tap to add a photo', style: TextStyle(color: Colors.grey.shade600)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _contactStatus,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Contact Status *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _kContactStatuses
                    .map((status) => DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _contactStatus = value;
                    // Reset the customer response section when leaving "Contacted".
                    if (value != _kContacted) {
                      _customerResponse = null;
                      _remarksController.clear();
                    }
                  });
                },
              ),
              if (_isContacted) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _customerResponse,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Customer Response *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    _buildResponseHeader('Positive Response'),
                    ..._kPositiveResponses.map(_buildResponseItem),
                    _buildResponseHeader('Negative Response'),
                    ..._kNegativeResponses.map(_buildResponseItem),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _customerResponse = value;
                      if (!_isNegativeResponse) {
                        _remarksController.clear();
                      }
                    });
                  },
                ),
                if (_isNegativeResponse) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _remarksController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Remarks *',
                      hintText: 'Add remarks for the negative response',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Constants.kPrimaryColor,
                        foregroundColor: Colors.white,
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}