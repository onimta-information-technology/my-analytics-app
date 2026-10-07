import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:ballys_reservation_app/data/services/places_service.dart';

/// What [MapLocationPicker] hands back: the address under the pin and its
/// place id (empty when Geocoding couldn't name the spot).
class MapPickedLocation {
  final String description;
  final String placeId;
  final double lat;
  final double lng;

  const MapPickedLocation({
    required this.description,
    required this.placeId,
    required this.lat,
    required this.lng,
  });
}

/// Full-screen map with a fixed centre pin. The user drags the map under the
/// pin; once the camera settles the spot is reverse geocoded.
class MapLocationPicker extends StatefulWidget {
  final String title;
  final Color accent;

  /// Place id of the current value, so the map opens on it.
  final String initialPlaceId;

  const MapLocationPicker({
    super.key,
    required this.title,
    required this.accent,
    this.initialPlaceId = '',
  });

  static Future<MapPickedLocation?> show(
    BuildContext context, {
    required String title,
    required Color accent,
    String initialPlaceId = '',
  }) {
    return Navigator.of(context).push<MapPickedLocation>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MapLocationPicker(
          title: title,
          accent: accent,
          initialPlaceId: initialPlaceId,
        ),
      ),
    );
  }

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  static const double _zoom = 16;

  final _places = PlacesService();
  GoogleMapController? _map;

  LatLng _target = const LatLng(
    PlacesService.defaultLat,
    PlacesService.defaultLng,
  );
  GeocodedPlace? _place;
  bool _resolving = false;
  bool _moving = false;
  bool _locating = false;

  // Bumped per lookup so a slow reply for an old spot can't overwrite a
  // newer one.
  int _lookup = 0;

  // Set when the camera is flying to a searched place whose name is already
  // known, so the idle after that flight doesn't reverse geocode over it.
  bool _skipNextResolve = false;

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  List<PlacePrediction> _results = [];
  bool _searching = false;
  String? _searchError;
  int _searchSeq = 0;

  @override
  void initState() {
    super.initState();
    // The results panel only shows while the search field has focus.
    _searchFocus.addListener(() {
      if (mounted) setState(() {});
    });
    // _resolve calls setState, which can't run inside initState.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openOnInitialPlace());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _openOnInitialPlace() async {
    if (widget.initialPlaceId.isNotEmpty) {
      final place = await _places.geocodePlaceId(widget.initialPlaceId);
      if (!mounted) return;
      if (place?.lat != null && place?.lng != null) {
        _moveTo(LatLng(place!.lat!, place.lng!));
        return;
      }
    }
    _resolve(_target);
  }

  /// Centres the map on [target]. With [known], that place is shown as-is
  /// instead of reverse geocoding the spot.
  void _moveTo(LatLng target, {GeocodedPlace? known}) {
    _target = target;
    final map = _map;
    if (known != null) {
      _lookup++; // drop any reverse geocode still in flight
      setState(() {
        _place = known;
        _resolving = false;
      });
      if (map == null) return;
      _skipNextResolve = true;
      map.animateCamera(CameraUpdate.newLatLngZoom(target, _zoom));
    } else if (map == null) {
      // onMapCreated moves the camera here once the map exists.
      _resolve(target);
    } else {
      // onCameraIdle resolves the address when the animation ends.
      map.animateCamera(CameraUpdate.newLatLngZoom(target, _zoom));
    }
  }

  Future<void> _resolve(LatLng target) async {
    final lookup = ++_lookup;
    setState(() => _resolving = true);
    final place = await _places.reverseGeocode(
      target.latitude,
      target.longitude,
    );
    if (!mounted || lookup != _lookup) return;
    setState(() {
      _place = place;
      _resolving = false;
    });
  }

  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _toast('Turn on location services to use your current location');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _toast('Location permission is required to use your current location');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      _moveTo(LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      _toast('Could not get your current location');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onSearchChanged(String term) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(term));
    setState(() {});
  }

  Future<void> _search(String term) async {
    final seq = ++_searchSeq;
    if (term.trim().length < 3) {
      setState(() {
        _results = [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() => _searching = true);
    final result = await _places.autocomplete(term);
    if (!mounted || seq != _searchSeq) return;
    setState(() {
      _results = result.predictions;
      _searchError = result.error;
      _searching = false;
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchSeq++;
    _searchCtrl.clear();
    setState(() {
      _results = [];
      _searching = false;
      _searchError = null;
    });
  }

  Future<void> _selectPrediction(PlacePrediction p) async {
    _searchFocus.unfocus();
    _debounce?.cancel();
    final seq = ++_searchSeq;
    setState(() {
      _searchCtrl.text = p.mainText;
      _results = [];
      _searchError = null;
      _searching = true;
    });
    final place = await _places.geocodePlaceId(p.placeId);
    if (!mounted || seq != _searchSeq) return;
    setState(() => _searching = false);
    if (place?.lat == null || place?.lng == null) {
      _toast('Could not find that place on the map');
      return;
    }
    _moveTo(
      LatLng(place!.lat!, place.lng!),
      known: GeocodedPlace(
        address: p.description,
        placeId: p.placeId,
        lat: place.lat,
        lng: place.lng,
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String get _coords =>
      '${_target.latitude.toStringAsFixed(6)}, '
      '${_target.longitude.toStringAsFixed(6)}';

  void _confirm() {
    final address = _place?.address ?? '';
    Navigator.pop(
      context,
      MapPickedLocation(
        description: address.isNotEmpty ? address : _coords,
        placeId: _place?.placeId ?? '',
        lat: _target.latitude,
        lng: _target.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _resolving || _moving;
    final address = _place?.address ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.accent,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _target, zoom: _zoom),
            onMapCreated: (c) {
              _map = c;
              c.moveCamera(CameraUpdate.newLatLngZoom(_target, _zoom));
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onCameraMoveStarted: () => setState(() => _moving = true),
            onCameraMove: (pos) => _target = pos.target,
            onTap: (_) => _searchFocus.unfocus(),
            onCameraIdle: () {
              setState(() => _moving = false);
              if (_skipNextResolve) {
                _skipNextResolve = false;
                return;
              }
              _resolve(_target);
            },
          ),
          // The pin's tip sits on the map centre.
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 44),
                child: Icon(Icons.location_on, size: 48, color: widget.accent),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 190,
            child: FloatingActionButton.small(
              heroTag: null,
              backgroundColor: Colors.white,
              foregroundColor: widget.accent,
              onPressed: _locating ? null : _goToMyLocation,
              child: _locating
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.accent,
                      ),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.place_outlined, color: widget.accent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: busy
                                ? const Text(
                                    'Finding address...',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 15,
                                    ),
                                  )
                                : Text(
                                    address.isNotEmpty ? address : _coords,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: busy ? null : _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Confirm Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: _searchBar(),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    final typed = _searchCtrl.text.trim();
    final showPanel = _searchFocus.hasFocus && typed.length >= 3;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              hintText: 'Search a place, hotel or address...',
              hintStyle: const TextStyle(color: Colors.black54, fontSize: 15),
              prefixIcon: Icon(Icons.search, color: widget.accent),
              suffixIcon: typed.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.clear, color: widget.accent),
                      onPressed: _clearSearch,
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: _onSearchChanged,
            onSubmitted: (_) {
              if (_results.isNotEmpty) _selectPrediction(_results.first);
            },
          ),
          if (_searching) LinearProgressIndicator(color: widget.accent),
          if (showPanel) _searchResults(),
        ],
      ),
    );
  }

  Widget _searchResults() {
    if (_searchError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _searchError!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
        ),
      );
    }
    if (_results.isEmpty) {
      if (_searching) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No places found — move the map to pick the spot',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _results.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final p = _results[i];
          return ListTile(
            dense: true,
            leading: Icon(Icons.place_outlined, color: widget.accent),
            title: Text(
              p.mainText,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: p.secondaryText.isEmpty
                ? null
                : Text(
                    p.secondaryText,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
            onTap: () => _selectPrediction(p),
          );
        },
      ),
    );
  }
}
