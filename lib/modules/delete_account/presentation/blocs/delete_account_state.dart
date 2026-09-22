sealed class DeleteAccountState {
  const DeleteAccountState();
}

class DeleteAccountIdle extends DeleteAccountState {
  const DeleteAccountIdle();
}

class DeleteAccountLoading extends DeleteAccountState {
  const DeleteAccountLoading();
}

class DeleteAccountSuccess extends DeleteAccountState {
  const DeleteAccountSuccess();
}

class DeleteAccountError extends DeleteAccountState {
  final String message;
  final DeleteAccountErrorType type;

  const DeleteAccountError({
    required this.message,
    required this.type,
  });
}

enum DeleteAccountErrorType {
  invalidPassword,
  activeTravels,
  other,
}
