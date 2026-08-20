import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/confirm_password_reset_usecase.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/i_confirm_password_reset_usecase.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/i_login_usecase.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/i_request_password_reset_usecase.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/login_usecase.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/request_password_reset_usecase.dart';
import 'package:moto_passenger/modules/auth/presentation/blocs/login_bloc.dart';
import 'package:moto_passenger/modules/auth/presentation/blocs/password_recovery_bloc.dart';
import 'package:moto_passenger/modules/auth/presentation/blocs/password_reset_bloc.dart';
import 'package:moto_passenger/modules/auth/presentation/pages/login_page.dart';
import 'package:moto_passenger/modules/auth/presentation/pages/password_recovery_page.dart';
import 'package:moto_passenger/modules/auth/presentation/pages/password_reset_page.dart';
import 'package:moto_passenger/modules/common_module.dart';
import 'package:moto_passenger/modules/delete_account/delete_account_module.dart';
import 'package:moto_passenger/modules/new_travel/new_travel_module.dart';
import 'package:moto_passenger/modules/passenger_home/passenger_home_module.dart';
import 'package:moto_passenger/modules/passenger_registration/passenger_registration_module.dart';
import 'package:moto_passenger/modules/profile_configuration/profile_module.dart';
import 'package:moto_passenger/modules/usage_terms/usage_terms_module.dart';
import 'package:moto_passenger/screens/splash_screen.dart';

class AppModule extends Module {
  @override
  List<Module> get imports => [
    CommonModule(),
  ];

  @override
  void binds(i) {
    i.add<ILoginUsecase>(LoginUsecase.new);
    i.addSingleton<LoginBloc>(LoginBloc.new);
    i.add<IRequestPasswordResetUsecase>(RequestPasswordResetUsecase.new);
    i.add<IConfirmPasswordResetUsecase>(ConfirmPasswordResetUsecase.new);
    i.addSingleton<PasswordRecoveryBloc>(PasswordRecoveryBloc.new);
  }

  @override
  void routes(r) {
    r.child('/', child: (_) => const SplashScreen());
    r.child(
      '/login',
      child: (_) => BlocProvider.value(
        value: Modular.get<LoginBloc>(),
        child: const LoginPage(),
      ),
    );
    r.child(
      '/recovery',
      child: (_) => BlocProvider.value(
        value: Modular.get<PasswordRecoveryBloc>(),
        child: const PasswordRecoveryPage(),
      ),
    );
    r.child(
      '/reset-password',
      child: (_) {
        final email = (Modular.args.data as Map)['email'] as String;
        return BlocProvider(
          create: (_) => PasswordResetBloc(
            Modular.get<IConfirmPasswordResetUsecase>(),
            email: email,
          ),
          child: const PasswordResetPage(),
        );
      },
    );
    r.module('/register', module: PassengerRegistrationModule());
    r.module('/home', module: PassengerHomeModule());
    r.module('/new-travel', module: NewTravelModule());
    r.module('/profile', module: ProfileModule());
    r.module('/delete-account', module: DeleteAccountModule());
    r.module('/usage-terms-guard', module: UsageTermsModule());
  }
}
