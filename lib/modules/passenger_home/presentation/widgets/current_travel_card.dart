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
    final tripStatus = isEmAndamento ? TripStatus.emAndamento : TripStatus.aceita;

    return GestureDetector(
      onTap: onTap,
      child: MotoGlass(
        painted: true,
        padding: const EdgeInsets.all(MotoSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const MotoTile(icon: Icons.directions_car, accent: true, size: 40),
                const SizedBox(width: MotoSpace.s3),
                Expanded(
                  child: Text('Viagem atual', style: Theme.of(context).textTheme.titleMedium),
                ),
                MotoStatusBadge.trip(tripStatus),
              ],
            ),
            if (travel.driverName != null) ...[
              const SizedBox(height: MotoSpace.s2),
              Row(
                children: [
                  Icon(Icons.person, color: context.moto.textTertiary, size: 18),
                  const SizedBox(width: MotoSpace.s2),
                  Text(travel.driverName!, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ],
            const SizedBox(height: MotoSpace.s3),
            MotoButton(
              label: 'Ver viagem',
              large: false,
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}
