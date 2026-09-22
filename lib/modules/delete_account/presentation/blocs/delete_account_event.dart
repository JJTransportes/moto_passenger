sealed class DeleteAccountEvent {
  const DeleteAccountEvent();
}

class SubmitDeletion extends DeleteAccountEvent {
  final String password;

  const SubmitDeletion(this.password);
}
