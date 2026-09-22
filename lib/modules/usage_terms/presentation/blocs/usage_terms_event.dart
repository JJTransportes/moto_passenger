part of 'usage_terms_bloc.dart';

sealed class UsageTermsEvent {
  const UsageTermsEvent();
}

class CheckAcceptanceStatus extends UsageTermsEvent {
  const CheckAcceptanceStatus();
}

class LoadActiveTerms extends UsageTermsEvent {
  const LoadActiveTerms();
}

class AcceptTerms extends UsageTermsEvent {
  const AcceptTerms();
}

class DeclineTerms extends UsageTermsEvent {
  const DeclineTerms();
}
