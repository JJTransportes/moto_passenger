import 'package:flutter/material.dart';
import 'package:moto_passenger/design_system/design_system.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/travel_summary_entity.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/widgets/travel_list_item.dart';

class LastTravelsCard extends StatelessWidget {
  final List<TravelSummaryEntity> travels;

  const LastTravelsCard({super.key, required this.travels});

  @override
  Widget build(BuildContext context) {
    final moto = context.moto;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height,
      width: MediaQuery.sizeOf(context).width,
      child: MotoGlass(
        painted: true,
        padding: const EdgeInsets.all(MotoSpace.s4),
        child: ListView(
          children: [
            Text('Últimas viagens', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: MotoSpace.s3),
            if (travels.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Nenhuma viagem realizada ainda',
                    style: TextStyle(color: moto.textSecondary),
                  ),
                ),
              )
            else
              ...travels.map((t) => TravelListItem(travel: t)),
          ],
        ),
      ),
    );
  }
}
