# Team module structure

## Why this split

`org_team_screen.dart` previously owned list display, invite flow, pending
invites, member edit, department chips, and call. Concurrent edits collided
constantly. Claude correctly diagnosed that; this branch does the mechanical
split so later product work has a clean surface.

## Layout

| File | Responsibility |
|------|----------------|
| `org_team_screen.dart` | Hub: invite form, member tiles, pending tiles, call |
| `org_team_models.dart` | `OrgMemberRow` / `OrgInviteRow` / `OrgDept` + providers |
| `department_chip.dart` | Reusable gloss dept chip (assign + HoD) |
| `member_edit_dialog.dart` | Member details dialog + save |
| `org_departments_screen.dart` | Create / rename / soft-deactivate departments |

## Department management (shipped on `feature/department-management`)

- Route: `/org/departments` (elevated roles)
- Team AppBar → departments icon when elevated
- RPCs: `create_org_department`, `rename_org_department`, `set_org_department_active`
- Column `organization_departments.is_active` (soft deactivate; no hard delete)
- Member edit lists **active** departments only

## Still missing (product)

1. **Roles overview** — read-only hierarchy from one source of truth.
2. **Activity log** — later, when multi-tenant scale needs audit.

## Process note

Suggestions land in chat first; branches are cut and implemented here.
