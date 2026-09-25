import 'package:flutter/material.dart';
import 'package:moto_passenger/design_system/design_system.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/travel_summary_entity.dart';

class TravelListItem extends StatelessWidget {
  final TravelSummaryEntity travel;

  const TravelListItem({super.key, required this.travel});

  @override
  Widget build(BuildContext context) {
    final moto = context.moto;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.directions_car, color: moto.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(travel.status),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: moto.textPrimary,
                  ),
                ),
                if (travel.driverName != null)
                  Text(
                    'Motorista: ${travel.driverName}',
                    style: TextStyle(
                      color: moto.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                Text(
                  _formatDate(travel.createdAt),
                  style: TextStyle(
                    color: moto.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Completed':
        return 'Viagem concluída';
      case 'Cancelled':
        return 'Viagem cancelada';
      case 'Accepted':
        return 'Viagem aceita';
      case 'InProgress':
        return 'Viagem em andamento';
      default:
        return 'Viagem';
    }
  }
}
