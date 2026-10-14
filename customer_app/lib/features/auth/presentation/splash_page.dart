import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/auth_controller.dart';

/// C01 — Splash / Session Gate
///
/// Full-screen background [AppColors.background], centered "AgriStore" logo.
/// Restores session (≤ 3 s timeout) then redirects:
///   session != null → /home
///   session == null → /login
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    // Listen once the widget tree is built so context.go works.
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
  }

  Future<void> _navigate() async {
    // Wait for AuthController to finish its init() restore.
    // The controller starts in AsyncLoading; we wait until it settles.
    await Future.doWhile(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final s = ref.read(authControllerProvider);
      return s.isLoading;
    }).timeout(
      const Duration(seconds: 4),
      onTimeout: () {},
    );

    if (!mounted) return;
    final session = ref.read(authControllerProvider);
    if (session.value != null) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AgriStore',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 200,
              child: LinearProgressIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}
