import 'package:flutter/material.dart';

import '../../design/gloss_theme.dart';
import 'org_roles.dart';
import 'org_team_models.dart';

/// Member plate: role·title meta, name, call + overflow menu.
class OrgMemberTile extends StatelessWidget {
  const OrgMemberTile({
    super.key,
    required this.member,
    required this.isMe,
    required this.canManage,
    required this.onTap,
    required this.onCall,
    required this.onEdit,
    required this.onRemove,
  });

  final OrgMemberRow member;
  final bool isMe;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onCall;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final m = member;
    final name = (m.fullName != null && m.fullName!.trim().isNotEmpty)
        ? m.fullName!.trim()
        : 'Team member';
    final title = (m.jobTitle != null && m.jobTitle!.trim().isNotEmpty)
        ? m.jobTitle!.trim()
        : null;
    final hasPhone = (m.phone != null && m.phone!.trim().isNotEmpty);
    final nameLine = isMe ? '$name · You' : name;
    final metaParts = <String>[];
    if (canManage) metaParts.add(OrgRoles.label(m.role));
    if (title != null) metaParts.add(title);
    final metaLine = metaParts.isEmpty ? '—' : metaParts.join(' · ');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: GlossSurfaces.tileMinHeight,
        margin: const EdgeInsets.only(bottom: GlossSurfaces.fieldGap),
        decoration: GlossSurfaces.plate,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 2, 0),
          child: Row(
            children: [
              _avatar(m.avatarUrl),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(metaLine,
                        style: GlossSurfaces.tileMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(nameLine,
                        style: GlossSurfaces.tileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (hasPhone)
                IconButton(
                  tooltip: 'Call ${m.phone}',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.call_outlined,
                      color: GlossColors.tealDeep, size: 20),
                  onPressed: onCall,
                ),
              if (canManage)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.more_vert,
                      color: GlossColors.tealDeep, size: 20),
                  color: GlossColors.sky,
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'remove') onRemove();
                    if (value == 'call') onCall();
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit', style: GlossSurfaces.logoMark)),
                    if (hasPhone)
                      PopupMenuItem(
                          value: 'call',
                          child:
                              Text('Call', style: GlossSurfaces.logoMark)),
                    if (!isMe && m.role != OrgRoles.owner)
                      PopupMenuItem(
                          value: 'remove',
                          child:
                              Text('Remove', style: GlossSurfaces.logoMark)),
                  ],
                )
              else if (!hasPhone)
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(String? url) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: GlossColors.sky,
        border: Border.all(
          color: GlossColors.navy.withValues(alpha: 0.28),
          width: 1.5,
        ),
        image: (url != null && url.isNotEmpty)
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      child: (url == null || url.isEmpty)
          ? const Icon(Icons.person_outline, color: GlossColors.navy, size: 17)
          : null,
    );
  }
}

/// Pending invite plate with resend / copy link / cancel.
class OrgInviteTile extends StatelessWidget {
  const OrgInviteTile({
    super.key,
    required this.invite,
    required this.canManage,
    required this.onResend,
    required this.onCopyLink,
    required this.onCancel,
  });

  final OrgInviteRow invite;
  final bool canManage;
  final VoidCallback onResend;
  final VoidCallback onCopyLink;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final i = invite;
    return Container(
      width: double.infinity,
      height: GlossSurfaces.tileMinHeight,
      margin: const EdgeInsets.only(bottom: GlossSurfaces.fieldGap),
      decoration: GlossSurfaces.plate,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 2, 0),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GlossColors.sky,
                border: Border.all(
                  color: GlossColors.navy.withValues(alpha: 0.28),
                  width: 1.5,
                ),
              ),
              child: const Icon(Icons.mail_outline,
                  color: GlossColors.tealDeep, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    [
                      OrgRoles.label(i.role),
                      'pending',
                      if (i.ageLabel.isNotEmpty) i.ageLabel,
                      if (i.isStale) 'expiring',
                    ].join(' · '),
                    style: GlossSurfaces.tileMeta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(i.email,
                      style: GlossSurfaces.tileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (canManage)
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(Icons.more_vert,
                    color: GlossColors.tealDeep, size: 20),
                color: GlossColors.sky,
                onSelected: (v) {
                  if (v == 'resend') onResend();
                  if (v == 'copy') onCopyLink();
                  if (v == 'cancel') onCancel();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'resend',
                      child: Text('Resend invite',
                          style: GlossSurfaces.logoMark)),
                  PopupMenuItem(
                      value: 'copy',
                      child: Text('Copy invite link',
                          style: GlossSurfaces.logoMark)),
                  PopupMenuItem(
                      value: 'cancel',
                      child: Text('Cancel invite',
                          style: GlossSurfaces.logoMark)),
                ],
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// Filter chip used on Team hub.
class OrgTeamFilterChip extends StatelessWidget {
  const OrgTeamFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GlossSurfaces.tileRadius),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration:
                selected ? GlossSurfaces.navyPlate : GlossSurfaces.plate,
            child: Text(
              label,
              style: GlossSurfaces.tileName.copyWith(
                color: selected ? GlossColors.sky : GlossColors.navy,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
