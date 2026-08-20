import 'package:powersync/powersync.dart';

/// Client-side SQLite schema for PowerSync.
///
/// Rules:
/// - Every **synced** table includes [organization_id] (tenant non-negotiable).
/// - Indexes support org-scoped list queries used offline.
/// - Column sets should stay aligned with Sync Streams + Postgres;
///   regenerate from PowerSync Dashboard when streams stabilize.
///
/// PowerSync always provides a text `id` column; do not redefine it.
final Schema peekePowerSyncSchema = Schema([
  Table(
    'organization_members',
    [
      Column.text('organization_id'),
      Column.text('user_id'),
      Column.text('role'),
      Column.text('title'),
      Column.text('created_at'),
      Column.text('updated_at'),
    ],
    indexes: [
      Index('om_org', [IndexedColumn('organization_id')]),
      Index('om_user', [IndexedColumn('user_id')]),
    ],
  ),
  Table(
    'organizations',
    [
      Column.text('name'),
      Column.text('slug'),
      Column.text('status'),
      Column.text('testing_until'),
      Column.text('review_note'),
      Column.text('created_at'),
      Column.text('updated_at'),
    ],
  ),
  Table(
    'clients',
    [
      Column.text('organization_id'),
      Column.text('name'),
      Column.text('code'),
      Column.text('notes'),
      Column.text('created_at'),
      Column.text('updated_at'),
    ],
    indexes: [
      Index('clients_org', [IndexedColumn('organization_id')]),
    ],
  ),
  Table(
    'systems',
    [
      Column.text('organization_id'),
      Column.text('client_id'),
      Column.text('name'),
      Column.text('status'),
      Column.text('created_at'),
      Column.text('updated_at'),
    ],
    indexes: [
      Index('systems_org', [IndexedColumn('organization_id')]),
      Index('systems_client', [IndexedColumn('client_id')]),
    ],
  ),
  // work_orders / work_requests: add when streams are uncommented.
]);
