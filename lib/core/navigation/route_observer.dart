import 'package:flutter/material.dart';

/// Observer global de navegação — permite que páginas (via [RouteAware])
/// saibam quando voltam a ficar visíveis depois de uma tela por cima ser
/// fechada, sem depender de cada chamador lembrar de disparar um refresh
/// manualmente. Registrado em `Modular.setObservers` (ver `app_widget.dart`).
final RouteObserver<ModalRoute<void>> appRouteObserver = RouteObserver<ModalRoute<void>>();
