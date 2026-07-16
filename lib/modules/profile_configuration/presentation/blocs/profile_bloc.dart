import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/entities/profile_entity.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/entities/update_profile_request.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/i_get_profile_usecase.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/i_update_profile_usecase.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/i_upload_photo_usecase.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/i_remove_photo_usecase.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final IGetProfileUsecase _getProfileUsecase;
  final IUpdateProfileUsecase _updateProfileUsecase;
  final IUploadPhotoUsecase _uploadPhotoUsecase;
  final IRemovePhotoUsecase _removePhotoUsecase;

  ProfileBloc(
    this._getProfileUsecase,
    this._updateProfileUsecase,
    this._uploadPhotoUsecase,
    this._removePhotoUsecase,
  ) : super(const ProfileInitial()) {
    on<LoadProfile>(_onLoadProfile);
    on<SaveProfile>(_onSaveProfile);
    on<UploadPhoto>(_onUploadPhoto);
    on<RemovePhoto>(_onRemovePhoto);
  }

  Future<void> _onLoadProfile(
    LoadProfile event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());

    final result = await _getProfileUsecase.call(event.userId);

    result.fold(
      (profile) => emit(ProfileLoaded(profile)),
      (error) => emit(ProfileError(error.toString())),
    );
  }

  Future<void> _onSaveProfile(
    SaveProfile event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded && currentState is! ProfileSaveError) {
      return;
    }

    final profile = (currentState is ProfileLoaded)
        ? currentState.profile
        : (currentState as ProfileSaveError).profile;

    emit(ProfileSaving(profile));

    final result = await _updateProfileUsecase.call(profile.id, event.request);

    result.fold(
      (updatedProfile) => emit(ProfileSaveSuccess(updatedProfile)),
      (error) => emit(ProfileSaveError(profile, error.toString())),
    );
  }

  Future<void> _onUploadPhoto(
    UploadPhoto event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded &&
        currentState is! ProfileSaveSuccess &&
        currentState is! ProfilePhotoUpdated &&
        currentState is! ProfilePhotoRemoved &&
        currentState is! ProfilePhotoError &&
        currentState is! ProfileSaveError) {
      return;
    }

    final profile = _extractProfile(currentState);

    emit(ProfilePhotoUploading(profile));

    final result = await _uploadPhotoUsecase.call(event.userId, event.imageFile);

    result.fold(
      (photoUrl) => emit(
        ProfilePhotoUpdated(
          profile.copyWith(photoUrl: photoUrl),
        ),
      ),
      (error) => emit(ProfilePhotoError(profile, error.toString())),
    );
  }

  Future<void> _onRemovePhoto(
    RemovePhoto event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded &&
        currentState is! ProfileSaveSuccess &&
        currentState is! ProfilePhotoUpdated &&
        currentState is! ProfilePhotoRemoved &&
        currentState is! ProfilePhotoError &&
        currentState is! ProfileSaveError) {
      return;
    }

    final profile = _extractProfile(currentState);

    final result = await _removePhotoUsecase.call(profile.id);

    result.fold(
      (_) => emit(
        ProfilePhotoRemoved(profile.copyWith(clearPhotoUrl: true)),
      ),
      (error) => emit(ProfilePhotoError(profile, error.toString())),
    );
  }

  ProfileEntity _extractProfile(ProfileState state) {
    if (state is ProfileLoaded) return state.profile;
    if (state is ProfileSaveSuccess) return state.profile;
    if (state is ProfilePhotoUpdated) return state.profile;
    if (state is ProfilePhotoRemoved) return state.profile;
    if (state is ProfilePhotoError) return state.profile;
    if (state is ProfileSaveError) return state.profile;
    return (state as ProfileSaving).profile;
  }
}
