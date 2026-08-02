import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/clients/client_detail_screen.dart';
import '../features/clients/client_form_screen.dart';
import '../features/clients/clients_list_screen.dart';
import '../features/clients/registration_hub_screen.dart';
import '../features/clients/system_detail_screen.dart';
import '../features/clients/system_form_screen.dart';
import '../features/clients/systems_list_screen.dart';
import '../features/org/create_org_screen.dart';
import '../features/org/home_shell_screen.dart';
import '../features/work/work_lists_screens.dart';
import '../features/work/work_order_detail_screen.dart';
import '../features/work/work_order_form_screen.dart';
import '../features/work/work_request_detail_screen.dart';
import '../features/work/work_request_form_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = ValueNotifier<int>(0);

  ref.listen(authStateProvider, (_, __) {
    authRefresh.value++;
  });

  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final signedIn = ref.read(isSignedInProvider);
      final loggingIn = state.matchedLocation == '/login';

      if (!signedIn && !loggingIn) return '/login';
      if (signedIn && loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeShellScreen(),
      ),
      GoRoute(
        path: '/org/create',
        builder: (context, state) => const CreateOrgScreen(),
      ),
      GoRoute(
        path: '/registration',
        builder: (context, state) => const RegistrationHubScreen(),
      ),
      GoRoute(
        path: '/clients',
        builder: (context, state) => const ClientsListScreen(),
      ),
      GoRoute(
        path: '/clients/new',
        builder: (context, state) => const ClientFormScreen(),
      ),
      GoRoute(
        path: '/clients/:id',
        builder: (context, state) => ClientDetailScreen(
          clientId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/clients/:id/edit',
        builder: (context, state) => ClientFormScreen(
          clientId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/systems',
        builder: (context, state) => const SystemsListScreen(),
      ),
      GoRoute(
        path: '/systems/new',
        builder: (context, state) => SystemFormScreen(
          preselectedClientId: state.uri.queryParameters['clientId'],
        ),
      ),
      GoRoute(
        path: '/systems/:id',
        builder: (context, state) => SystemDetailScreen(
          systemId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/systems/:id/edit',
        builder: (context, state) => SystemFormScreen(
          systemId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/work',
        builder: (context, state) => const WorkHubScreen(),
      ),
      GoRoute(
        path: '/work/requests',
        builder: (context, state) => const WorkRequestsListScreen(),
      ),
      GoRoute(
        path: '/work/requests/new',
        builder: (context, state) => const WorkRequestFormScreen(),
      ),
      GoRoute(
        path: '/work/requests/:id',
        builder: (context, state) => WorkRequestDetailScreen(
          requestId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/work/orders',
        builder: (context, state) => const WorkOrdersListScreen(),
      ),
      GoRoute(
        path: '/work/orders/new',
        builder: (context, state) => const WorkOrderFormScreen(),
      ),
      GoRoute(
        path: '/work/orders/:id',
        builder: (context, state) => WorkOrderDetailScreen(
          orderId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});
