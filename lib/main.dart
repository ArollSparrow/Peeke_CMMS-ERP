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
    // Team invite emails (inviteUserByEmail) redirect with #access_token=…&type=invite
    // (implicit grant). Default PKCE expects ?code= and leaves the invitee with no
    // session → Accept invite shows “Link not active yet”. Implicit on web is
    // required so mail remains the primary path for members.
    authOptions: FlutterAuthClientOptions(
      authFlowType: kIsWeb ? AuthFlowType.implicit : AuthFlowType.pkce,
      detectSessionInUri: true,
      autoRefreshToken: true,
    ),
  );

  runApp(
    const ProviderScope(
      child: PeekeApp(),
    ),
  );
}
