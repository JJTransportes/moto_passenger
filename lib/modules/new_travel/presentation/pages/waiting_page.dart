import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/config/app_config.dart';
import 'package:moto_passenger/core/network/signalr_service.dart';
import 'package:moto_passenger/design_system/design_system.dart';
import 'package:moto_passenger/modules/new_travel/data/datasources/new_travel_datasource.dart';

class WaitingPage extends StatefulWidget {
  final String orderId;

  const WaitingPage({super.key, required this.orderId});

  @override
  State<WaitingPage> createState() => _WaitingPageState();
}

class _WaitingPageState extends State<WaitingPage> with WidgetsBindingObserver {
  StreamSubscription? _acceptedSub;
  StreamSubscription? _cancelledSub;
  StreamSubscription? _driverContactedSub;
  final _startTime = DateTime.now();
  Timer? _elapsedTimer;
  final ValueNotifier<int> _elapsedSeconds = ValueNotifier(0);
  bool _isCancelling = false;

  // PSG-08: WaitingPage dependia só de SignalR — se o evento OrderAccepted
  // se perdesse (reconexão, app voltando de background, hub instável), o
  // passageiro ficava preso na tela de espera mesmo com o motorista já a
  // caminho. Esse polling é o mesmo fallback que TravelTrackingPage já tem
  // via TravelTrackingBloc, adaptado aqui porque WaitingPage não usa bloc.
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 8);

  // O SignalR (onOrderAccepted) e o polling acima detectam a mesma
  // aceitação por caminhos independentes — sem essa guarda, se os dois
  // dispararem perto um do outro, `_onOrderAccepted` roda duas vezes e
  // navega duas vezes seguidas pra `/new-travel/tracking`. A segunda
  // navegação substitui a tela recém-aberta por outra instância nova (bloc
  // novo), deixando a primeira chamada de rede "pendurada" respondendo pra
  // uma página que já não existe mais — e a tela visível (a segunda) nunca
  // recebe essa resposta, ficando presa no spinner.
  bool _orderAcceptedHandled = false;

  String? _authToken;

  // Estado do motorista sendo contatado (evento DriverContacted) — reiniciado
  // por completo a cada novo evento, nunca acumulado (ver Requisito 1.2 da spec).
  String? _contactedDriverName;
  String? _contactedDriverPhotoUrl;
  DateTime? _contactedExpiresAt; // UTC
  DateTime? _contactedReceivedAt; // UTC, momento local de recebimento do evento
  Timer? _countdownTimer;
  final ValueNotifier<DateTime> _countdownNow = ValueNotifier(
    DateTime.now().toUtc(),
  );

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _initSignalR();
    _startPolling();

    // Update elapsed time every second
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds.value = DateTime.now().difference(_startTime).inSeconds;
    });
  }

  // PSG-08: pausa o polling e desconecta o SignalR quando o app vai para
  // background (nada pra checar enquanto a UI não está visível); ao voltar,
  // reconecta e faz uma checagem imediata em vez de esperar o próximo tick,
  // já que o pedido pode ter sido aceito/cancelado durante o tempo fora.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _pollTimer?.cancel();
      Modular.get<SignalRService>().disconnectAll();
    } else if (state == AppLifecycleState.resumed) {
      _initSignalR();
      _pollOnce();
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    if (!mounted) return;
    try {
      final dio = Modular.get<Dio>();
      final response = await dio.get('/api/travels/active');
      if (!mounted) return;

      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['orderId'] != widget.orderId) return;

      final status = data['status'] as String?;
      print('[DIAG] _pollOnce got status=$status travelId=${data['travelId']}');
      if (status == 'Accepted' || status == 'InProgress') {
        _onOrderAccepted({
          'orderId': widget.orderId,
          'travelId': data['travelId'],
        });
      } else if (status == 'Cancelled') {
        _onOrderCancelled({
          'orderId': widget.orderId,
          'reason': data['cancellationReason'],
        });
      }
    } on DioException {
      // Best-effort — SignalR continua sendo o caminho primário, e o
      // próximo tick tenta de novo.
    }
  }

  Future<void> _initSignalR() async {
    // Chamado de novo em cada retorno ao foreground (ver
    // didChangeAppLifecycleState) — sem cancelar antes, cada resume
    // empilhava mais um listener duplicado nos streams do SignalR.
    _acceptedSub?.cancel();
    _cancelledSub?.cancel();
    _driverContactedSub?.cancel();

    final token = await AuthStorage().getToken();
    if (token == null) return;

    _authToken = token;

    final signalR = Modular.get<SignalRService>();
    final baseUrl = AppConfig.getBaseUrl();

    // Register stream listeners BEFORE connecting to avoid race condition:
    // if the backend emits an event between connect() and listen(), the
    // broadcast stream would drop it since it has no buffer.
    _acceptedSub = signalR.onOrderAccepted.listen(_onOrderAccepted);
    _cancelledSub = signalR.onOrderCancelled.listen(_onOrderCancelled);
    _driverContactedSub = signalR.onDriverContacted.listen(_onDriverContacted);

    try {
      // Connect to travel-orders hub to receive OrderAccepted events
      await signalR.connect(
        'travel-orders',
        '$baseUrl/hubs/travel-orders',
        token,
      );
      if (mounted) setState(() {});
    } catch (_) {
      // Non-critical; polling in TravelTrackingPage will be the fallback
    }

    // A conexão pode já existir desde antes de esta tela montar (o pedido é
    // criado, e o hub conectado, ainda em NewTravelBloc._onConfirm) — se o
    // primeiro DriverContacted já chegou nesse meio-tempo, ele fica em cache
    // no SignalRService e é aplicado aqui em vez de se perder.
    final cached = signalR.lastDriverContacted;
    if (cached != null) _onDriverContacted(cached);
  }

  void _onDriverContacted(Map<String, dynamic> event) {
    if (event['orderId'] != widget.orderId) return;

    final expiresAt = DateTime.tryParse(
      event['expiresAt'] as String? ?? '',
    )?.toUtc();
    if (expiresAt == null || !mounted) return;

    setState(() {
      _contactedDriverName = event['driverName'] as String?;
      _contactedDriverPhotoUrl = event['driverPhotoUrl'] as String?;
      _contactedExpiresAt = expiresAt;
      _contactedReceivedAt = DateTime.now().toUtc();
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final now = DateTime.now().toUtc();
      _countdownNow.value = now;
      if (!now.isBefore(expiresAt)) {
        _countdownTimer?.cancel();
      }
    });
  }

  Duration _remainingAt(DateTime now) {
    final expiresAt = _contactedExpiresAt;
    if (expiresAt == null) return Duration.zero;
    final diff = expiresAt.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  double _progressFractionAt(DateTime now) {
    final expiresAt = _contactedExpiresAt;
    final receivedAt = _contactedReceivedAt;
    if (expiresAt == null || receivedAt == null) return 0;
    final total = expiresAt.difference(receivedAt).inMilliseconds;
    if (total <= 0) return 0;
    return (_remainingAt(now).inMilliseconds / total).clamp(0.0, 1.0);
  }

  String _resolveImageUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${AppConfig.getBaseUrl()}$url';
  }

  Map<String, String>? get _authHeaders {
    final token = _authToken;
    if (token == null) return null;
    return {'Authorization': 'Bearer $token'};
  }

  void _onOrderCancelled(Map<String, dynamic> event) {
    // OrderCancelled payload: { orderId, reason } — no travelId
    if (event['orderId'] != widget.orderId) return;

    final reason = event['reason'] as String?;

    if (reason == 'no_drivers_available' && mounted) {
      _showNoDriversDialog();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pedido cancelado!'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
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
              Navigator.of(context).pop(); // volta para NewTravelPage
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

  void _onOrderAccepted(Map<String, dynamic> event) {
    print(
      '[DIAG] _onOrderAccepted called, event=$event, alreadyHandled=$_orderAcceptedHandled, mounted=$mounted',
    );
    if (_orderAcceptedHandled) return;
    if (event['orderId'] == widget.orderId) {
      final travelId = event['travelId'] as String?;
      if (travelId != null && mounted) {
        _orderAcceptedHandled = true;
        print(
          '[DIAG] navigating to /new-travel/tracking travelId=$travelId orderId=${widget.orderId}',
        );
        // Achado: `Navigator.of(context).pushReplacementNamed(...)` é o
        // Navigator imperativo puro do Flutter — num app com flutter_modular
        // (Router API declarativo), isso NÃO passa os `arguments` pelo canal
        // que a rota `/tracking` lê (`Modular.args.data`, populado só por
        // `Modular.to.*`). A página de acompanhamento abria sem saber qual
        // `travelId` carregar e ficava presa no spinner de carregamento até
        // um evento de SignalR que não depende desses argumentos (ex.:
        // `TravelStarted`, que sempre emite `TravelTrackingInProgress`
        // incondicionalmente) forçar uma transição de estado — batendo
        // exatamente com "só volta ao normal quando o motorista inicia a
        // viagem". `Modular.to.pushReplacementNamed` é o equivalente correto.
        Modular.to.pushReplacementNamed(
          '/new-travel/tracking',
          arguments: {
            'travelId': travelId,
            'orderId': widget.orderId,
          },
        );
      }
    }
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: const Text('Deseja realmente cancelar este pedido?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sim, cancelar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);

    try {
      await Modular.get<INewTravelDatasource>().cancelOrder(widget.orderId);
    } catch (_) {
      // Even if cancel fails, go back — the order may already be processed
    }

    if (mounted) {
      Modular.to.pop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _acceptedSub?.cancel();
    _cancelledSub?.cancel();
    _driverContactedSub?.cancel();
    _elapsedTimer?.cancel();
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    _elapsedSeconds.dispose();
    _countdownNow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sem volta manual daqui: só sai pelo cancelamento explícito (botão
    // "Cancelar pedido") ou pelas transições automáticas de OrderAccepted/
    // OrderCancelled — nunca pelo botão/gesto de voltar do Android.
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Aguardando Motorista',
            style: TextStyle(color: context.moto.textPrimary),
          ),
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: MotoCanvas(
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: _contactedDriverName == null
                    ? _buildWaitingCard()
                    : _buildContactingCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MotoSonar(),
        const SizedBox(height: 32),
        Text(
          'Pedido enviado!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: context.moto.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Aguardando um motorista aceitar sua viagem...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: context.moto.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        ValueListenableBuilder<int>(
          valueListenable: _elapsedSeconds,
          builder: (context, seconds, _) => Text(
            'Aguardando ha ${seconds}s',
            style: TextStyle(
              fontSize: 14,
              color: context.moto.textTertiary,
            ),
          ),
        ),
        const SizedBox(height: 48),
        _buildCancelButton(),
      ],
    );
  }

  Widget _buildContactingCard() {
    final photoUrl = _contactedDriverPhotoUrl;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MotoAvatar(
          initials: _initialsOf(_contactedDriverName),
          size: 96,
          image: photoUrl != null && photoUrl.isNotEmpty
              ? NetworkImage(_resolveImageUrl(photoUrl), headers: _authHeaders)
              : null,
        ),
        const SizedBox(height: 24),
        Text(
          'Contatando motorista $_contactedDriverName',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: context.moto.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'O motorista pode recusar ou o tempo esgotar — nesse caso, o pedido é '
          'repassado automaticamente para o próximo motorista mais próximo.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: context.moto.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        ValueListenableBuilder<DateTime>(
          valueListenable: _countdownNow,
          builder: (context, now, _) {
            final remainingSeconds = _remainingAt(now).inSeconds;
            return Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progressFractionAt(now),
                    minHeight: 8,
                    backgroundColor: context.moto.bgSunken,
                    valueColor: AlwaysStoppedAnimation(context.moto.accent),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${remainingSeconds}s',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.moto.textTertiary,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        _buildCancelButton(),
      ],
    );
  }

  Widget _buildCancelButton() {
    return MotoButton(
      label: 'Cancelar pedido',
      variant: MotoButtonVariant.danger,
      loading: _isCancelling,
      onPressed: _isCancelling ? null : _cancelOrder,
    );
  }

  String _initialsOf(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }
}
