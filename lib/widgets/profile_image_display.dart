import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/design_system/design_system.dart';

class ProfileImageDisplay extends StatefulWidget {
  final String? photoUrl;
  final String name;
  final double radius;

  const ProfileImageDisplay({
    super.key,
    this.photoUrl,
    required this.name,
    this.radius = 17,
  });

  @override
  State<ProfileImageDisplay> createState() => _ProfileImageDisplayState();
}

class _ProfileImageDisplayState extends State<ProfileImageDisplay> {
  Map<String, String>? _authHeaders;

  @override
  void initState() {
    super.initState();
    _loadAuthHeaders();
  }

  Future<void> _loadAuthHeaders() async {
    final authStorage = Modular.get<AuthStorage>();
    final token = await authStorage.getToken();
    if (token != null && mounted) {
      setState(() {
        _authHeaders = {'Authorization': 'Bearer $token'};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photoUrl != null && widget.photoUrl!.isNotEmpty && _authHeaders != null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundImage: NetworkImage(widget.photoUrl!, headers: _authHeaders),
        onBackgroundImageError: (_, __) => _buildFallback(context),
      );
    }
    return _buildFallback(context);
  }

  Widget _buildFallback(BuildContext context) {
    return CircleAvatar(
      backgroundColor: context.moto.accent,
      radius: widget.radius,
      child: Text(
        widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
        style: TextStyle(
          color: context.moto.textOnAccent,
          fontWeight: FontWeight.bold,
          fontSize: widget.radius > 25 ? 24 : 16,
        ),
      ),
    );
  }
}
