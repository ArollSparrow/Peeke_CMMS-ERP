import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/gloss_theme.dart';
import '../../infra/friendly_error.dart';
import '../auth/auth_providers.dart';
import 'org_providers.dart';
import 'org_team_models.dart';

/// Create / rename / soft-deactivate departments + HoD / headcount (v2).
/// Elevated roles only (same gate as Team invite).
class OrgDepartmentsScreen extends ConsumerStatefulWidget {
  const OrgDepartmentsScreen({super.key});

  @override
  ConsumerState<OrgDepartmentsScreen> createState() =>
      _OrgDepartmentsScreenState();
}

class _OrgDepartmentsScreenState extends ConsumerState<OrgDepartmentsScreen> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(orgDepartmentsProvider);
    ref.invalidate(orgDepartmentStatsProvider);
    ref.invalidate(orgMembersProvider);
  }

  Future<void> _create() async {
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Enter a department name (at least 2 characters)');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await ref.read(supabaseClientProvider).rpc(
        'create_org_department',
        params: {
          'p_organization_id': org.id,
          'p_name': name,
        },
      );
      _name.clear();
      _refresh();
      setState(() => _message = 'Department “$name” created');
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(OrgDept dept) async {
    final ctrl = TextEditingController(text: dept.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename department'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final name = ctrl.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Name too short');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await ref.read(supabaseClientProvider).rpc(
        'rename_org_department',
        params: {
          'p_department_id': dept.id,
          'p_name': name,
        },
      );
      _refresh();
      setState(() => _message = 'Renamed to “$name”');
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setActive(OrgDept dept, bool active) async {
    if (!active) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Deactivate department?'),
          content: Text(
            '“${dept.name}” will be hidden from new member assignments.\n\n'
            'Existing member links are kept. You can reactivate later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep active'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await ref.read(supabaseClientProvider).rpc(
        'set_org_department_active',
        params: {
          'p_department_id': dept.id,
          'p_active': active,
        },
      );
      _refresh();
      setState(
        () => _message = active
            ? '“${dept.name}” reactivated'
            : '“${dept.name}” deactivated',
      );
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _tile(OrgDeptStats s) {
    final d = s.dept;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: GlossSurfaces.fieldGap),
      decoration: GlossSurfaces.plate,
      child: Opacity(
        opacity: d.isActive ? 1 : 0.55,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 2, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.isActive ? d.code : '${d.code} · inactive',
                      style: GlossSurfaces.tileMeta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      d.name,
                      style: GlossSurfaces.tileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.hodLine,
                      style: GlossSurfaces.tileMeta.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      s.countLine,
                      style: GlossSurfaces.tileMeta.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(
                  Icons.more_vert,
                  color: GlossColors.tealDeep,
                  size: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(GlossSurfaces.tileRadius),
                ),
                color: GlossColors.sky,
                onSelected: (v) {
                  if (v == 'rename') _rename(d);
                  if (v == 'off') _setActive(d, false);
                  if (v == 'on') _setActive(d, true);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text('Rename', style: GlossSurfaces.logoMark),
                  ),
                  if (d.isActive)
                    PopupMenuItem(
                      value: 'off',
                      child: Text('Deactivate',
                          style: GlossSurfaces.logoMark),
                    )
                  else
                    PopupMenuItem(
                      value: 'on',
                      child: Text('Reactivate',
                          style: GlossSurfaces.logoMark),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caps = ref.watch(orgCapabilitiesProvider);
    final stats = ref.watch(orgDepartmentStatsProvider);

    if (!caps.isElevated) {
      return Scaffold(
        backgroundColor: GlossColors.sky,
        appBar: AppBar(title: const Text('Departments')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Only owners and elevated admins can manage departments.',
              style: GlossSurfaces.logoAccent,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: GlossColors.sky,
      appBar: AppBar(title: const Text('Departments')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'Each row shows HoD and headcount. Assign HoD on Team → member → '
            'long-press a department chip. Deactivate hides a department from '
            'new assignments without deleting history.',
            style: GlossSurfaces.logoAccent,
          ),
          const SizedBox(height: 16),
          GlossSurfaces.fieldShell(
            child: TextField(
              controller: _name,
              style: GlossSurfaces.logoMark.copyWith(fontSize: 13),
              cursorColor: GlossColors.navy,
              textCapitalization: TextCapitalization.words,
              decoration: GlossSurfaces.compactField('New department').copyWith(
                    hintText: 'e.g. Quality Assurance',
                  ),
              onSubmitted: (_) => _create(),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.center,
            child: GlossSurfaces.glossCta(
              label: 'ADD DEPARTMENT',
              onTap: _create,
              busy: _busy,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: GlossSurfaces.fieldGap),
            Text(
              _error!,
              style: GlossSurfaces.logoMark
                  .copyWith(color: GlossColors.danger),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: GlossSurfaces.fieldGap),
            Text(_message!, style: GlossSurfaces.logoAccent),
          ],
          const SizedBox(height: 20),
          Text(
            'ALL DEPARTMENTS',
            style: GlossSurfaces.logoAccent.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: GlossSurfaces.fieldGap),
          stats.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(friendlyError(e)),
            data: (list) {
              if (list.isEmpty) {
                return Text('No departments yet',
                    style: GlossSurfaces.logoAccent);
              }
              return Column(
                children: [for (final s in list) _tile(s)],
              );
            },
          ),
        ],
      ),
    );
  }
}
