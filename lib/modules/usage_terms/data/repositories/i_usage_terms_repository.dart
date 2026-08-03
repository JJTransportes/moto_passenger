import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/usage_terms/domain/entities/usage_term_entity.dart';

abstract class IUsageTermsRepository {
  /// Checks whether the authenticated user has accepted the currently active terms.
  Future<Result<AcceptanceStatusEntity>> checkAcceptanceStatus();

  /// Returns the currently active usage terms with sub-terms.
  Future<Result<UsageTermEntity>> getActiveTerms();

  /// Records the user's acceptance of the currently active terms.
  Future<Result<void>> acceptTerms();
}
