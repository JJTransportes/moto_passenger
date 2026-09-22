part of 'profile_bloc.dart';

sealed class ProfileEvent {
  const ProfileEvent();
}

final class LoadProfile extends ProfileEvent {
  final String userId;
  LoadProfile(this.userId);
}

final class SaveProfile extends ProfileEvent {
  final String userId;
  final UpdateProfileRequest request;
  SaveProfile(this.userId, this.request);
}

final class UploadPhoto extends ProfileEvent {
  final String userId;
  final File imageFile;
  UploadPhoto(this.userId, this.imageFile);
}

final class RemovePhoto extends ProfileEvent {
  final String userId;
  const RemovePhoto(this.userId);
}

final class DiscardChanges extends ProfileEvent {
  const DiscardChanges();
}
