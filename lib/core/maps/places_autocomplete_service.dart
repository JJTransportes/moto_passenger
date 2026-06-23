// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:moto_passenger/core/maps/i_places_autocomplete_service.dart';

class PlaceDetail {
  final String placeId;
  final double latitude;
  final double longitude;
  final String formattedAddress;

  const PlaceDetail({
    required this.placeId,
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
  });
}

class PlacesAutocompleteService implements IPlacesAutocompleteService {
  final Dio _dio;

  PlacesAutocompleteService(this._dio);

  @override
  Future<PlaceDetail> getPlaceDetails(String placeId) async {
    try {
      final response = await _dio.get('/api/addresses/place-details', queryParameters: {'placeId': placeId});
      final data = response.data as Map<String, dynamic>;
      return PlaceDetail(
        placeId: data['placeId'] as String,
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        formattedAddress: data['formattedAddress'] as String,
      );
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Erro ao obter detalhes do endereço');
    }
  }

  @override
  Future<RouteDetailResult> getRouteDetails({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final response = await _dio.get(
        '/api/routes/details',
        data: [
          {'latitude': originLat, 'longitude': originLng},
          {'latitude': destLat, 'longitude': destLng},
        ],
      );
      final data = response.data as Map<String, dynamic>;
      log(jsonEncode(data));

      final initial = data['initialPoint'] as Map<String, dynamic>;
      final finalPoint = data['finalPoint'] as Map<String, dynamic>;

      return RouteDetailResult(
        departureAddress: initial['address'] as String,
        destinationAddress: finalPoint['address'] as String,
        originLat: (initial['latitude'] as num).toDouble(),
        originLng: (initial['longitude'] as num).toDouble(),
        destLat: (finalPoint['latitude'] as num).toDouble(),
        destLng: (finalPoint['longitude'] as num).toDouble(),
        distanceMeters: (data['distanceBetweenPointsInMeters'] as num).toInt(),
        timeHours: (data['averageTimeBetweenPointsInHours'] as num).toInt(),
        timeMinutes: (data['averageTimeBetweenPointsInMinutes'] as num).toInt(),
        encodedPolyline: data['encodedPolyline'] as String,
      );
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Erro ao calcular rota');
    }
  }

  @override
  Future<List<PlaceSuggestion>> search(String query) async {
    try {
      final response = await _dio.get('/api/routes/coordinates?search=$query');
      final rawData = response.data as List;

      final suggestions = rawData.map((data) {
        final suggestionMap = data as Map<String, dynamic>;
        return PlaceSuggestion.fromMap(suggestionMap);
      }).toList();

      return suggestions;
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Erro ao buscar endereços');
    }
  }
}

class PlaceSuggestion {
  final String address;
  final double latitude;
  final double longitude;

  const PlaceSuggestion({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory PlaceSuggestion.fromMap(Map<String, dynamic> map) {
    return PlaceSuggestion(
      address: map['address'] as String,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
    );
  }
}

class RouteDetailResult {
  final String departureAddress;
  final String destinationAddress;
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final int distanceMeters;
  final int timeHours;
  final int timeMinutes;
  final String encodedPolyline;

  const RouteDetailResult({
    required this.departureAddress,
    required this.destinationAddress,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    required this.distanceMeters,
    required this.timeHours,
    required this.timeMinutes,
    required this.encodedPolyline,
  });
}
