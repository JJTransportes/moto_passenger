import 'package:result_dart/result_dart.dart';
import 'package:moto_passenger/modules/usage_terms/data/datasources/i_usage_terms_datasource.dart';
import 'package:moto_passenger/modules/usage_terms/data/repositories/i_usage_terms_repository.dart';
import 'package:moto_passenger/modules/usage_terms/domain/entities/usage_term_entity.dart';

class UsageTermsRepository implements IUsageTermsRepository {
  final IUsageTermsDatasource _datasource;

  UsageTermsRepository(this._datasource);

  @override
  AsyncResult<AcceptanceStatusEntity> checkAcceptanceStatus() async {
    try {
      final json = await _datasource.getAcceptanceStatus();
      final entity = AcceptanceStatusEntity(
        activeUsageTermId: json['activeUsageTermId'] as String?,
        accepted: json['accepted'] as bool? ?? false,
        acceptedAt: json['acceptedAt'] != null
            ? DateTime.parse(json['acceptedAt'] as String)
            : null,
      );
      return Success(entity);
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  AsyncResult<UsageTermEntity> getActiveTerms() async {
    try {
      final json = await _datasource.getActiveTerms();
      final subTerms = (json['subTerms'] as List<dynamic>? ?? [])
          .map((st) => SubTermEntity(
                subTermId: st['subTermId'] as String,
                title: st['title'] as String,
                content: st['content'] as String,
                sortOrder: st['sortOrder'] as int? ?? 0,
              ))
          .toList();
      final entity = UsageTermEntity(
        usageTermId: json['usageTermId'] as String,
        title: json['title'] as String,
        subTerms: subTerms,
      );
      return Success(entity);
    } on Exception catch (e) {
      return Failure(e);
    }
  }

  @override
  AsyncResult<void> acceptTerms() async {
    try {
      await _datasource.acceptTerms();
      return Success(unit);
    } on Exception catch (e) {
      return Failure(e);
    }
  }
}
