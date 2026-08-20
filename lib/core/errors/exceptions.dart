class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([this.message = 'Credenciais inválidas']);
  @override
  String toString() => message;
}

class NotFoundException implements Exception {
  final String message;
  const NotFoundException([this.message = 'Recurso não encontrado']);
  @override
  String toString() => message;
}

class ValidationException implements Exception {
  final String message;
  const ValidationException([this.message = 'Dados inválidos']);
  @override
  String toString() => message;
}

class RateLimitedException implements Exception {
  final String message;
  const RateLimitedException([this.message = 'Muitas tentativas. Tente novamente mais tarde.']);
  @override
  String toString() => message;
}

class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'Erro de conexão. Verifique sua internet.']);
  @override
  String toString() => message;
}

class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'Erro interno do servidor. Tente novamente.']);
  @override
  String toString() => message;
}

class ConflictException implements Exception {
  final String message;
  const ConflictException([this.message = 'Conflito ao processar a solicitação.']);
  @override
  String toString() => message;
}

class DeviceConflictException implements Exception {
  final String message;
  const DeviceConflictException([
    this.message = 'Sessão ativa em outro tipo de dispositivo. Faça logout no outro aparelho antes de entrar.',
  ]);
  @override
  String toString() => message;
}

class DeviceMismatchException implements Exception {
  final String message;
  const DeviceMismatchException([
    this.message = 'Sessão vinculada a outro tipo de dispositivo.',
  ]);
  @override
  String toString() => message;
}
