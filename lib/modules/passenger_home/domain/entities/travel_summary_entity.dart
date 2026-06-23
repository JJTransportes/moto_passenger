class TravelSummaryEntity {
  final String travelId;
  final String? driverName;
  final String status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  const TravelSummaryEntity({
    required this.travelId,
    this.driverName,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
  });

  bool get isActive => status == 'Accepted' || status == 'InProgress';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TravelSummaryEntity &&
          runtimeType == other.runtimeType &&
          travelId == other.travelId &&
          driverName == other.driverName &&
          status == other.status &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      travelId.hashCode ^
      driverName.hashCode ^
      status.hashCode ^
      createdAt.hashCode;
}
