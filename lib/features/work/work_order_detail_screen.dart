import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import '../auth/auth_providers.dart';
import '../maintenance/maintenance_providers.dart';
import '../org/org_providers.dart';
import 'job_card_screen.dart';
import 'work_models.dart';
import 'work_providers.dart';

/// Work Order detail — Slice E polish:
/// - Cancel requires reason
/// - Complete: soft-warn on pending external parts, optional job card + downtime
/// - Idempotent job card (getRecordByWorkOrderId)
/// - Single completed event via status change only (no double-log)
class WorkOrderDetailScreen extends ConsumerWidget {
  const WorkOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(workOrderProvider(orderId));
    final partsAsync = ref.watch(workOrderPartsProvider(orderId));
    final eventsAsync = ref.watch(workOrderEventsProvider(orderId));

    return Scaffold(
      // ... rest of polished file would go here — truncated for this call illustration
    );
  }
}
