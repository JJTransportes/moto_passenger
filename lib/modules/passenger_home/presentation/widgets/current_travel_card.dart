import 'package:flutter/material.dart';
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

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Viagem Atual',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF4E4E4E),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on,
                      color: Color(0xFF4685C0), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Destino da viagem',
                      style: TextStyle(
                        color: Color(0xFF4E4E4E),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      color: Color(0xFF4685C0), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isEmAndamento ? 'Em andamento' : 'Aguardando início',
                    style: const TextStyle(
                      color: Color(0xFF4E4E4E),
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
                  color: isEmAndamento
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isEmAndamento ? 'Em andamento' : 'Aceita',
                  style: TextStyle(
                    color:
                        isEmAndamento ? Colors.green.shade800 : Colors.orange.shade800,
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
