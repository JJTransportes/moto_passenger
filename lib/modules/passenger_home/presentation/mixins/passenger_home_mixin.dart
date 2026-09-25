import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/auth/sign_out_service.dart';
import 'package:moto_passenger/design_system/design_system.dart';
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
            photoUrl: profile.photoUrl,
            onSignOut: () => _handleSignOut(context),
            onSettings: () => Modular.to.pushNamed('/profile'),
            onAvatarTap: () => Modular.to.pushNamed('/profile'),
          ),
          const SizedBox(height: 24),
          if (currentTravel != null) ...[
            CurrentTravelCard(
              travel: currentTravel,
              onTap: () async {
                await Modular.to.pushNamed(
                  '/new-travel/tracking',
                  arguments: {
                    'travelId': currentTravel.travelId,
                  },
                );
                if (mounted) {
                  BlocProvider.of<PassengerHomeBloc>(context).add(const RefreshPassengerHome());
                }
              },
            ),
            const SizedBox(height: 16),
          ],
          LastTravelsCard(travels: lastTravels),
        ],
      ),
    ),
  );

  Widget defaultState() => const SizedBox.shrink();

  Widget failureState(String message) => Scaffold(
    body: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SafeArea(
        child: Column(
          children: [
            ProfileHeader(
              fullName: '',
              onSignOut: () => _handleSignOut(context),
              onSettings: () => Modular.to.pushNamed('/profile'),
              onAvatarTap: () => Modular.to.pushNamed('/profile'),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Erro ao carregar. Toque para tentar novamente.',
                    style: TextStyle(color: context.moto.textSecondary, fontSize: 16),
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

  FloatingActionButton homeFab({bool hasActiveTravel = false}) => FloatingActionButton(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
        MediaQuery.sizeOf(context).height * 0.1,
      ),
    ),
    backgroundColor: hasActiveTravel ? context.moto.textDisabled : context.moto.accent,
    onPressed: hasActiveTravel
        ? null
        : () async {
            // A Home não recarrega sozinha ao voltar dessa tela (só no pull-
            // to-refresh) — sem isso, o FAB ficava com o estado antigo (ex.:
            // habilitado mesmo já tendo uma corrida ativa) até um refresh
            // manual.
            await Modular.to.pushNamed('/new-travel');
            if (mounted) {
              BlocProvider.of<PassengerHomeBloc>(context).add(const RefreshPassengerHome());
            }
          },
    child: Icon(Icons.add, color: context.moto.textOnAccent),
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
    body: SafeArea(
      child: Column(
        children: [
          ProfileHeader(
            fullName: '',
            onSignOut: () => _handleSignOut(context),
            onSettings: () => Modular.to.pushNamed('/profile'),
            onAvatarTap: () => Modular.to.pushNamed('/profile'),
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
