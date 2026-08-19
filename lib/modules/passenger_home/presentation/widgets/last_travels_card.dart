import 'package:flutter/material.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/travel_summary_entity.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/widgets/travel_list_item.dart';

class LastTravelsCard extends StatelessWidget {
  final List<TravelSummaryEntity> travels;

  const LastTravelsCard({super.key, required this.travels});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height,
      width: MediaQuery.sizeOf(context).width,
      child: Card(
        elevation: 8,
        shadowColor: Colors.white24,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const Text(
                'Últimas Viagens',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF4E4E4E),
                ),
              ),
              const SizedBox(height: 12),
              if (travels.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Nenhuma viagem realizada ainda',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...travels.map((t) => TravelListItem(travel: t)),
            ],
          ),
        ),
      ),
    );
  }
}
