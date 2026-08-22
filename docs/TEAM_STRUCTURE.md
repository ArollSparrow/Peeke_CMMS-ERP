# Team module structure

## Why this split

`org_team_screen.dart` previously owned list display, invite flow, pending
invites, member edit, department chips, and call. Concurrent edits collided
constantly. The mechanical split gives product work a clean surface.

## Layout

| File | Responsibility |
|------|----------------|
| `org_team_screen.dart` | Hub: directory search/filters, invite, members, pending |
| `org_team_models.dart` | `OrgMemberRow` / `OrgInviteRow` / `OrgDept` + providers |
| `department_chip.dart` | Reusable gloss dept chip (assign + HoD) |
| `member_edit_dialog.dart` | Member details dialog + save |
| `org_departments_screen.dart` | Create / rename / soft-deactivate departments |

## Department management

- Route: `/org/departments` (elevated roles)
- Team AppBar → departments icon when elevated
- RPCs: `create_org_department`, `rename_org_department`, `set_org_department_active`
- Column `organization_departments.is_active` (soft deactivate; no hard delete)
- Member edit lists **active** departments (+ already-assigned inactive)

## Team hub P0 (this branch)

- **Search** — name, email, title, phone, role, departments
- **Filter chips** — All · Pending · Role (picker) · Department (picker)
- **Elevated list meta** — org role shown first on member tiles for admins
- **Pending actions** — Resend · Copy invite link · Cancel
- **Email validation** — client regex aligned with invite edge function
- **Home tile** — “Directory, invites & departments” + member count badge

## Still missing (product)

1. **Roles overview** — read-only hierarchy + short capability notes
2. **Member full-screen profile** / self-serve profile fields
3. **Departments v2** — headcount + HoD on each row
4. **Owner transfer** · invite expiry · bulk invite
5. **Activity log** — later, multi-tenant audit

## Process note

Suggestions land in chat first; branches are cut and implemented here.
Branch: `feature/department-management` (CI preview enabled).
