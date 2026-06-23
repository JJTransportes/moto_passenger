import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/i_login_usecase.dart';
import 'package:moto_passenger/modules/auth/domain/usecases/login_usecase.dart';
import 'package:moto_passenger/modules/auth/presentation/blocs/login_bloc.dart';
import 'package:moto_passenger/modules/auth/presentation/pages/login_page.dart';
import 'package:moto_passenger/modules/auth/presentation/pages/password_recovery_page.dart';
import 'package:moto_passenger/modules/auth/presentation/pages/password_reset_page.dart';
import 'package:moto_passenger/modules/common_module.dart';
import 'package:moto_passenger/modules/new_travel/new_travel_module.dart';
import 'package:moto_passenger/modules/passenger_home/passenger_home_module.dart';
import 'package:moto_passenger/screens/splash_screen.dart';

class AppModule extends Module {
  @override
  List<Module> get imports => [
    CommonModule(),
  ];

  @override
  void binds(i) {
    i.add<ILoginUsecase>(LoginUsecase.new);
    i.add<LoginBloc>(LoginBloc.new);
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
    r.child('/recovery', child: (_) => const PasswordRecoveryPage());
    r.child('/reset-password', child: (_) => const PasswordResetPage());
    r.module('/home', module: PassengerHomeModule());
    r.module('/new-travel', module: NewTravelModule());
  }
}
