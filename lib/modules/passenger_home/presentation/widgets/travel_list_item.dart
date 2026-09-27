import 'package:flutter/material.dart';
import 'package:moto_passenger/design_system/design_system.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/travel_summary_entity.dart';

class TravelListItem extends StatelessWidget {
  final TravelSummaryEntity travel;

  const TravelListItem({super.key, required this.travel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MotoSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MotoTile(icon: Icons.directions_car, tone: _statusTone(travel.status)),
          const SizedBox(width: MotoSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (travel.driverName != null)
                  Text(travel.driverName!, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                MotoStatusBadge.trip(_tripStatus(travel.status)),
              ],
            ),
          ),
          Text(_formatDate(travel.createdAt), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  MotoTone _statusTone(String status) {
    switch (status) {
      case 'Completed': return MotoTone.success;
      case 'Cancelled': return MotoTone.danger;
      case 'InProgress': return MotoTone.info;
      default: return MotoTone.warning;
    }
  }

  TripStatus _tripStatus(String status) {
    switch (status) {
      case 'Completed': return TripStatus.concluida;
      case 'Cancelled': return TripStatus.cancelada;
      case 'InProgress': return TripStatus.emAndamento;
      case 'Accepted': return TripStatus.aceita;
      default: return TripStatus.solicitada;
    }
  }
}
