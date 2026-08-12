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
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final uri = Uri.base;
        if (uriIndicatesPasswordRecovery(uri)) {
          ref.read(passwordRecoveryPendingProvider.notifier).state = true;
        }
        if (uriIndicatesInvite(uri)) {
          ref.read(invitePasswordPendingProvider.notifier).state = true;
          ref.read(teamInviteLandingProvider.notifier).state = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (prev, next) {
      final event = next.valueOrNull?.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        ref.read(passwordRecoveryPendingProvider.notifier).state = true;
      }
      if (event == AuthChangeEvent.signedOut) {
        ref.read(passwordRecoveryPendingProvider.notifier).state = false;
        ref.read(invitePasswordPendingProvider.notifier).state = false;
      }
      // Invite session often arrives as signedIn with type=invite already in URL
      final user = next.valueOrNull?.session?.user;
      if (user != null) {
        final meta = user.userMetadata;
        if (meta != null &&
            (meta['invited_organization_id'] != null ||
                meta['invited_at'] != null)) {
          ref.read(teamInviteLandingProvider.notifier).state = true;
          // First visit after invite link: force password screen if still pending flag
          if (kIsWeb && uriIndicatesInvite(Uri.base)) {
            ref.read(invitePasswordPendingProvider.notifier).state = true;
          }
        }
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
