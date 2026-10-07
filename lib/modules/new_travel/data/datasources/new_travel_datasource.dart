import 'package:dio/dio.dart';
import 'package:moto_passenger/core/errors/exceptions.dart';

abstract class INewTravelDatasource {
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> request);
  Future<Map<String, dynamic>> createPriorityOrder(
    Map<String, dynamic> request,
  );
  Future<Map<String, dynamic>?> getLatestOrder();
  Future<void> cancelOrder(String orderId);
}

class NoDriversAvailableException implements Exception {
  final String partitionAcronym;
  final String message;

  const NoDriversAvailableException({
    required this.partitionAcronym,
    required this.message,
  });

  @override
  String toString() => message;
}

class NewTravelDatasource implements INewTravelDatasource {
  final Dio _dio;

  NewTravelDatasource(this._dio);

  @override
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> request) async {
    try {
      // Trata o 404 de "sem motoristas" como resposta normal. Assim esse
      // cenário de negócio não depende da cadeia de interceptadores de erro
      // do Dio para chegar ao Bloc.
      final response = await _dio.post(
        '/api/travels/orders',
        data: request,
        options: Options(validateStatus: _acceptNoDriversResponse),
      );
      _throwIfNoDriversAvailable(response.statusCode, response.data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && e.response?.data is Map) {
        final body = e.response!.data as Map<String, dynamic>;
        if (body['type'] == 'no_drivers_available') {
          throw NoDriversAvailableException(
            partitionAcronym: body['partitionAcronym'] as String? ?? '',
            message:
                body['message'] as String? ?? 'Nenhum motorista disponível',
          );
        }
      }
      if (e.response?.statusCode == 429) {
        throw RateLimitedException(
          _extractErrorMessage(e) ??
              'Muitos pedidos de corrida em pouco tempo. Aguarde alguns minutos e tente novamente.',
        );
      }
      if (e.response?.statusCode == 400) {
        throw ValidationException(
          _extractErrorMessage(e) ?? 'Dados inválidos para criar a viagem.',
        );
      }
      if ((e.response?.statusCode ?? 0) >= 500) {
        throw const ServerException();
      }
      throw _mapNetworkFallback(e, 'Erro ao criar viagem');
    }
  }

  @override
  Future<Map<String, dynamic>> createPriorityOrder(
    Map<String, dynamic> request,
  ) async {
    try {
      final response = await _dio.post(
        '/api/travels/priority-orders',
        data: request,
        options: Options(validateStatus: _acceptNoDriversResponse),
      );
      _throwIfNoDriversAvailable(response.statusCode, response.data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && e.response?.data is Map) {
        final body = e.response!.data as Map<String, dynamic>;
        if (body['type'] == 'no_drivers_available') {
          throw NoDriversAvailableException(
            partitionAcronym: body['partitionAcronym'] as String? ?? '',
            message:
                body['message'] as String? ?? 'Nenhum motorista disponível',
          );
        }
      }
      if (e.response?.statusCode == 429) {
        throw RateLimitedException(
          _extractErrorMessage(e) ??
              'Muitos pedidos de corrida em pouco tempo. Aguarde alguns minutos e tente novamente.',
        );
      }
      if (e.response?.statusCode == 400) {
        throw ValidationException(
          _extractErrorMessage(e) ?? 'Dados inválidos para criar a viagem.',
        );
      }
      if ((e.response?.statusCode ?? 0) >= 500) {
        throw const ServerException();
      }
      throw _mapNetworkFallback(e, 'Erro ao criar viagem');
    }
  }

  @override
  Future<Map<String, dynamic>?> getLatestOrder() async {
    try {
      final response = await _dio.get('/api/travels/orders/latest');
      if (response.statusCode == 204) return null;
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 204) {
        return null;
      }
      throw _mapNetworkFallback(e, 'Erro ao verificar pedidos pendentes');
    }
  }

  @override
  Future<void> cancelOrder(String orderId) async {
    try {
      await _dio.post('/api/travels/orders/$orderId/cancel');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Pedido não encontrado ou já foi processado');
      }
      throw _mapNetworkFallback(e, 'Erro ao cancelar pedido');
    }
  }

  String? _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    return null;
  }

  static bool _acceptNoDriversResponse(int? status) =>
      status != null && (status < 400 || status == 404);

  void _throwIfNoDriversAvailable(int? statusCode, dynamic data) {
    if (statusCode != 404 || data is! Map) return;
    final body = Map<String, dynamic>.from(data);
    if (body['type'] != 'no_drivers_available') return;

    throw NoDriversAvailableException(
      partitionAcronym: body['partitionAcronym'] as String? ?? '',
      message: body['message'] as String? ?? 'Nenhum motorista disponível',
    );
  }

  // PSG-10: sem resposta HTTP nenhuma (timeout, sem internet, DNS/conexão
  // recusada) o código caía num `Exception(e.message)` cru — geralmente a
  // string técnica do Dio (`DioException [connection error]: ...`), exibida
  // direto pro passageiro. Mapeia pra `NetworkException`, com mensagem em
  // português, igual ao padrão já usado nos outros datasources do app.
  Exception _mapNetworkFallback(DioException e, String fallbackMessage) {
    if (e.response == null ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const NetworkException();
    }
    return Exception(e.message ?? fallbackMessage);
  }
}
