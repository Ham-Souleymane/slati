import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONFIGURATION — paste your Google Places API key here
// ─────────────────────────────────────────────────────────────────────────────
const String kGooglePlacesApiKey = 'AIzaSyBMMo9JBVk3k5HDxJvevnLlZv-LdUE8X40';

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
  });

  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;
}

class PlaceDetails {
  const PlaceDetails({
    required this.latLng,
    required this.address,
  });

  final LatLng latLng;
  final String address;
}

// ─────────────────────────────────────────────────────────────────────────────
// Google Places Service
// ─────────────────────────────────────────────────────────────────────────────

class GooglePlacesService {
  static const _autocompleteUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const _detailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';

  Map<String, String> get _headers {
    final headers = <String, String>{};
    try {
      if (Platform.isAndroid) {
        headers['X-Android-Package'] = 'com.slatk.slatkapp';
        headers['X-Android-Cert'] = '695C0FEEC408540F5ACCABFED1B0A2B77D44DAE8';
      } else if (Platform.isIOS) {
        headers['X-Ios-Bundle-Identifier'] = 'com.slatk.slatkapp';
      }
    } catch (_) {}
    return headers;
  }

  /// Returns address suggestions for the given [query].
  /// Optionally biased around [locationBias] (lat,lng) with [radiusMeters].
  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    LatLng? locationBias,
    int radiusMeters = 50000,
    String language = 'ar',
  }) async {
    if (query.trim().isEmpty) return [];

    final params = {
      'input': query,
      'key': kGooglePlacesApiKey,
      'language': language,
      'types': 'geocode|establishment',
    };

    if (locationBias != null) {
      params['location'] = '${locationBias.latitude},${locationBias.longitude}';
      params['radius'] = radiusMeters.toString();
    }

    try {
      final uri = Uri.parse(_autocompleteUrl).replace(queryParameters: params);
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 'OK') return [];

      final predictions = json['predictions'] as List<dynamic>;
      return predictions
          .map((p) => PlaceSuggestion(
                placeId: p['place_id'] as String,
                mainText: (p['structured_formatting']?['main_text'] ?? p['description']) as String,
                secondaryText: (p['structured_formatting']?['secondary_text'] ?? '') as String,
                fullText: p['description'] as String,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches the lat/lng and formatted address for a [placeId].
  Future<PlaceDetails?> getDetails(String placeId, {String language = 'ar'}) async {
    final params = {
      'place_id': placeId,
      'key': kGooglePlacesApiKey,
      'fields': 'geometry,formatted_address',
      'language': language,
    };

    try {
      final uri = Uri.parse(_detailsUrl).replace(queryParameters: params);
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 'OK') return null;

      final result = json['result'] as Map<String, dynamic>;
      final location = result['geometry']['location'] as Map<String, dynamic>;
      final address = result['formatted_address'] as String? ?? '';

      return PlaceDetails(
        latLng: LatLng(
          (location['lat'] as num).toDouble(),
          (location['lng'] as num).toDouble(),
        ),
        address: address,
      );
    } catch (_) {
      return null;
    }
  }
}
