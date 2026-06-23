import 'package:moto_passenger/modules/passenger_home/domain/entities/travel_summary_entity.dart';

class TravelSummaryModel {
  final String travelId;
  final String orderId;
  final String status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? driverName;
  final String? passengerName;
  final int totalDistanceInMeters;
  final int totalTravelTimeInMinutes;

  const TravelSummaryModel({
    required this.travelId,
    required this.orderId,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.driverName,
    this.passengerName,
    required this.totalDistanceInMeters,
    required this.totalTravelTimeInMinutes,
  });

  factory TravelSummaryModel.fromJson(Map<String, dynamic> json) {
    return TravelSummaryModel(
      travelId: json['travelId'] as String,
      orderId: json['orderId'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      finishedAt: json['finishedAt'] != null
          ? DateTime.parse(json['finishedAt'] as String)
          : null,
      driverName: json['driverName'] as String?,
      passengerName: json['passengerName'] as String?,
      totalDistanceInMeters: json['totalDistanceInMeters'] as int,
      totalTravelTimeInMinutes: json['totalTravelTimeInMinutes'] as int,
    );
  }

  TravelSummaryEntity toEntity() {
    return TravelSummaryEntity(
      travelId: travelId,
      driverName: driverName,
      status: status,
      createdAt: createdAt,
      startedAt: startedAt,
      finishedAt: finishedAt,
    );
  }
}

class PaginatedTravelListModel {
  final List<TravelSummaryModel> items;
  final int page;
  final int pageSize;
  final int totalCount;

  const PaginatedTravelListModel({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  factory PaginatedTravelListModel.fromJson(Map<String, dynamic> json) {
    return PaginatedTravelListModel(
      items: (json['items'] as List)
          .map((e) =>
              TravelSummaryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int,
      pageSize: json['pageSize'] as int,
      totalCount: json['totalCount'] as int,
    );
  }
}
