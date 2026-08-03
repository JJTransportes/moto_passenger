class UsageTermEntity {
  final String usageTermId;
  final String title;
  final List<SubTermEntity> subTerms;

  const UsageTermEntity({
    required this.usageTermId,
    required this.title,
    required this.subTerms,
  });
}

class SubTermEntity {
  final String subTermId;
  final String title;
  final String content;
  final int sortOrder;

  const SubTermEntity({
    required this.subTermId,
    required this.title,
    required this.content,
    required this.sortOrder,
  });
}

class AcceptanceStatusEntity {
  final String? activeUsageTermId;
  final bool accepted;
  final DateTime? acceptedAt;

  const AcceptanceStatusEntity({
    this.activeUsageTermId,
    required this.accepted,
    this.acceptedAt,
  });
}
