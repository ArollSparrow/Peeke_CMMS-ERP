/// Tenant org roles and departments (fixed catalog for all tenants).
/// Owner remains special (billing / lifecycle). System Admin capability
/// is implied by [OrgRoles.owner] by default (IT HoD on org create).
class OrgRoles {
  static const owner = 'owner';
  static const systemAdmin = 'system_admin';
  static const ceo = 'ceo';
  static const generalManager = 'general_manager';
  static const hod = 'hod';
  static const supervisor = 'supervisor';
  static const admin = 'admin';
  static const officer = 'officer';
  static const technician = 'technician';
  static const operator = 'operator';

  /// Legacy value still accepted by DB until fully migrated.
  static const memberLegacy = 'member';

  /// Roles that may manage team, settings, invites.
  static const elevated = {
    owner,
    systemAdmin,
    admin,
    ceo,
    generalManager,
  };

  /// Roles selectable when inviting (never owner).
  static const inviteChoices = <String>[
    technician,
    operator,
    officer,
    supervisor,
    hod,
    admin,
    generalManager,
    ceo,
    systemAdmin,
  ];

  /// All assignable roles including owner (edit UI only for non-owner change).
  static const all = <String>[
    owner,
    systemAdmin,
    ceo,
    generalManager,
    hod,
    supervisor,
    admin,
    officer,
    technician,
    operator,
  ];

  /// Display order for Roles overview (authority top → field).
  static const hierarchy = <String>[
    owner,
    systemAdmin,
    ceo,
    generalManager,
    admin,
    hod,
    supervisor,
    officer,
    technician,
    operator,
  ];

  static String label(String? code) {
    switch (code) {
      case owner:
        return 'Owner / System Admin';
      case systemAdmin:
        return 'System Admin';
      case ceo:
        return 'CEO';
      case generalManager:
        return 'General Manager';
      case hod:
        return 'HoD';
      case supervisor:
        return 'Supervisor';
      case admin:
        return 'Admin';
      case officer:
        return 'Officer';
      case technician:
      case memberLegacy:
        return 'Technician';
      case operator:
        return 'Operator';
      default:
        return code ?? '—';
    }
  }

  /// Short capability note for Roles overview (product language, not ACL matrix).
  static String capability(String? code) {
    switch (normalize(code)) {
      case owner:
        return 'Full org control · billing & lifecycle · invite & team · all modules';
      case systemAdmin:
        return 'Technical admin · team & settings · same elevated tools as Admin';
      case ceo:
        return 'Executive oversight · elevated team & org settings';
      case generalManager:
        return 'Operations leadership · elevated team & org settings';
      case admin:
        return 'Day-to-day admin · invites, members, departments';
      case hod:
        return 'Department head · leads assigned depts (set on member profile)';
      case supervisor:
        return 'Supervises field work · approvals where policy allows';
      case officer:
        return 'Office / coordination · standard module access';
      case technician:
        return 'Field maintenance · work orders, jobs, service history';
      case operator:
        return 'Plant operations · start/stop, fuel, breakdown records';
      default:
        return 'Standard member access';
    }
  }

  static bool isElevatedRole(String? code) =>
      elevated.contains(normalize(code));

  static String normalize(String? code) {
    if (code == null || code.isEmpty) return technician;
    if (code == memberLegacy) return technician;
    return code;
  }
}

class OrgDepartments {
  static const codes = <String>[
    'administration',
    'finance',
    'procurement',
    'engineering',
    'warehouse',
    'operations',
    'hr',
    'it',
  ];

  static String label(String code) {
    switch (code) {
      case 'administration':
        return 'Administration';
      case 'finance':
        return 'Finance';
      case 'procurement':
        return 'Procurement';
      case 'engineering':
        return 'Engineering';
      case 'warehouse':
        return 'Warehouse';
      case 'operations':
        return 'Operations';
      case 'hr':
        return 'HR';
      case 'it':
        return 'IT';
      default:
        return code;
    }
  }
}
