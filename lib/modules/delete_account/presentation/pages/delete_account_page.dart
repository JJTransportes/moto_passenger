import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_passenger/core/auth/sign_out_service.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';
import 'package:moto_passenger/core/network/signalr_service.dart';
import 'package:moto_passenger/modules/delete_account/presentation/blocs/delete_account_bloc.dart';
import 'package:moto_passenger/modules/delete_account/presentation/blocs/delete_account_event.dart';
import 'package:moto_passenger/modules/delete_account/presentation/blocs/delete_account_state.dart';
import 'package:moto_passenger/modules/profile_configuration/presentation/widgets/confirm_password_dialog.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  Future<void> _onContinueTapped() async {
    final password = await showConfirmPasswordDialog(context);
    if (password == null || !mounted) return;
    context.read<DeleteAccountBloc>().add(SubmitDeletion(password));
  }

  Future<void> _handleSuccess() async {
    await context.read<SignalRService>().disconnectAll();
    if (mounted) {
      await context.read<SignOutService>().signOut();
    }
  }

  void _showError(Exception error) {
    final message = _resolveErrorMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _resolveErrorMessage(Exception error) {
    if (error is UnauthorizedException) return error.toString();
    if (error is ValidationException) return error.toString();
    if (error is NetworkException) return error.toString();
    if (error is ServerException) return error.toString();
    return 'Erro inesperado. Tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => context.read<DeleteAccountBloc>(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Excluir conta'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF4E4E4E),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        backgroundColor: Colors.white,
        body: BlocConsumer<DeleteAccountBloc, DeleteAccountState>(
          listener: (context, state) {
            if (state is DeleteAccountSuccess) {
              _handleSuccess();
            }
            if (state is DeleteAccountError) {
              final exception = switch (state.type) {
                DeleteAccountErrorType.invalidPassword =>
                  UnauthorizedException(state.message),
                DeleteAccountErrorType.activeTravels =>
                  ValidationException(state.message),
                DeleteAccountErrorType.other => Exception(state.message),
              };
              _showError(exception);
            }
          },
          builder: (context, state) {
            final isLoading = state is DeleteAccountLoading;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: _buildWarningStep(isLoading),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWarningStep(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tem certeza que deseja excluir sua conta?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Esta ação é irreversível e todos os seus dados, incluindo '
          'histórico de viagens, serão perdidos.',
          style: TextStyle(fontSize: 16, color: Color(0xFF4E4E4E)),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : _onContinueTapped,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Continuar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: isLoading ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Cancelar',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
