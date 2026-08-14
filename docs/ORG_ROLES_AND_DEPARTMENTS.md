# Org roles, departments & personal details

**Last updated:** 2026-08-14  
**Status:** Schema + Team UI live on Supabase `tappfahlaiixctyliesz`

---

## Roles (primary role per member)

| Code | Label |
|------|--------|
| `owner` | Owner / System Admin (tenant creator; not inviteable) |
| `system_admin` | System Admin |
| `ceo` | CEO |
| `general_manager` | General Manager |
| `hod` | HoD |
| `supervisor` | Supervisor |
| `admin` | Admin |
| `officer` | Officer |
| `technician` | Technician (default invite) |
| `operator` | Operator |

Legacy `member` is normalised to **technician**.

**Elevated (team / settings):** `owner`, `system_admin`, `admin`, `ceo`, `general_manager`.

---

## Departments (seeded per org)

Administration · Finance · Procurement · Engineering · Warehouse · Operations · HR · **IT**

- Member ↔ departments: many-to-many (`organization_member_departments`)
- HoD ↔ departments: many-to-many (`organization_department_heads`) — one person can head multiple depts

**Default on org create:** Owner is **HoD of IT** and treated as **System Admin** (role remains `owner`).

---

## Personal details

Stored on `organization_members`:

- `full_name`
- `phone`
- `job_title`

Captured on **Join your team** (name + optional phone) and editable by elevated users on **Team → Edit**.

Auth user metadata also stores `full_name` / `display_name` / `phone` for recovery.

---

## Invite vs assign

| Step | Behaviour |
|------|-----------|
| Invite | Default role **Technician**; elevated can pick any non-owner role |
| Join | Full name + phone + password |
| After join | Admins edit role, name, phone, job title |

---

## RPCs

- `list_org_team(org_id)` — directory with email + details
- `update_org_member_details(...)` — admin update role + details
- `update_my_org_profile(...)` — self-service name/phone/title
- `set_org_member_departments(...)` — departments + HoD flags
- `seed_organization_departments(org_id)` — 8 default depts

---

## Next

- Department picker UI on Team
- Wire role gates to work-order approval
- Self-service profile screen for members
