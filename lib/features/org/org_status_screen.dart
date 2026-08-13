import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import '../auth/auth_providers.dart';
import 'org_providers.dart';

/// Calm status surface when the organisation is not product-active.
/// Clarity without clutter.
class OrgStatusScreen extends ConsumerWidget {
  const OrgStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(activeOrganizationProvider);
    final status = org?.status ?? 'pending';

    final String title;
    final String body;
    switch (status) {
      case 'rejected':
        title = 'Application not approved';
        body = org?.reviewNote?.isNotEmpty == true
            ? org!.reviewNote!
            : 'Peeke Automation did not approve this organisation. '
                'Contact support if you believe this is a mistake.';
        break;
      case 'suspended':
        title = 'Access suspended';
        body = org?.reviewNote?.isNotEmpty == true
            ? org!.reviewNote!
            : 'This organisation is suspended. Contact Peeke Automation.';
        break;
      case 'testing':
        // Expired testing window lands here via hasProductAccess == false
        title = 'Test window ended';
        body =
            'Your evaluation period has ended. Peeke Automation will confirm '
            'full access after review.';
        break;
      default:
        title = 'Under review';
        body =
            'Your organisation application is with Peeke Automation. '
            'You will gain access to CMMS-ERP once it is approved '
            'or granted a test window.';
    }

    return Scaffold(
      backgroundColor: GlossColors.sky,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/branding/peeke_icon.png',
                          height: 96,
                          width: 96,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Text(
                            'Peeke',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              color: GlossColors.navy,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (org != null) ...[
                          Text(
                            org.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: GlossColors.navy,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: GlossColors.navy,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: GlossColors.teal,
                            height: 1.4,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 28),
                        TextButton(
                          onPressed: () async {
                            ref.invalidate(myOrganizationsProvider);
                          },
                          child: const Text(
                            'Refresh status',
                            style: TextStyle(
                              color: GlossColors.teal,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await ref
                                .read(supabaseClientProvider)
                                .auth
                                .signOut();
                            if (context.mounted) context.go('/login');
                          },
                          child: const Text(
                            'Sign out',
                            style: TextStyle(
                              color: GlossColors.navy,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                '© Peeke Automation',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: GlossColors.navy,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
