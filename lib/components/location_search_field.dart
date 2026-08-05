import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ballys_reservation_app/data/services/places_service.dart';

/// A read-only field that opens a Google Places search sheet.
///
/// The typed term can always be accepted as-is, so a location can still be
/// entered when Places returns nothing.
class LocationSearchField extends StatelessWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final TextStyle textStyle;
  final Color accent;
  final String sheetTitle;

  /// Called with the picked description and its place id (empty for free text).
  final void Function(String description, String placeId) onSelected;

  final FormFieldValidator<String>? validator;

  /// When false the search sheet can't be opened and the value shown is left
  /// alone — for callers that fill the field from somewhere else.
  final bool enabled;

  const LocationSearchField({
    super.key,
    required this.controller,
    required this.decoration,
    required this.textStyle,
    required this.accent,
    required this.sheetTitle,
    required this.onSelected,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: textStyle,
      maxLines: 2,
      minLines: 1,
      validator: validator,
      decoration: decoration.copyWith(
        suffixIcon: !enabled
            ? null
            : controller.text.isEmpty
            ? Icon(Icons.search, color: accent)
            : IconButton(
                icon: Icon(Icons.clear, color: accent),
                onPressed: () => onSelected('', ''),
              ),
      ),
      onTap: !enabled
          ? null
          : () async {
              final result = await showModalBottomSheet<PlacePrediction>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => _PlaceSearchSheet(
                  title: sheetTitle,
                  accent: accent,
                  initialTerm: controller.text,
                ),
              );
              if (result != null) {
                onSelected(result.description, result.placeId);
              }
            },
    );
  }
}

class _PlaceSearchSheet extends StatefulWidget {
  final String title;
  final Color accent;
  final String initialTerm;

  const _PlaceSearchSheet({
    required this.title,
    required this.accent,
    required this.initialTerm,
  });

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final _places = PlacesService();
  final _searchCtrl = TextEditingController();

  Timer? _debounce;
  List<PlacePrediction> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.initialTerm;
    if (widget.initialTerm.trim().length >= 3) _search(widget.initialTerm);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String term) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(term));
    setState(() {});
  }

  Future<void> _search(String term) async {
    if (term.trim().length < 3) {
      setState(() {
        _results = [];
        _loading = false;
        _searched = false;
        _error = null;
      });
      return;
    }
    setState(() => _loading = true);
    final result = await _places.autocomplete(term);
    if (!mounted) return;
    setState(() {
      _results = result.predictions;
      _error = result.error;
      _loading = false;
      _searched = true;
    });
  }

  void _useFreeText() {
    final term = _searchCtrl.text.trim();
    if (term.isEmpty) return;
    Navigator.pop(
      context,
      PlacePrediction(
        description: term,
        placeId: '',
        mainText: term,
        secondaryText: '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final typed = _searchCtrl.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Search a place, hotel or address...',
                  hintStyle: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(Icons.search, color: widget.accent),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: widget.accent, width: 1.8),
                  ),
                ),
                onChanged: _onChanged,
                onSubmitted: (_) => _useFreeText(),
              ),
            ),
            const SizedBox(height: 8),
            if (_loading) LinearProgressIndicator(color: widget.accent),
            Expanded(child: _body(typed)),
            if (typed.isNotEmpty)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _useFreeText,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: widget.accent,
                        side: BorderSide(color: widget.accent, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.edit_location_alt_outlined),
                      label: Text(
                        'Use "$typed"',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(String typed) {
    if (typed.length < 3) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Type at least 3 characters to search',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  color: Colors.redAccent, size: 32),
              const SizedBox(height: 10),
              const Text(
                'Google Places is unavailable',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontSize: 13),
              ),
              const SizedBox(height: 10),
              const Text(
                'You can still type the location and use it below.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      if (_loading || !_searched) return const SizedBox.shrink();
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No places found — you can still use what you typed',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final p = _results[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: widget.accent.withOpacity(0.12),
            child: Icon(Icons.place_outlined, color: widget.accent, size: 20),
          ),
          title: Text(
            p.mainText,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: p.secondaryText.isEmpty
              ? null
              : Text(
                  p.secondaryText,
                  style: const TextStyle(fontSize: 13, color: Color.fromARGB(255, 0, 0, 0)),
                ),
          onTap: () => Navigator.pop(context, p),
        );
      },
    );
  }
}
