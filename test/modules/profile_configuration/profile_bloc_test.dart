import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/entities/profile_entity.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/entities/update_profile_request.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/i_get_profile_usecase.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/i_remove_photo_usecase.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/i_update_profile_usecase.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/i_upload_photo_usecase.dart';
import 'package:moto_passenger/modules/profile_configuration/presentation/blocs/profile_bloc.dart';
import 'package:result_dart/result_dart.dart';

class _GetProfile extends Mock implements IGetProfileUsecase {}

class _UpdateProfile extends Mock implements IUpdateProfileUsecase {}

class _UploadPhoto extends Mock implements IUploadPhotoUsecase {}

class _RemovePhoto extends Mock implements IRemovePhotoUsecase {}

void main() {
  setUpAll(() {
    registerFallbackValue(const UpdateProfileRequest(password: 'senha'));
    registerFallbackValue(File('unused'));
  });

  test('permite salvar novamente após um primeiro salvamento', () async {
    final getProfile = _GetProfile();
    final updateProfile = _UpdateProfile();
    const original = ProfileEntity(
      id: 'passenger-1',
      fullName: 'Maria',
      email: 'maria@example.com',
      phone: '11987654321',
    );
    final afterFirstSave = original.copyWith(phone: '11976543210');
    final afterSecondSave = afterFirstSave.copyWith(fullName: 'Maria Silva');
    var updateCount = 0;

    when(
      () => getProfile.call('passenger-1'),
    ).thenAnswer((_) async => const Success(original));
    when(() => updateProfile.call('passenger-1', any())).thenAnswer((_) async {
      updateCount++;
      return Success(updateCount == 1 ? afterFirstSave : afterSecondSave);
    });

    final bloc = ProfileBloc(
      getProfile,
      updateProfile,
      _UploadPhoto(),
      _RemovePhoto(),
    );
    addTearDown(bloc.close);

    bloc.add(LoadProfile('passenger-1'));
    await bloc.stream.firstWhere((state) => state is ProfileLoaded);

    bloc.add(
      SaveProfile(
        'passenger-1',
        const UpdateProfileRequest(phone: '11976543210', password: 'senha'),
      ),
    );
    await bloc.stream.firstWhere(
      (state) => state is ProfileSaveSuccess && state.profile == afterFirstSave,
    );

    bloc.add(
      SaveProfile(
        'passenger-1',
        const UpdateProfileRequest(fullName: 'Maria Silva', password: 'senha'),
      ),
    );
    await bloc.stream.firstWhere(
      (state) =>
          state is ProfileSaveSuccess && state.profile == afterSecondSave,
    );

    verify(() => updateProfile.call('passenger-1', any())).called(2);
  });
}
