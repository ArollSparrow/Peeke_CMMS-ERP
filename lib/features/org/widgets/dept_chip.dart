import 'package:flutter/material.dart';

import '../../../design/gloss_theme.dart';
import '../org_team_screen.dart' show OrgDept;

/// A single department chip used in the member-edit dialog's department
/// picker. Pure function of its parameters — no ref/context coupling —
/// extracted verbatim from org_team_screen.dart's old `_deptChip` method.
class DeptChip extends StatelessWidget {
  const DeptChip({
    super.key,
    required this.dept,
    required this.selected,
    required this.isHod,
    required this.onTap,
    required this.onLongPress,
  });

  final OrgDept dept;
  final bool selected;
  final bool isHod;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final label = isHod ? '${dept.name} · HoD' : dept.name;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
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
    );
  }
}
