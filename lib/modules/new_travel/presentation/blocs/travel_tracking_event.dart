sealed class TravelTrackingEvent {
  const TravelTrackingEvent();
}

class LoadTravel extends TravelTrackingEvent {
  final String travelId;
  const LoadTravel(this.travelId);
}

class CancelTravel extends TravelTrackingEvent {
  final String travelId;
  final String reason;
  const CancelTravel(this.travelId, this.reason);
}

class TravelOrderAccepted extends TravelTrackingEvent {
  final Map<String, dynamic> data;
  const TravelOrderAccepted(this.data);
}

class TravelStarted extends TravelTrackingEvent {
  final Map<String, dynamic> data;
  const TravelStarted(this.data);
}

class TravelCompleted extends TravelTrackingEvent {
  final Map<String, dynamic> data;
  const TravelCompleted(this.data);
}

class TravelCancelled extends TravelTrackingEvent {
  final Map<String, dynamic> data;
  const TravelCancelled(this.data);
}

class PollTravelStatus extends TravelTrackingEvent {
  final String travelId;
  const PollTravelStatus(this.travelId);
}

class DriverLocationUpdated extends TravelTrackingEvent {
  final Map<String, dynamic> data;
  const DriverLocationUpdated(this.data);
}

class DistanceUpdated extends TravelTrackingEvent {
  final Map<String, dynamic> data;
  const DistanceUpdated(this.data);
}

/// PSG-08: disparado quando o app vai para background — para o timer de
/// polling (SignalR também some nesse período) até o app voltar ao
/// foreground e a página disparar um novo [LoadTravel], que já reinicia o
/// polling e força um refresh do estado mais atual.
class PollingPaused extends TravelTrackingEvent {
  const PollingPaused();
}

/// `DriverNearby` / `DriverArrived` do hub `travel-management` (spec
/// pickup-arrival-alerts). `data` = `{travelId, kind: "Nearby"|"Arrived", occurredAt}`.
class DriverProximityAlerted extends TravelTrackingEvent {
  final Map<String, dynamic> data;
  const DriverProximityAlerted(this.data);
}
