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
| `org_member_profile_screen.dart` | Full-screen profile + self-serve |
| `org_activity_screen.dart` | Elevated audit trail |

## Routes

| Path | Who |
|------|-----|
| `/org/team` | All members |
| `/org/roles` | All members |
| `/org/team/:userId` | All members (self-serve for own) |
| `/org/team/activity` | Elevated |
| `/org/departments` | Elevated |

## Shipped on this branch

**P0** — search, filters, pending Resend/Copy/Cancel, email validation, home badge  
**Departments v2** — `orgDepartmentStatsProvider`: HoD names + member counts per dept  
**Roles overview** — hierarchy order, capability blurbs, live member counts, “You”  
**Member profile** — full-screen view, self-serve name/phone/title/photo, elevated full edit  
**Owner transfer** — `transfer_org_ownership` RPC; owner-only on member profile  
**Invite age** — pending tiles show age; **expiring** flag after 7 days  
**Bulk invite** — elevated Team hub → Bulk invite… (multi-line emails, one role)

**Activity log** — `organization_activity` + `log_org_activity`; Team AppBar history icon

## Still missing

_(Team roadmap items on this branch are complete.)_

Branch: `feature/department-management`
