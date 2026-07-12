part of 'profile_bloc.dart';

sealed class ProfileState {
  const ProfileState();
}

final class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

final class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

final class ProfileLoaded extends ProfileState {
  final ProfileEntity profile;
  final bool hasUnsavedChanges;

  const ProfileLoaded(this.profile, {this.hasUnsavedChanges = false});
}

final class ProfileSaving extends ProfileState {
  final ProfileEntity profile;
  const ProfileSaving(this.profile);
}

final class ProfileSaveSuccess extends ProfileState {
  final ProfileEntity profile;
  const ProfileSaveSuccess(this.profile);
}

final class ProfileSaveError extends ProfileState {
  final ProfileEntity profile;
  final String message;
  const ProfileSaveError(this.profile, this.message);
}

final class ProfilePhotoUploading extends ProfileState {
  final ProfileEntity profile;
  final double progress;
  const ProfilePhotoUploading(this.profile, {this.progress = 0.0});
}

final class ProfilePhotoUpdated extends ProfileState {
  final ProfileEntity profile;
  const ProfilePhotoUpdated(this.profile);
}

final class ProfilePhotoRemoved extends ProfileState {
  final ProfileEntity profile;
  const ProfilePhotoRemoved(this.profile);
}

final class ProfilePhotoError extends ProfileState {
  final ProfileEntity profile;
  final String message;
  const ProfilePhotoError(this.profile, this.message);
}

final class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);
}
