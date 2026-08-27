import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Decodes a Google-encoded polyline string into map points. Same algorithm
/// as moto_driver's DirectionsService.decode — kept here as a standalone
/// utility since the passenger app doesn't call the Directions API itself,
/// it just renders the polyline the backend already computed and returns on
/// GET /api/travels/{id} (TravelRouteResponse.EncodedPolyline).
List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  int index = 0;
  int lat = 0;
  int lng = 0;

  while (index < encoded.length) {
    int b;
    int shift = 0;
    int result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    points.add(LatLng(lat / 1E5, lng / 1E5));
  }

  return points;
}
