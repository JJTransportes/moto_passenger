part of 'usage_terms_bloc.dart';

sealed class UsageTermsState {
  const UsageTermsState();
}

class UsageTermsInitial extends UsageTermsState {
  const UsageTermsInitial();
}

class UsageTermsChecking extends UsageTermsState {
  const UsageTermsChecking();
}

class UsageTermsAccepted extends UsageTermsState {
  const UsageTermsAccepted();
}

class UsageTermsLoading extends UsageTermsState {
  const UsageTermsLoading();
}

class UsageTermsLoaded extends UsageTermsState {
  final UsageTermEntity terms;

  const UsageTermsLoaded(this.terms);
}

class UsageTermsSubmitting extends UsageTermsState {
  const UsageTermsSubmitting();
}

class UsageTermsDeclined extends UsageTermsState {
  const UsageTermsDeclined();
}

class UsageTermsError extends UsageTermsState {
  final String message;

  const UsageTermsError(this.message);
}
