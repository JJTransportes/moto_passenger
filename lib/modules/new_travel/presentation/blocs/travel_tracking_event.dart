sealed class TravelTrackingEvent {
  const TravelTrackingEvent();
}

class LoadTravel extends TravelTrackingEvent {
  final String travelId;
  const LoadTravel(this.travelId);
}

class CancelTravel extends TravelTrackingEvent {
  final String travelId;
  const CancelTravel(this.travelId);
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
