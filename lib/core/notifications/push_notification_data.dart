class PushNotificationData {
  final String type;
  final String? travelId;
  final String? orderId;
  final String title;
  final String body;
  final Map<String, dynamic> rawPayload;

  const PushNotificationData({
    required this.type,
    this.travelId,
    this.orderId,
    required this.title,
    required this.body,
    required this.rawPayload,
  });
}
