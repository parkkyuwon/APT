import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'core/api_client.dart';
import 'core/app_route_observer.dart';
import 'core/deep_link.dart';
import 'providers/app_state_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/connectivity_provider.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding/blocked_screen.dart';
import 'screens/onboarding/consent_screen.dart';
import 'screens/onboarding/pending_screen.dart';
import 'screens/onboarding/photo_verification_screen.dart';
import 'screens/onboarding/profile_setup_screen.dart';
import 'screens/public/guest_shell_screen.dart';
import 'screens/public/shell_screen.dart';
import 'screens/public/parking_voice_screen.dart';
import 'screens/splash_screen.dart';
import 'services/services.dart';
import 'services/push_notifications.dart';
import 'services/parking_voice_controller.dart';
import 'services/indoor_access_controller.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DeepLink.start();
  await AppConfig.init();
  final api = await ApiClient.init();
  final services = ApiServices.from(api);
  await initializeDeparturePush();
  runApp(AptEvApp(services: services));
}

class AptEvApp extends StatelessWidget {
  const AptEvApp({required this.services, super.key});

  final ApiServices services;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => AuthProvider(services)..bootstrap()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProxyProvider<ConnectivityProvider, AppStateProvider>(
          create: (ctx) => AppStateProvider(
            services,
            connectivity: ctx.read<ConnectivityProvider>(),
            auth: ctx.read<AuthProvider>(),
          ),
          update: (_, __, prev) => prev!,
        ),
        Provider.value(value: services),
        ChangeNotifierProvider(
            lazy: false,
            create: (ctx) => IndoorAccessController(
                services.indoorPositioning, ctx.read<AuthProvider>())),
        ChangeNotifierProvider(
            create: (ctx) =>
                PushNotifications(services, ctx.read<AuthProvider>())),
        ChangeNotifierProvider(
            create: (ctx) => ParkingVoiceController(
                services.parkingVoice, ctx.read<AuthProvider>())),
      ],
      child: Consumer<AuthProvider>(
        builder: (_, auth, __) => MaterialApp(
          // 로그아웃·계정 전환 때 이전 회원의 pushed route도 제거한다.
          key: ValueKey('${auth.stage}:${auth.session?.email}'),
          title: AppConfig.appName,
          theme: buildAppTheme(),
          debugShowCheckedModeBanner: false,
          navigatorObservers: [appRouteObserver],
          builder: (_, child) => Column(children: [
            if (auth.stage == AuthStage.approved ||
                auth.stage == AuthStage.admin)
              const ParkingVoicePanel(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ]),
          // DeepLink retains platform slot URLs; auth owns the initial screen.
          onGenerateInitialRoutes: (_) => [
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/'),
              builder: (_) => const _RootNavigator(),
            ),
          ],
          routes: {'/': (_) => const _RootNavigator()},
        ),
      ),
    );
  }
}

class _RootNavigator extends StatelessWidget {
  const _RootNavigator();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    switch (auth.stage) {
      case AuthStage.initializing:
        return const SplashScreen();
      case AuthStage.anonymous:
        return const LoginScreen();
      case AuthStage.guest:
        return const GuestShellScreen();
      case AuthStage.pending:
        return const PendingScreen();
      case AuthStage.needsProfileSetup:
        return const ProfileSetupScreen();
      case AuthStage.needsConsent:
        return const ConsentScreen();
      case AuthStage.needsPhotoVerification:
        return const PhotoVerificationScreen();
      case AuthStage.blocked:
        return const BlockedScreen();
      case AuthStage.approved:
      case AuthStage.admin:
        return ShellScreen(key: ValueKey('member:${auth.session?.email}'));
    }
  }
}
