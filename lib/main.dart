import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'core/api_client.dart';
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
import 'screens/public/shell_screen.dart';
import 'screens/splash_screen.dart';
import 'services/services.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DeepLink.captureInitial();
  await AppConfig.init();
  final api = await ApiClient.init();
  final services = ApiServices.from(api);
  runApp(AptEvApp(services: services));
}

class AptEvApp extends StatelessWidget {
  const AptEvApp({required this.services, super.key});

  final ApiServices services;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(services)..bootstrap()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProxyProvider<ConnectivityProvider, AppStateProvider>(
          create: (ctx) => AppStateProvider(
            services,
            connectivity: ctx.read<ConnectivityProvider>(),
          ),
          update: (_, __, prev) => prev!,
        ),
        Provider.value(value: services),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        home: const _RootNavigator(),
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
        return const ShellScreen();
    }
  }
}
