# Team module structure

## Why this split

`org_team_screen.dart` previously owned list display, invite flow, pending
invites, member edit, department chips, and call. Concurrent edits collided
constantly. Claude correctly diagnosed that; this branch does the mechanical
split so later product work has a clean surface.

## Layout (this branch)

| File | Responsibility |
|------|----------------|
| `org_team_screen.dart` | Hub: invite form, member tiles, pending tiles, call |
| `org_team_models.dart` | `OrgMemberRow` / `OrgInviteRow` / `OrgDept` + providers |
| `department_chip.dart` | Reusable gloss dept chip (assign + HoD) |
| `member_edit_dialog.dart` | Member details dialog + save |

## Still missing (product — not started here)

1. **Department management** — create / rename / deactivate in-app (today only seed + assign).
2. **Roles overview** — read-only hierarchy from one source of truth.
3. **Activity log** — later, when multi-tenant scale needs audit.

## Process note

Suggestions (Claude or otherwise) land in chat first; branches are cut and
implemented here. Gloss-only work remains on `redesign/gloss-full-round-edges` (PR #24).
