import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_passenger/modules/usage_terms/data/repositories/i_usage_terms_repository.dart';
import 'package:moto_passenger/modules/usage_terms/domain/entities/usage_term_entity.dart';
import 'package:moto_passenger/modules/usage_terms/domain/usecases/i_accept_terms_usecase.dart';
import 'package:moto_passenger/modules/usage_terms/domain/usecases/i_check_acceptance_status_usecase.dart';

part 'usage_terms_event.dart';
part 'usage_terms_state.dart';

class UsageTermsBloc extends Bloc<UsageTermsEvent, UsageTermsState> {
  final ICheckAcceptanceStatusUsecase _checkAcceptanceStatusUsecase;
  final IAcceptTermsUsecase _acceptTermsUsecase;
  final IUsageTermsRepository _repository;

  UsageTermsBloc(
    this._checkAcceptanceStatusUsecase,
    this._acceptTermsUsecase,
    this._repository,
  ) : super(const UsageTermsInitial()) {
    on<CheckAcceptanceStatus>(_onCheckAcceptanceStatus);
    on<LoadActiveTerms>(_onLoadActiveTerms);
    on<AcceptTerms>(_onAcceptTerms);
    on<DeclineTerms>(_onDeclineTerms);
  }

  Future<void> _onCheckAcceptanceStatus(
    CheckAcceptanceStatus event,
    Emitter<UsageTermsState> emit,
  ) async {
    emit(const UsageTermsChecking());

    final result = await _checkAcceptanceStatusUsecase.call();

    result.fold(
      (status) {
        // No active terms at all → treat as accepted
        if (status.activeUsageTermId == null) {
          emit(const UsageTermsAccepted());
          return;
        }

        if (status.accepted) {
          emit(const UsageTermsAccepted());
        } else {
          add(const LoadActiveTerms());
        }
      },
      (error) {
        emit(UsageTermsError(error.toString()));
      },
    );
  }

  Future<void> _onLoadActiveTerms(
    LoadActiveTerms event,
    Emitter<UsageTermsState> emit,
  ) async {
    emit(const UsageTermsLoading());

    final result = await _repository.getActiveTerms();

    result.fold(
      (terms) => emit(UsageTermsLoaded(terms)),
      (error) => emit(UsageTermsError(error.toString())),
    );
  }

  Future<void> _onAcceptTerms(
    AcceptTerms event,
    Emitter<UsageTermsState> emit,
  ) async {
    emit(const UsageTermsSubmitting());

    final result = await _acceptTermsUsecase.call();

    result.fold(
      (_) => emit(const UsageTermsAccepted()),
      (error) => emit(UsageTermsError(error.toString())),
    );
  }

  Future<void> _onDeclineTerms(
    DeclineTerms event,
    Emitter<UsageTermsState> emit,
  ) async {
    emit(const UsageTermsDeclined());
  }
}
