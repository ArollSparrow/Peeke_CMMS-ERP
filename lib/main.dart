import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'infra/supabase/supabase_env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Path URLs leave the # fragment free for Supabase Auth (invite / recovery).
  // Hash-based routing fights access_token in the fragment and breaks invites.
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  await Supabase.initialize(
    url: SupabaseEnv.url,
    anonKey: SupabaseEnv.anonKey,
    // Email invite: /auth/v1/verify → redirect_to#access_token=…&type=invite
    // (implicit grant). PKCE expects ?code= and a code_verifier the invitee never
    // had (invite is created server-side). On web that left bare /accept-invite
    // with no session after the hash was stripped. Implicit is required for mail.
    authOptions: FlutterAuthClientOptions(
      authFlowType: kIsWeb ? AuthFlowType.implicit : AuthFlowType.pkce,
      detectSessionInUri: true,
      autoRefreshToken: true,
    ),
  );

  // Capture invite/recovery hash before the first frame can navigate away.
  if (kIsWeb) {
    try {
      final uri = Uri.base;
      final frag = uri.fragment;
      final hasImplicit = frag.contains('access_token=') ||
          uri.queryParameters.containsKey('access_token');
      final hasCode = uri.queryParameters.containsKey('code');
      final hasTokenHash = uri.queryParameters.containsKey('token_hash');
      if (hasImplicit || hasCode || hasTokenHash) {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      }
    } catch (_) {
      // Accept-invite screen will surface errors / retry recovery.
    }
  }

  runApp(
    const ProviderScope(
      child: PeekeApp(),
    ),
  );
}
