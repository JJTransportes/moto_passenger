import 'package:flutter/material.dart';
import 'package:moto_passenger/design_system/design_system.dart';
import 'package:moto_passenger/widgets/profile_image_display.dart';

class ProfileHeader extends StatelessWidget {
  final String fullName;
  final String? photoUrl;
  final VoidCallback? onSignOut;
  final VoidCallback? onSettings;
  final VoidCallback? onAvatarTap;

  const ProfileHeader({
    super.key,
    required this.fullName,
    this.photoUrl,
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

  static const _weekdays = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
  static const _months = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  String _todayLabel() {
    final now = DateTime.now();
    return '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: ProfileImageDisplay(
            photoUrl: photoUrl,
            name: fullName,
            radius: 20,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_todayLabel(), style: Theme.of(context).textTheme.bodySmall),
            Text(
              'Olá, $_firstName',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.moto.textPrimary,
              ),
            ),
          ],
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
