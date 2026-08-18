import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../design/gloss_theme.dart';
import '../../infra/friendly_error.dart';
import '../auth/auth_providers.dart';
import 'department_chip.dart';
import 'org_providers.dart';
import 'org_roles.dart';
import 'org_team_models.dart';

Widget _glossField({required Widget child}) {
  return GlossSurfaces.fieldShell(child: child);
}

Future<String?> uploadMemberAvatar({
  required SupabaseClient client,
  required String orgId,
  required String userId,
}) async {
  final picker = ImagePicker();
  final x = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 85,
  );
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  final ext = (x.name.split('.').last).toLowerCase();
  final path = '$orgId/$userId.${ext.isEmpty ? 'jpg' : ext}';
  await client.storage.from('member-avatars').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: x.mimeType ?? 'image/jpeg',
        ),
      );
  return client.storage.from('member-avatars').getPublicUrl(path);
}

/// Opens member details; returns true if saved successfully.
Future<bool> showOrgMemberEditDialog({
  required BuildContext context,
  required WidgetRef ref,
  required OrgMemberRow member,
  required void Function(String message) onError,
}) async {
  final org = ref.read(activeOrganizationProvider);
  if (org == null) return false;
  final client = ref.read(supabaseClientProvider);
  final depts = await ref.read(orgDepartmentsProvider.future);

  final mdRows = await client
      .from('organization_member_departments')
      .select('department_id')
      .eq('organization_id', org.id)
      .eq('user_id', member.userId);
  final hodRows = await client
      .from('organization_department_heads')
      .select('department_id')
      .eq('organization_id', org.id)
      .eq('user_id', member.userId);

  final selectedDepts = <String>{
    for (final e in (mdRows as List))
      Map<String, dynamic>.from(e as Map)['department_id'] as String,
  };
  final hodDepts = <String>{
    for (final e in (hodRows as List))
      Map<String, dynamic>.from(e as Map)['department_id'] as String,
  };

  final nameCtrl = TextEditingController(text: member.fullName ?? '');
  final phoneCtrl = TextEditingController(text: member.phone ?? '');
  final jobCtrl = TextEditingController(text: member.jobTitle ?? '');
  var role = member.role == OrgRoles.owner
      ? OrgRoles.owner
      : OrgRoles.normalize(member.role);
  String? avatarUrl = member.avatarUrl;
  var avatarBusy = false;

  final maxH = MediaQuery.sizeOf(context).height * 0.78;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> pickAvatar() async {
            if (avatarBusy) return;
            setLocal(() => avatarBusy = true);
            try {
              final url = await uploadMemberAvatar(
                client: client,
                orgId: org.id,
                userId: member.userId,
              );
              if (url != null) {
                setLocal(() => avatarUrl = url);
              }
            } catch (e) {
              onError(friendlyError(e));
            } finally {
              setLocal(() => avatarBusy = false);
            }
          }

          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420, maxHeight: maxH),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Member details',
                            style: GlossSurfaces.logoMark.copyWith(
                              fontSize: 17,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.pop(ctx, false),
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: avatarBusy ? null : pickAvatar,
                                customBorder: const CircleBorder(),
                                child: Tooltip(
                                  message: avatarBusy
                                      ? 'Uploading…'
                                      : 'Tap to change photo',
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 32,
                                        backgroundColor: GlossColors.sky
                                            .withValues(alpha: 0.9),
                                        backgroundImage: (avatarUrl != null &&
                                                avatarUrl!.isNotEmpty)
                                            ? NetworkImage(avatarUrl!)
                                            : null,
                                        child: (avatarUrl == null ||
                                                avatarUrl!.isEmpty)
                                            ? const Icon(
                                                Icons.person_outline,
                                                size: 32,
                                                color: GlossColors.navy,
                                              )
                                            : null,
                                      ),
                                      if (avatarBusy)
                                        Container(
                                          width: 64,
                                          height: 64,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: GlossColors.navy
                                                .withValues(alpha: 0.35),
                                          ),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: GlossColors.sky,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (member.email != null) ...[
                            const SizedBox(height: 8),
                            Text(member.email!, style: GlossSurfaces.tileMeta),
                          ],
                          const SizedBox(height: GlossSurfaces.fieldGap),
                          _glossField(
                            child: TextField(
                              controller: nameCtrl,
                              style:
                                  GlossSurfaces.logoMark.copyWith(fontSize: 13),
                              decoration:
                                  GlossSurfaces.compactField('Full name'),
                              textCapitalization: TextCapitalization.words,
                            ),
                          ),
                          const SizedBox(height: GlossSurfaces.fieldGap),
                          _glossField(
                            child: TextField(
                              controller: phoneCtrl,
                              style:
                                  GlossSurfaces.logoMark.copyWith(fontSize: 13),
                              decoration: GlossSurfaces.compactField('Phone'),
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(height: GlossSurfaces.fieldGap),
                          _glossField(
                            child: TextField(
                              controller: jobCtrl,
                              style:
                                  GlossSurfaces.logoMark.copyWith(fontSize: 13),
                              decoration:
                                  GlossSurfaces.compactField('Job title'),
                            ),
                          ),
                          const SizedBox(height: GlossSurfaces.fieldGap),
                          if (member.role != OrgRoles.owner)
                            _glossField(
                              child: DropdownButtonFormField<String>(
                                // ignore: deprecated_member_use
                                value: role,
                                isDense: true,
                                isExpanded: true,
                                iconSize: 18,
                                style: GlossSurfaces.logoMark
                                    .copyWith(fontSize: 13),
                                decoration:
                                    GlossSurfaces.compactField('Role'),
                                items: [
                                  for (final r in OrgRoles.inviteChoices)
                                    DropdownMenuItem(
                                      value: r,
                                      child: Text(
                                        OrgRoles.label(r),
                                        style: GlossSurfaces.logoMark
                                            .copyWith(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (v) => setLocal(
                                    () => role = v ?? OrgRoles.technician),
                              ),
                            )
                          else
                            Text(
                              'Role: Owner / System Admin',
                              style:
                                  GlossSurfaces.logoMark.copyWith(fontSize: 13),
                            ),
                          const SizedBox(height: 12),
                          Text('Departments',
                              style:
                                  GlossSurfaces.logoMark.copyWith(fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to assign · long-press for HoD',
                            style: GlossSurfaces.logoAccent
                                .copyWith(fontSize: 11),
                          ),
                          const SizedBox(height: GlossSurfaces.fieldGap),
                          if (depts.isEmpty)
                            Text('No departments seeded yet.',
                                style: GlossSurfaces.logoAccent)
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final d in depts)
                                  DepartmentChip(
                                    dept: d,
                                    selected: selectedDepts.contains(d.id),
                                    isHod: hodDepts.contains(d.id),
                                    onTap: () {
                                      setLocal(() {
                                        if (selectedDepts.contains(d.id)) {
                                          selectedDepts.remove(d.id);
                                          hodDepts.remove(d.id);
                                        } else {
                                          selectedDepts.add(d.id);
                                        }
                                      });
                                    },
                                    onLongPress: () {
                                      setLocal(() {
                                        if (!selectedDepts.contains(d.id)) {
                                          selectedDepts.add(d.id);
                                        }
                                        if (hodDepts.contains(d.id)) {
                                          hodDepts.remove(d.id);
                                        } else {
                                          hodDepts.add(d.id);
                                        }
                                      });
                                    },
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child:
                              Text('Cancel', style: GlossSurfaces.logoMark),
                        ),
                        const SizedBox(width: 8),
                        GlossSurfaces.glossCta(
                          label: 'SAVE',
                          onTap: () => Navigator.pop(ctx, true),
                          height: 42,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 22),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (saved != true) return false;
  try {
    await client.rpc(
      'update_org_member_details',
      params: {
        'p_organization_id': org.id,
        'p_user_id': member.userId,
        'p_role': member.role == OrgRoles.owner ? null : role,
        'p_full_name': nameCtrl.text.trim(),
        'p_phone': phoneCtrl.text.trim(),
        'p_job_title': jobCtrl.text.trim(),
        'p_avatar_url': avatarUrl,
      },
    );
    await client.rpc(
      'set_org_member_departments',
      params: {
        'p_organization_id': org.id,
        'p_user_id': member.userId,
        'p_department_ids': selectedDepts.toList(),
        'p_hod_department_ids': hodDepts.toList(),
      },
    );
    ref.invalidate(orgMembersProvider);
    ref.invalidate(orgDepartmentsProvider);
    return true;
  } catch (e) {
    onError(friendlyError(e));
    return false;
  }
}
