import 'dart:async';

import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'powersync_env.dart';

/// Backend connector: Supabase JWT for PowerSync + RLS-bound uploads.
///
/// - [fetchCredentials] reuses the signed-in Supabase session (no service role).
/// - [uploadData] applies CRUD via the user-scoped Supabase client so Postgres
///   RLS remains the write authority.
class PeekeSupabaseConnector extends PowerSyncBackendConnector {
  PeekeSupabaseConnector(this._db);

  final PowerSyncDatabase _db;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    if (!PowerSyncEnv.isConfigured) return null;

    final session = _client.auth.currentSession;
    if (session == null) return null;

    // Refresh if close to expiry so PowerSync does not drop mid-sync.
    final expiresAt = session.expiresAt;
    if (expiresAt != null) {
      final exp = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
      if (exp.isBefore(DateTime.now().toUtc().add(const Duration(minutes: 2)))) {
        await _client.auth.refreshSession();
      }
    }

    final fresh = _client.auth.currentSession;
    if (fresh == null) return null;

    return PowerSyncCredentials(
      endpoint: PowerSyncEnv.url,
      token: fresh.accessToken,
      expiresAt: fresh.expiresAt != null
          ? DateTime.fromMillisecondsSinceEpoch(fresh.expiresAt! * 1000)
          : null,
      userId: fresh.user.id,
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final batch = await database.getCrudBatch();
    if (batch == null) return;

    final client = _client;

    for (final entry in batch.crud) {
      final table = entry.table;
      try {
        if (entry.op == UpdateType.put) {
          final data = Map<String, dynamic>.from(entry.opData ?? {});
          data['id'] = entry.id;
          await client.from(table).upsert(data);
        } else if (entry.op == UpdateType.patch) {
          final data = Map<String, dynamic>.from(entry.opData ?? {});
          await client.from(table).update(data).eq('id', entry.id);
        } else if (entry.op == UpdateType.delete) {
          await client.from(table).delete().eq('id', entry.id);
        }
      } on PostgrestException catch (e) {
        // RLS rejection or constraint — surface; do not complete batch blindly.
        // Throwing keeps the op in the queue for retry / diagnosis.
        throw StateError(
          'PowerSync upload failed on $table/${entry.id}: ${e.message}',
        );
      }
    }

    await batch.complete();
  }
}
