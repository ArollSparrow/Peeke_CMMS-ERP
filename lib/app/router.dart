import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/clients/client_detail_screen.dart';
import '../features/clients/client_form_screen.dart';
import '../features/clients/clients_list_screen.dart';
import '../features/clients/registration_hub_screen.dart';
import '../features/clients/system_detail_screen.dart';
import '../features/clients/system_form_screen.dart';
import '../features/clients/systems_list_screen.dart';
import '../features/inventory/inventory_screens.dart';
import '../features/maintenance/downtime_list_screen.dart';
import '../features/maintenance/maintenance_record_detail_screen.dart';
import '../features/maintenance/maintenance_screens.dart';
import '../features/maintenance/pm_plan_detail_screen.dart';
import '../features/maintenance/service_history_screen.dart';
import '../features/operations/operations_screens.dart';
import '../features/org/create_org_screen.dart';
import '../features/org/home_shell_screen.dart';
import '../features/payments/payment_screens.dart';
import '../features/platform/platform_providers.dart';
import '../features/platform/platform_screens.dart';
import '../features/procurement/procurement_screens.dart';
import '../features/work/job_card_screen.dart';
import '../features/work/work_lists_screens.dart';
import '../features/work/work_order_detail_screen.dart';
import '../features/work/work_order_form_screen.dart';
import '../features/work/work_request_detail_screen.dart';
import '../features/work/work_request_form_screen.dart';

bool _isPlatformPath(String loc) =>
    loc == '/platform' || loc.startsWith('/platform/');

bool _isAuthPublicPath(String loc) =>
    loc == '/login' || loc == '/reset-password';

