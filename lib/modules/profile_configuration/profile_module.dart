import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/modules/common_module.dart';
import 'package:moto_passenger/modules/profile_configuration/data/datasources/i_profile_datasource.dart';
import 'package:moto_passenger/modules/profile_configuration/data/datasources/profile_datasource.dart';
import 'package:moto_passenger/modules/profile_configuration/data/repositories/i_profile_repository.dart';
import 'package:moto_passenger/modules/profile_configuration/data/repositories/profile_repository.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/i_get_profile_usecase.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/i_remove_photo_usecase.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/i_update_profile_usecase.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/i_upload_photo_usecase.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/get_profile_usecase.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/update_profile_usecase.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/upload_photo_usecase.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/usecases/remove_photo_usecase.dart';
import 'package:moto_passenger/modules/profile_configuration/presentation/blocs/profile_bloc.dart';
import 'package:moto_passenger/modules/profile_configuration/presentation/pages/profile_page.dart';

class ProfileModule extends Module {
  @override
  List<Module> get imports => [
    CommonModule(),
  ];

  @override
  void binds(Injector i) {
    i.add<IProfileDatasource>(ProfileDatasource.new);
    i.add<IProfileRepository>(ProfileRepository.new);
    i.add<IGetProfileUsecase>(GetProfileUsecase.new);
    i.add<IUpdateProfileUsecase>(UpdateProfileUsecase.new);
    i.add<IUploadPhotoUsecase>(UploadPhotoUsecase.new);
    i.add<IRemovePhotoUsecase>(RemovePhotoUsecase.new);
    i.addSingleton<ProfileBloc>(ProfileBloc.new);
  }

  @override
  void routes(RouteManager r) {
    r.child(
      '/',
      child: (_) => BlocProvider.value(
        value: Modular.get<ProfileBloc>(),
        child: const ProfilePage(),
      ),
    );
  }
}
