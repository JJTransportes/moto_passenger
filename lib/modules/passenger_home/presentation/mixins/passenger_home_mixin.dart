import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/auth/sign_out_service.dart';
import 'package:moto_passenger/core/theme/app_theme.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/passenger_profile_entity.dart';
import 'package:moto_passenger/modules/passenger_home/domain/entities/travel_summary_entity.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/blocs/passenger_home_bloc.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/blocs/passenger_home_event.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/pages/passenger_home_page.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/widgets/current_travel_card.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/widgets/last_travels_card.dart';
import 'package:moto_passenger/modules/passenger_home/presentation/widgets/profile_header.dart';

mixin PassengerHomeMixin on State<PassengerHomePage> {
  Widget buildContent(
    PassengerProfileEntity profile,
    TravelSummaryEntity? currentTravel,
    List<TravelSummaryEntity> lastTravels,
  ) => RefreshIndicator(
    onRefresh: () async {
      BlocProvider.of<PassengerHomeBloc>(context).add(const RefreshPassengerHome());
    },
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileHeader(
            fullName: profile.fullName,
            onSignOut: () => _handleSignOut(context),
            onSettings: () => Modular.to.pushNamed('/profile'),
          ),
          const SizedBox(height: 24),
          if (currentTravel != null) ...[
            CurrentTravelCard(
              travel: currentTravel,
              onTap: () {
                Modular.to.pushNamed(
                  '/new-travel/tracking',
                  arguments: {
                    'travelId': currentTravel.travelId,
                  },
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          LastTravelsCard(
            travels: lastTravels,
            onViewAll: () => Modular.to.pushNamed('/travel-history'),
          ),
        ],
      ),
    ),
  );

  Widget defaultState() => const SizedBox.shrink();

  Widget failureState(String message) => Scaffold(
    backgroundColor: AppColors.white,
    body: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SafeArea(
        child: Column(
          children: [
            ProfileHeader(
              fullName: '',
              onSignOut: () => _handleSignOut(context),
              onSettings: () => Modular.to.pushNamed('/profile'),
            ),
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Erro ao carregar. Toque para tentar novamente.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  FloatingActionButton homeFab() => FloatingActionButton(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
        MediaQuery.sizeOf(context).height * 0.1,
      ),
    ),
    backgroundColor: AppColors.primary,
    onPressed: () => Modular.to.pushNamed('/new-travel'),
    child: const Icon(Icons.add, color: Colors.white),
  );

  Widget loadedState(
    PassengerProfileEntity profile,
    TravelSummaryEntity? currentTravel,
    List<TravelSummaryEntity> lastTravels,
  ) => buildContent(
    profile,
    currentTravel,
    lastTravels,
  );

  Widget loadingState() => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(
      child: Column(
        children: [
          ProfileHeader(
            fullName: '',
            onSignOut: () => _handleSignOut(context),
            onSettings: () => Modular.to.pushNamed('/profile'),
          ),
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    ),
  );

  Future<void> _handleSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja realmente sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await Modular.get<SignOutService>().signOut();
  }
}
