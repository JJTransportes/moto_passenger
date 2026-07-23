import 'package:flutter/material.dart';
import 'package:moto_passenger/core/theme/app_theme.dart';

class ProfileHeader extends StatelessWidget {
  final String fullName;
  final VoidCallback? onSignOut;
  final VoidCallback? onSettings;
  final VoidCallback? onAvatarTap;

  const ProfileHeader({
    super.key,
    required this.fullName,
    this.onSignOut,
    this.onSettings,
    this.onAvatarTap,
  });

  String get _firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(' ');
    return parts.first;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: CircleAvatar(
            backgroundColor: AppColors.primary,
            radius: 17,
            child: Text(
              fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Olá, $_firstName',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4E4E4E),
          ),
        ),
        const Spacer(),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'settings') onSettings?.call();
            if (value == 'signout') onSignOut?.call();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'settings',
              child: Text('Configurações'),
            ),
            PopupMenuItem(
              value: 'signout',
              child: Text('Sair'),
            ),
          ],
        ),
      ],
    );
  }
}
