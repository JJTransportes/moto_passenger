import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/config/app_config.dart';
import 'package:moto_passenger/core/network/signalr_service.dart';
import 'package:moto_passenger/core/theme/app_theme.dart';

class WaitingPage extends StatefulWidget {
  final String orderId;

  const WaitingPage({super.key, required this.orderId});

  @override
  State<WaitingPage> createState() => _WaitingPageState();
}

class _WaitingPageState extends State<WaitingPage> {
  StreamSubscription? _acceptedSub;
  StreamSubscription? _cancelledSub;
  final _startTime = DateTime.now();
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();

    _initSignalR();

    // Update elapsed time every second
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime);
        });
      }
    });
  }

  Future<void> _initSignalR() async {
    final token = await AuthStorage().getToken();
    if (token == null) return;

    final signalR = Modular.get<SignalRService>();
    final baseUrl = AppConfig.getBaseUrl();

    try {
      // Connect to travel-orders hub to receive OrderAccepted events
      await signalR.connect(
        'travel-orders',
        '$baseUrl/hubs/travel-orders',
        token,
      );
    } catch (_) {
      // Non-critical; polling in TravelTrackingPage will be the fallback
    }

    // Listen for OrderAccepted and OrderCancelled events
    _acceptedSub = signalR.onOrderAccepted.listen(_onOrderAccepted);
    _cancelledSub = signalR.onOrderCancelled.listen(_onOrderCancelled);
  }

  void _onOrderAccepted(Map<String, dynamic> event) {
    if (event['orderId'] == widget.orderId) {
      final travelId = event['travelId'] as String?;
      if (travelId != null && mounted) {
        Navigator.of(context).pushReplacementNamed(
          '/new-travel/tracking',
          arguments: {
            'travelId': travelId,
            'orderId': widget.orderId,
          },
        );
      }
    }
  }

  void _onOrderCancelled(Map<String, dynamic> event) {
    if (event['orderId'] != widget.orderId) return;

    final reason = event['reason'] as String?;

    if (reason == 'no_drivers_available' && mounted) {
      _showNoDriversDialog();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason ?? 'Pedido cancelado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Modular.to.pop();
    }
  }

  void _showNoDriversDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Nenhum motorista disponível'),
        content: const Text(
          'No momento não há motoristas disponíveis para atender sua viagem. '
          'Tente novamente em alguns instantes.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Modular.to.pop();
            },
            child: const Text('Tentar Novamente'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Modular.to.navigate('/home');
            },
            child: const Text('Ir para Home'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _acceptedSub?.cancel();
    _cancelledSub?.cancel();
    _elapsedTimer?.cancel();
    Modular.get<SignalRService>().disconnect('travel-orders');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _elapsed.inSeconds;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Aguardando Motorista',
            style: TextStyle(color: Color(0xFF4E4E4E))),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4E4E4E)),
          onPressed: () => Modular.to.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFF4685C0),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Pedido enviado!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4E4E4E),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aguardando um motorista aceitar sua viagem...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF4E4E4E),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Aguardando ha ${seconds}s',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side:
                          const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Modular.to.pop();
                    },
                    child: const Text(
                      'Cancelar pedido',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
