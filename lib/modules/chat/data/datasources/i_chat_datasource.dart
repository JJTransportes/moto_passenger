abstract class IChatDatasource {
  /// POST /api/travels/{id}/chat/messages. Lança exceções tipadas.
  Future<Map<String, dynamic>> sendMessage(
    String travelId,
    String text,
    String clientMessageId,
  );

  /// GET /api/travels/{id}/chat/messages.
  Future<Map<String, dynamic>> getHistory(String travelId);

  /// POST /api/travels/{id}/chat/read.
  Future<void> markRead(String travelId);
}
