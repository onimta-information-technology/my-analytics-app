import 'dart:convert';

import 'package:http/http.dart' as http;

/// One autocomplete suggestion returned by Google Places.
class PlacePrediction {
  final String description;
  final String placeId;
  final String mainText;
  final String secondaryText;

  const PlacePrediction({
    required this.description,
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });
}

/// Outcome of an autocomplete lookup.
///
/// [error] is non-null when Google rejected the request (bad key, billing off,
/// API not enabled), so the UI can say why instead of showing "no results".
class PlacesResult {
  final List<PlacePrediction> predictions;
  final String? error;

  const PlacesResult({this.predictions = const [], this.error});

  bool get failed => error != null;
}

/// Google Places autocomplete lookups.
///
/// Tries the Places API (New) first and falls back to the legacy
/// `maps/api/place/autocomplete` endpoint, since a key may only be enabled for
/// one of the two.
class PlacesService {
  static const String _apiKey = 'AIzaSyDETWXoAvfKzF2H6zuZMQ9mBq3kyWI_W48';

  // Results are biased (not restricted) towards Colombo.
  static const double _biasLat = 6.9271;
  static const double _biasLng = 79.8612;
  static const double _biasRadiusMeters = 50000;

  Future<PlacesResult> autocomplete(String input) async {
    final term = input.trim();
    if (term.length < 3) return const PlacesResult();

    final viaNewApi = await _autocompleteNewApi(term);
    if (viaNewApi != null && !viaNewApi.failed) return viaNewApi;

    final viaLegacy = await _autocompleteLegacyApi(term);
    if (viaLegacy != null && !viaLegacy.failed) return viaLegacy;

    // Both endpoints refused — report whichever reason we have.
    return viaLegacy ??
        viaNewApi ??
        const PlacesResult(error: 'Could not reach Google Places.');
  }

  /// Returns null on a transport-level failure. A [PlacesResult] with an
  /// [error] means Google answered but rejected the request.
  Future<PlacesResult?> _autocompleteNewApi(String input) async {
    try {
      final res = await http.post(
        Uri.parse('https://places.googleapis.com/v1/places:autocomplete'),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
        },
        body: jsonEncode({
          'input': input,
          'locationBias': {
            'circle': {
              'center': {'latitude': _biasLat, 'longitude': _biasLng},
              'radius': _biasRadiusMeters,
            },
          },
        }),
      );
      if (res.statusCode != 200) {
        return PlacesResult(error: _errorFromNewApi(res.body));
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final suggestions = (data['suggestions'] as List?) ?? [];
      final predictions = suggestions
          .map((s) => (s as Map<String, dynamic>)['placePrediction']
              as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .map((p) {
            final format = p['structuredFormat'] as Map<String, dynamic>?;
            final main = (format?['mainText'] as Map<String, dynamic>?)?['text']
                    as String? ??
                '';
            final secondary =
                (format?['secondaryText'] as Map<String, dynamic>?)?['text']
                        as String? ??
                    '';
            final text =
                (p['text'] as Map<String, dynamic>?)?['text'] as String? ?? '';
            return PlacePrediction(
              description: text.isNotEmpty
                  ? text
                  : [main, secondary].where((e) => e.isNotEmpty).join(', '),
              placeId: p['placeId'] as String? ?? '',
              mainText: main.isNotEmpty ? main : text,
              secondaryText: secondary,
            );
          })
          .toList();
      return PlacesResult(predictions: predictions);
    } catch (_) {
      return null;
    }
  }

  String _errorFromNewApi(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>?;
      final msg = error?['message'] as String?;
      if (msg != null && msg.isNotEmpty) return msg;
    } catch (_) {}
    return 'Google Places rejected the request.';
  }

  Future<PlacesResult?> _autocompleteLegacyApi(String input) async {
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': input,
          'key': _apiKey,
          'location': '$_biasLat,$_biasLng',
          'radius': _biasRadiusMeters.toStringAsFixed(0),
        },
      );
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        final msg = data['error_message'] as String?;
        return PlacesResult(
          error: (msg != null && msg.isNotEmpty)
              ? msg
              : 'Google Places rejected the request ($status).',
        );
      }

      final raw = (data['predictions'] as List?) ?? [];
      final predictions = raw.map((p) {
        final m = p as Map<String, dynamic>;
        final format = m['structured_formatting'] as Map<String, dynamic>?;
        return PlacePrediction(
          description: m['description'] as String? ?? '',
          placeId: m['place_id'] as String? ?? '',
          mainText: format?['main_text'] as String? ??
              m['description'] as String? ??
              '',
          secondaryText: format?['secondary_text'] as String? ?? '',
        );
      }).toList();
      return PlacesResult(predictions: predictions);
    } catch (_) {
      return null;
    }
  }
}
