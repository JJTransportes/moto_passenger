import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/modules/usage_terms/domain/entities/usage_term_entity.dart';
import 'package:moto_passenger/modules/usage_terms/presentation/blocs/usage_terms_bloc.dart';
import 'package:moto_passenger/modules/usage_terms/presentation/widgets/usage_terms_dialog.dart';

class UsageTermsGuardPage extends StatefulWidget {
  const UsageTermsGuardPage({super.key});

  @override
  State<UsageTermsGuardPage> createState() => _UsageTermsGuardPageState();
}

class _UsageTermsGuardPageState extends State<UsageTermsGuardPage> {
  UsageTermEntity? _cachedTerms;

  @override
  void initState() {
    super.initState();
    context.read<UsageTermsBloc>().add(const CheckAcceptanceStatus());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: BlocConsumer<UsageTermsBloc, UsageTermsState>(
        listener: (context, state) {
          if (state is UsageTermsAccepted) {
            Modular.to.pushReplacementNamed('/home');
          } else if (state is UsageTermsLoaded) {
            _cachedTerms = state.terms;
          } else if (state is UsageTermsDeclined) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'É necessário aceitar os Termos de Uso para continuar.',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
            // Reload terms to re-display the dialog
            context.read<UsageTermsBloc>().add(const LoadActiveTerms());
          } else if (state is UsageTermsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Tentar novamente',
                  onPressed: () {
                    context
                        .read<UsageTermsBloc>()
                        .add(const CheckAcceptanceStatus());
                  },
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: _buildBody(state),
          );
        },
      ),
    );
  }

  Widget _buildBody(UsageTermsState state) {
    // Show terms screen when we have terms loaded or are submitting
    if (_cachedTerms != null &&
        (state is UsageTermsLoaded || state is UsageTermsSubmitting)) {
      return UsageTermsDialog(
        terms: _cachedTerms!,
        onAccept: () {
          context.read<UsageTermsBloc>().add(const AcceptTerms());
        },
        onDecline: () {
          context.read<UsageTermsBloc>().add(const DeclineTerms());
        },
        isSubmitting: state is UsageTermsSubmitting,
      );
    }

    // Loading / checking states
    return const Center(child: CircularProgressIndicator());
  }
}
