abstract class IUsageTermsDatasource {
  /// Returns the acceptance status for the authenticated user.
  /// Response: { activeUsageTermId, accepted, acceptedAt }
  Future<Map<String, dynamic>> getAcceptanceStatus();

  /// Returns the currently active usage terms with sub-terms.
  /// Response: { usageTermId, title, subTerms: [{ subTermId, title, content, sortOrder }] }
  Future<Map<String, dynamic>> getActiveTerms();

  /// Records the user's acceptance of the currently active terms.
  /// Idempotent — returns 200 even if already accepted.
  Future<void> acceptTerms();
}
