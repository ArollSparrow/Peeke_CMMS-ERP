import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'peeke_schema.dart';
import 'powersync_env.dart';
import 'supabase_connector.dart';

/// Opens and optionally connects the PowerSync-managed SQLite database.
///
/// Isolation:
/// - DB file path includes auth user id when available.
/// - Call [disconnectAndClear] on logout so the next session cannot see prior
///   tenant rows on a shared device.
class PeekePowerSync {
  PeekePowerSync._();

  static PowerSyncDatabase? _db;
  static PeekeSupabaseConnector? _connector;

  static PowerSyncDatabase? get instance => _db;

  static bool get isReady => _db != null;

  static Future<PowerSyncDatabase?> open() async {
    if (!PowerSyncEnv.isConfigured) return null;
    if (_db != null) return _db;

    final path = await _dbPath();
    final db = PowerSyncDatabase(schema: peekePowerSyncSchema, path: path);
    await db.initialize();
    _db = db;
    return db;
  }

  /// Connect sync when a Supabase session exists and [PowerSyncEnv] is set.
  static Future<void> connectIfPossible() async {
    if (!PowerSyncEnv.isConfigured) return;

    final db = await open();
    if (db == null) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      await db.disconnect();
      return;
    }

    _connector ??= PeekeSupabaseConnector(db);
    await db.connect(connector: _connector!);
  }

  static Future<void> disconnect() async {
    await _db?.disconnect();
  }

  /// Logout / user switch: drop local synced state for device hygiene.
  static Future<void> disconnectAndClear() async {
    final db = _db;
    if (db == null) return;
    await db.disconnectAndClear();
    _db = null;
    _connector = null;
  }

  static Future<String> _dbPath() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
    final name = 'peeke_powersync_$userId.db';
    if (kIsWeb) {
      // Web uses in-browser storage; path is a logical key.
      return name;
    }
    final dir = await getApplicationSupportDirectory();
    return join(dir.path, name);
  }
}
