# Team module structure

## Layout

| File | Responsibility |
|------|----------------|
| `org_team_screen.dart` | Hub: search/filters, invite, members, pending |
| `org_team_models.dart` | Models + providers (incl. dept stats) |
| `department_chip.dart` | Dept chip (assign + HoD) |
| `member_edit_dialog.dart` | Member details dialog |
| `org_departments_screen.dart` | Departments CRUD + HoD/headcount |
| `org_roles_screen.dart` | Read-only roles hierarchy + capabilities |

## Routes

| Path | Who |
|------|-----|
| `/org/team` | All members |
| `/org/departments` | Elevated |
| `/org/roles` | All members |

## Shipped on this branch

**P0** — search, filters, pending Resend/Copy/Cancel, email validation, home badge  
**Departments v2** — `orgDepartmentStatsProvider`: HoD names + member counts per dept  
**Roles overview** — hierarchy order, capability blurbs, live member counts, “You”

## Still missing

1. Member full-screen profile / self-serve fields  
2. Owner transfer · invite expiry · bulk invite  
3. Activity log  

Branch: `feature/department-management`
