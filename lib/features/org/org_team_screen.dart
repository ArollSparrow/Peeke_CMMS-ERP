import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/gloss_theme.dart';
import '../../infra/friendly_error.dart';
import '../auth/auth_providers.dart';
import '../auth/login_screen.dart' show authRedirectTo;
import 'member_edit_dialog.dart';
import 'org_providers.dart';
import 'org_roles.dart';
import 'org_team_models.dart';
import 'org_team_invite_panel.dart';

export 'org_team_models.dart';

/// Client-side email check aligned with invite-org-member EMAIL_RE.
final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

enum _TeamFilter { all, pending, role, department }

class OrgTeamScreen extends ConsumerStatefulWidget {
  const OrgTeamScreen({super.key});

  @override
  ConsumerState<OrgTeamScreen> createState() => _OrgTeamScreenState();
}

class _OrgTeamScreenState extends ConsumerState<OrgTeamScreen> {
  final _email = TextEditingController();
  final _search = TextEditingController();
  String _role = OrgRoles.technician;
  bool _busy = false;
  String? _message;
  String? _error;
  String? _actionLink;

  _TeamFilter _filter = _TeamFilter.all;
  String? _filterRole;
  String? _filterDeptName;

  @override
  void dispose() {
    _email.dispose();
    _search.dispose();
    super.dispose();
  }

  Widget _glossField({required Widget child}) {
    return GlossSurfaces.fieldShell(child: child);
  }

  // SEE_ARTIFACTS_FOR_FULL_BODY
}
