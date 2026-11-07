import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../organization/presentation/onboarding_screen.dart';
import '../../session/application/session_controller.dart';
import '../../session/domain/app_session.dart';
import '../../shell/presentation/main_shell.dart';
import 'login_screen.dart';
import 'session_error_screen.dart';
import 'splash_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    return switch (session.status) {
      SessionStatus.loading => const SplashScreen(),
      SessionStatus.signedOut => const LoginScreen(),
      SessionStatus.error => SessionErrorScreen(
        message: session.errorMessage ?? 'No se pudo cargar tu cuenta.',
      ),
      SessionStatus.signedIn =>
        session.organization == null
            ? const OnboardingScreen()
            : const MainShell(),
    };
  }
}
