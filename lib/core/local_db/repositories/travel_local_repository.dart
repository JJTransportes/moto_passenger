import 'package:moto_passenger/core/local_db/local_database_service.dart';
import 'package:moto_passenger/core/local_db/models/local_data_models.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/travel_summary_entity.dart';

class TravelLocalRepository {
  Future<void> cacheTravels(List<TravelSummaryEntity> travels) async {
    try {
      final db = LocalDatabaseService.instance;
      final batch = db.batch();

      batch.delete('travels');

      for (final t in travels) {
        batch.insert('travels', {
          'travel_id': t.travelId,
          'status': t.status,
          'driver_name': t.driverName,
          'created_at': t.createdAt.toIso8601String(),
          'started_at': t.startedAt?.toIso8601String(),
          'finished_at': t.finishedAt?.toIso8601String(),
        });
      }

      await batch.commit(noResult: true);
    } catch (_) {}
  }

  Future<List<TravelLocalData>> getCachedTravels() async {
    try {
      final db = LocalDatabaseService.instance;
      final rows = await db.query('travels', orderBy: 'created_at DESC');
      return rows.map((r) => TravelLocalData.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveActiveTravel(TravelSummaryEntity? travel) async {
    try {
      final db = LocalDatabaseService.instance;
      await db.delete('active_travel');
      if (travel == null) return;

      await db.insert('active_travel', {
        'id': 1,
        'travel_id': travel.travelId,
        'status': travel.status,
        'driver_name': travel.driverName,
        'created_at': travel.createdAt.toIso8601String(),
      });
    } catch (_) {}
  }

  Future<TravelLocalData?> getActiveTravel() async {
    try {
      final db = LocalDatabaseService.instance;
      final rows = await db.query('active_travel', limit: 1);
      if (rows.isEmpty) return null;
      return TravelLocalData.fromMap(rows.first);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearTravels() async {
    try {
      final db = LocalDatabaseService.instance;
      await Future.wait([
        db.delete('travels'),
        db.delete('active_travel'),
      ]);
    } catch (_) {}
  }
}
