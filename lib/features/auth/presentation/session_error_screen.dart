import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_error_view.dart';
import '../../session/application/session_controller.dart';

class SessionErrorScreen extends ConsumerWidget {
  const SessionErrorScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AppErrorView(
                message: message,
                onRetry: () =>
                    ref.read(sessionControllerProvider.notifier).retry(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: TextButton(
                onPressed: () =>
                    ref.read(sessionControllerProvider.notifier).signOut(),
                child: const Text('Cerrar sesión'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
