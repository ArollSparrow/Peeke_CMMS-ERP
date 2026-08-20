import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/org/org_providers.dart';
import 'powersync_database.dart';
import 'powersync_env.dart';

/// True when PowerSync Cloud URL is compiled in.
final powerSyncConfiguredProvider = Provider<bool>((ref) {
  return PowerSyncEnv.isConfigured;
});

/// Opens local DB once per app session when configured.
final powerSyncDatabaseProvider =
    FutureProvider<PowerSyncDatabase?>((ref) async {
  if (!PowerSyncEnv.isConfigured) return null;
  return PeekePowerSync.open();
});

/// Keeps sync connected while a user session exists.
final powerSyncConnectionProvider = FutureProvider<void>((ref) async {
  if (!PowerSyncEnv.isConfigured) return;

  final user = ref.watch(currentUserProvider);
  if (user == null) {
    await PeekePowerSync.disconnect();
    return;
  }

  await PeekePowerSync.connectIfPossible();
});

/// Org-scoped clients from local SQLite (offline-capable).
final localClientsWatchProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
  final db = await ref.watch(powerSyncDatabaseProvider.future);
  final org = ref.watch(activeOrganizationProvider);
  if (db == null || org == null) {
    yield const [];
    return;
  }

  yield* db
      .watch(
        'SELECT * FROM clients WHERE organization_id = ? ORDER BY name COLLATE NOCASE',
        parameters: [org.id],
      )
      .map(
        (rows) => rows
            .map((r) => Map<String, dynamic>.from(r))
            .toList(growable: false),
      );
});

/// Org-scoped systems from local SQLite (offline-capable).
final localSystemsWatchProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
  final db = await ref.watch(powerSyncDatabaseProvider.future);
  final org = ref.watch(activeOrganizationProvider);
  if (db == null || org == null) {
    yield const [];
    return;
  }

  yield* db
      .watch(
        'SELECT * FROM systems WHERE organization_id = ? ORDER BY name COLLATE NOCASE',
        parameters: [org.id],
      )
      .map(
        (rows) => rows
            .map((r) => Map<String, dynamic>.from(r))
            .toList(growable: false),
      );
});
