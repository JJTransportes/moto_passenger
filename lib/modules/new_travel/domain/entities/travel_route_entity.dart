class TravelRouteEntity {
  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;
  final String departureAddress;
  final String destinationAddress;
  final int distanceMeters;
  final int timeMinutes;
  final String encodedPolyline;

  const TravelRouteEntity({
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.departureAddress,
    required this.destinationAddress,
    required this.distanceMeters,
    required this.timeMinutes,
    required this.encodedPolyline,
  });
}
