import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/gloss_theme.dart';
import 'router.dart';

class PeekeApp extends ConsumerWidget {
  const PeekeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Peeke CMMS-ERP',
      debugShowCheckedModeBanner: false,
      theme: GlossTheme.light,
      routerConfig: router,
    );
  }
}
