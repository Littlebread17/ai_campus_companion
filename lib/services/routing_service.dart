import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Result of a walking-route lookup.
class WalkingRoute {
  /// Ordered points that draw the route line on the map.
  final List<LatLng> points;

  /// Total walking distance in metres.
  final double distanceMeters;

  /// Estimated walking time in seconds.
  final double durationSeconds;

  const WalkingRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  String get distanceLabel {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
  }

  String get etaLabel {
    final minutes = (durationSeconds / 60).ceil();
    if (minutes <= 1) return '1 min walk';
    return '$minutes min walk';
  }
}

/// Fetches walking routes from the free public OSRM server.
///
/// No API key or billing is required. If the request fails (offline, server
/// down), callers should fall back to a straight line between the two points.
class RoutingService {
  static const _base = 'https://router.project-osrm.org/route/v1/foot';

  Future<WalkingRoute?> getWalkingRoute(LatLng from, LatLng to) async {
    final url = Uri.parse(
      '$_base/${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List<dynamic>;

      // GeoJSON stores coordinates as [longitude, latitude].
      final points = coords
          .map(
            (c) => LatLng(
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            ),
          )
          .toList();

      return WalkingRoute(
        points: points,
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
