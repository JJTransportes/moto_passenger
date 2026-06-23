import 'package:flutter/material.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/travel_summary_entity.dart';

class TravelListItem extends StatelessWidget {
  final TravelSummaryEntity travel;

  const TravelListItem({super.key, required this.travel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.directions_car,
              color: Color(0xFF4685C0), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(travel.status),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF4E4E4E),
                  ),
                ),
                if (travel.driverName != null)
                  Text(
                    'Motorista: ${travel.driverName}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                Text(
                  _formatDate(travel.createdAt),
                  style: TextStyle(
                    color: Colors.grey.shade500,
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
