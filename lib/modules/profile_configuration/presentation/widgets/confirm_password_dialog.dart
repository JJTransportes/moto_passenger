import 'package:flutter/material.dart';
import 'package:moto_passenger/design_system/design_system.dart';

Future<String?> showConfirmPasswordDialog(
  BuildContext context, {
  bool showLogoutWarning = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _ConfirmPasswordDialog(showLogoutWarning: showLogoutWarning),
  );
}

class _ConfirmPasswordDialog extends StatefulWidget {
  final bool showLogoutWarning;

  const _ConfirmPasswordDialog({required this.showLogoutWarning});

  @override
  State<_ConfirmPasswordDialog> createState() => _ConfirmPasswordDialogState();
}

class _ConfirmPasswordDialogState extends State<_ConfirmPasswordDialog> {
  final _passwordController = TextEditingController();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      final isValid = _passwordController.text.isNotEmpty;
      if (isValid != _isValid) setState(() => _isValid = isValid);
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirme sua senha'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Digite sua senha atual para confirmar a alteração do perfil.'),
          if (widget.showLogoutWarning) ...[
            const SizedBox(height: 12),
            Text(
              'Você será desconectado após salvar, pois seu e-mail de acesso vai mudar.',
              style: TextStyle(color: context.moto.danger, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Senha',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _isValid
              ? () => Navigator.of(context).pop(_passwordController.text)
              : null,
          style: TextButton.styleFrom(foregroundColor: context.moto.accent),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
