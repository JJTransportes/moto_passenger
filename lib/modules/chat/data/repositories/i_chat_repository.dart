import 'package:moto_passenger/modules/chat/domain/entities/chat_entities.dart';
import 'package:result_dart/result_dart.dart';

abstract class IChatRepository {
  Future<Result<ChatMessageEntity>> sendMessage(SendChatMessageParams params);

  Future<Result<ChatHistoryEntity>> loadHistory(String travelId);

  Future<Result<void>> markRead(String travelId);
}
