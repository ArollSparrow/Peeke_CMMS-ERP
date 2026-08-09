import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../design/gloss_theme.dart';
import '../features/auth/auth_providers.dart';
import 'router.dart';

class PeekeApp extends ConsumerStatefulWidget {
  const PeekeApp({super.key});

  @override
  ConsumerState<PeekeApp> createState() => _PeekeAppState();
}

class _PeekeAppState extends ConsumerState<PeekeApp> {
  @override
  void initState() {
    super.initState();
    // Capture recovery flag as early as possible (before first redirect).
    if (kIsWeb && uriIndicatesPasswordRecovery(Uri.base)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(passwordRecoveryPendingProvider.notifier).state = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Global: recovery event can fire after LoginScreen is gone.
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (prev, next) {
      final event = next.valueOrNull?.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        ref.read(passwordRecoveryPendingProvider.notifier).state = true;
      }
      if (event == AuthChangeEvent.signedOut) {
        ref.read(passwordRecoveryPendingProvider.notifier).state = false;
      }
    });

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Peeke CMMS-ERP',
      debugShowCheckedModeBanner: false,
      theme: GlossTheme.light,
      routerConfig: router,
    );
  }
}