bool _isTenantAppPath(String loc) {
  if (loc == '/login' || loc == '/gate' || loc == '/reset-password') return false;
  if (_isPlatformPath(loc)) return false;
  return true;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = ValueNotifier<int>(0);

  ref.listen(authStateProvider, (_, __) {
    authRefresh.value++;
  });

  ref.listen(isPlatformAdminProvider, (_, __) {
    authRefresh.value++;
  });

  ref.listen(passwordRecoveryPendingProvider, (_, __) {
    authRefresh.value++;
  });

  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final signedIn = ref.read(isSignedInProvider);
      final loc = state.matchedLocation;
      final recovery = ref.read(passwordRecoveryPendingProvider);

      if (recovery) {
        if (loc != '/reset-password') return '/reset-password';
        return null;
      }

      if (loc == '/reset-password') {
        if (signedIn) return '/gate';
        return '/login';
      }

      if (!signedIn && !_isAuthPublicPath(loc)) return '/login';
      if (signedIn && loc == '/login') return '/gate';

      final adminAsync = ref.read(isPlatformAdminProvider);
      final isAdmin = adminAsync.valueOrNull;
      if (isAdmin == true && _isTenantAppPath(loc)) {
        return '/platform';
      }
      if (isAdmin == false && _isPlatformPath(loc)) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(path: '/gate', builder: (context, state) => const PostAuthGateScreen()),
      GoRoute(path: '/platform', builder: (context, state) => const PlatformHomeScreen()),
      GoRoute(path: '/platform/tenants', builder: (context, state) => const PlatformTenantsScreen()),
      GoRoute(
        path: '/platform/subscriptions',
        builder: (context, state) => PlatformSubscriptionsScreen(
          preselectedOrgId: state.uri.queryParameters['orgId'],
        ),
      ),
      GoRoute(
        path: '/platform/payments',
        builder: (context, state) => const PlatformPaymentSettingsScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeShellScreen()),
      GoRoute(path: '/org/create', builder: (context, state) => const CreateOrgScreen()),
      GoRoute(path: '/registration', builder: (context, state) => const RegistrationHubScreen()),
      GoRoute(path: '/clients', builder: (context, state) => const ClientsListScreen()),
      GoRoute(path: '/clients/new', builder: (context, state) => const ClientFormScreen()),
      GoRoute(
        path: '/clients/:id',
        builder: (context, state) => ClientDetailScreen(clientId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/clients/:id/edit',
        builder: (context, state) => ClientFormScreen(clientId: state.pathParameters['id']),
      ),
      GoRoute(path: '/systems', builder: (context, state) => const SystemsListScreen()),
      GoRoute(
        path: '/systems/new',
        builder: (context, state) => SystemFormScreen(
          preselectedClientId: state.uri.queryParameters['clientId'],
        ),
      ),
      GoRoute(
        path: '/systems/:id',
        builder: (context, state) => SystemDetailScreen(systemId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/systems/:id/edit',
        builder: (context, state) => SystemFormScreen(systemId: state.pathParameters['id']),
      ),
      GoRoute(path: '/work', builder: (context, state) => const WorkHubScreen()),
      GoRoute(path: '/work/requests', builder: (context, state) => const WorkRequestsListScreen()),
      GoRoute(path: '/work/requests/new', builder: (context, state) => const WorkRequestFormScreen()),
      GoRoute(
        path: '/work/requests/:id',
        builder: (context, state) => WorkRequestDetailScreen(requestId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/work/orders', builder: (context, state) => const WorkOrdersListScreen()),
      GoRoute(path: '/work/orders/new', builder: (context, state) => const WorkOrderFormScreen()),
      GoRoute(
        path: '/work/orders/:id',
        builder: (context, state) => WorkOrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/work/orders/:id/job-card',
        builder: (context, state) =>
            JobCardScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/inventory', builder: (context, state) => const InventoryHubScreen()),
      GoRoute(
        path: '/inventory/parts',
        builder: (context, state) => SparePartsListScreen(
          lowOnly: state.uri.queryParameters['low'] == '1',
        ),
      ),
      GoRoute(path: '/inventory/parts/new', builder: (context, state) => const SparePartFormScreen()),
      GoRoute(
        path: '/inventory/parts/:id',
        builder: (context, state) => SparePartDetailScreen(partId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/inventory/parts/:id/edit',
        builder: (context, state) => SparePartFormScreen(partId: state.pathParameters['id']),
      ),
      GoRoute(path: '/procurement', builder: (context, state) => const ProcurementHubScreen()),
      GoRoute(path: '/procurement/vendors', builder: (context, state) => const VendorsListScreen()),
      GoRoute(path: '/procurement/vendors/new', builder: (context, state) => const VendorFormScreen()),
      GoRoute(
        path: '/procurement/vendors/:id',
        builder: (context, state) => VendorDetailScreen(vendorId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/procurement/vendors/:id/edit',
        builder: (context, state) => VendorFormScreen(vendorId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/procurement/orders',
        builder: (context, state) => const PurchaseOrdersListScreen(),
      ),
      GoRoute(
        path: '/procurement/orders/new',
        builder: (context, state) => PurchaseOrderFormScreen(
          preselectedVendorId: state.uri.queryParameters['vendorId'],
        ),
      ),
      GoRoute(
        path: '/procurement/orders/:id',
        builder: (context, state) =>
            PurchaseOrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/maintenance', builder: (context, state) => const MaintenanceHubScreen()),
      GoRoute(path: '/maintenance/plans', builder: (context, state) => const PmPlansListScreen()),
      GoRoute(
        path: '/maintenance/plans/new',
        builder: (context, state) => PmPlanFormScreen(
          preselectedSystemId: state.uri.queryParameters['systemId'],
        ),
      ),
      GoRoute(
        path: '/maintenance/plans/:id',
        builder: (context, state) => PmPlanDetailScreen(planId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/maintenance/plans/:id/edit',
        builder: (context, state) => PmPlanFormScreen(planId: state.pathParameters['id']),
      ),
      GoRoute(path: '/maintenance/jobs/new', builder: (context, state) => const LogMaintenanceJobScreen()),
      GoRoute(path: '/maintenance/history', builder: (context, state) => const ServiceHistoryScreen()),
      GoRoute(
        path: '/maintenance/history/:id',
        builder: (context, state) => MaintenanceRecordDetailScreen(
          recordId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(path: '/maintenance/downtime', builder: (context, state) => const DowntimeListScreen()),
      GoRoute(path: '/maintenance/technicians', builder: (context, state) => const TechniciansListScreen()),
      GoRoute(path: '/operations', builder: (context, state) => const OperationsHubScreen()),
      GoRoute(path: '/operations/record', builder: (context, state) => const RecordOperationScreen()),
      GoRoute(
        path: '/operations/fueling',
        builder: (context, state) => const RecordOperationScreen(fuelingOnly: true),
      ),
      GoRoute(
        path: '/operations/breakdown',
        builder: (context, state) => const RecordOperationScreen(breakdownOnly: true),
      ),
      GoRoute(path: '/operations/records', builder: (context, state) => const OperationRecordsScreen()),
      GoRoute(path: '/payments', builder: (context, state) => const PaymentsHubScreen()),
      GoRoute(path: '/payments/settings', builder: (context, state) => const PaymentSettingsScreen()),
      GoRoute(
        path: '/payments/transactions',
        builder: (context, state) => const PaymentTransactionsScreen(),
      ),
    ],
  );
});
