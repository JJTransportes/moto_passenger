part of 'profile_bloc.dart';

sealed class ProfileEvent {
  const ProfileEvent();
}

final class LoadProfile extends ProfileEvent {
  final String userId;
  LoadProfile(this.userId);
}

final class SaveProfile extends ProfileEvent {
  final UpdateProfileRequest request;
  SaveProfile(this.request);
}

final class UploadPhoto extends ProfileEvent {
  final File imageFile;
  UploadPhoto(this.imageFile);
}

final class RemovePhoto extends ProfileEvent {
  const RemovePhoto();
}

final class DiscardChanges extends ProfileEvent {
  const DiscardChanges();
}
