import 'package:flutter/material.dart';
import 'package:moto_passenger/design_system/design_system.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/travel_summary_entity.dart';

class CurrentTravelCard extends StatelessWidget {
  final TravelSummaryEntity travel;
  final VoidCallback? onTap;

  const CurrentTravelCard({
    super.key,
    required this.travel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEmAndamento = travel.status == 'InProgress';
    final moto = context.moto;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: moto.borderDefault),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Viagem Atual',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: moto.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, color: moto.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Destino da viagem',
                      style: TextStyle(
                        color: moto.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.timer_outlined, color: moto.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isEmAndamento ? 'Em andamento' : 'Aguardando início',
                    style: TextStyle(
                      color: moto.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isEmAndamento ? moto.successSoft : moto.warningSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isEmAndamento ? 'Em andamento' : 'Aceita',
                  style: TextStyle(
                    color: isEmAndamento ? moto.success : moto.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
