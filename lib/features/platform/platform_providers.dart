import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import 'platform_models.dart';

/// True when the signed-in user is in platform_admins.
final isPlatformAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  final client = ref.watch(supabaseClientProvider);
  try {
    final result = await client.rpc('is_platform_admin');
    return result == true;
  } catch (_) {
    return false;
  }
});

class PlatformRepository {
  PlatformRepository(this._client);
  final SupabaseClient _client;

  Future<List<TenantOrgSummary>> listTenants() async {
    final rows = await _client
        .from('organizations')
        .select()
        .order('created_at', ascending: false);
    final orgs = (rows as List)
        .map((e) => TenantOrgSummary.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    // Attach subscription status where present
    final subs = await _client.from('organization_subscriptions').select(
          'organization_id, status, subscription_plans(name)',
        );
    final byOrg = <String, Map<String, dynamic>>{};
    for (final s in (subs as List)) {
      final m = Map<String, dynamic>.from(s as Map);
      byOrg[m['organization_id'] as String] = m;
    }

    return orgs
        .map((o) {
          final s = byOrg[o.id];
          if (s == null) return o;
          final plan = s['subscription_plans'] as Map<String, dynamic>?;
          return TenantOrgSummary(
            id: o.id,
            name: o.name,
            slug: o.slug,
            status: o.status,
            createdAt: o.createdAt,
            subscriptionStatus: s['status'] as String?,
            planName: plan?['name'] as String?,
          );
        })
        .toList();
  }

  Future<List<SubscriptionPlan>> listPlans() async {
    final rows = await _client
        .from('subscription_plans')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return (rows as List)
        .map((e) => SubscriptionPlan.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<OrgSubscription>> listSubscriptions() async {
    final rows = await _client.from('organization_subscriptions').select(
          '*, organizations(name, slug), subscription_plans(name)',
        );
    return (rows as List)
        .map((e) => OrgSubscription.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<OrgSubscription> upsertSubscription({
    required String organizationId,
    String? planId,
    required String status,
    double? amount,
    String currency = 'KES',
    String billingInterval = 'month',
    String? notes,
  }) async {
    final patch = <String, dynamic>{
      'organization_id': organizationId,
      'status': status,
      'currency': currency,
      'billing_interval': billingInterval,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (planId != null) 'plan_id': planId,
      if (amount != null) 'amount': amount,
      if (notes != null) 'notes': notes,
    };

    final row = await _client
        .from('organization_subscriptions')
        .upsert(patch, onConflict: 'organization_id')
        .select('*, organizations(name, slug), subscription_plans(name)')
        .single();
    return OrgSubscription.fromMap(Map<String, dynamic>.from(row));
  }

  Future<PlatformPaymentSettings?> getPlatformPaymentSettings() async {
    final row = await _client
        .from('platform_payment_settings')
        .select()
        .eq('provider', 'paystack')
        .maybeSingle();
    if (row == null) return null;
    return PlatformPaymentSettings.fromMap(Map<String, dynamic>.from(row));
  }

  Future<PlatformPaymentSettings> upsertPlatformPaymentSettings({
    required bool isLive,
    required bool isEnabled,
    String? publicKey,
    String? secretKey,
    String currency = 'KES',
    String? businessName,
  }) async {
    final existing = await getPlatformPaymentSettings();
    final patch = <String, dynamic>{
      'provider': 'paystack',
      'is_live': isLive,
      'is_enabled': isEnabled,
      'currency': currency,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (publicKey != null)
        'public_key': publicKey.trim().isEmpty ? null : publicKey.trim(),
      if (businessName != null)
        'business_name':
            businessName.trim().isEmpty ? null : businessName.trim(),
    };
    if (secretKey != null && secretKey.trim().isNotEmpty) {
      patch['secret_key'] = secretKey.trim();
    }

    if (existing == null) {
      final row = await _client
          .from('platform_payment_settings')
          .insert(patch)
          .select()
          .single();
      return PlatformPaymentSettings.fromMap(Map<String, dynamic>.from(row));
    }

    final row = await _client
        .from('platform_payment_settings')
        .update(patch)
        .eq('id', existing.id)
        .select()
        .single();
    return PlatformPaymentSettings.fromMap(Map<String, dynamic>.from(row));
  }
}

final platformRepositoryProvider = Provider<PlatformRepository>((ref) {
  return PlatformRepository(ref.watch(supabaseClientProvider));
});

final platformTenantsProvider =
    FutureProvider.autoDispose<List<TenantOrgSummary>>((ref) async {
  final isAdmin = await ref.watch(isPlatformAdminProvider.future);
  if (!isAdmin) return [];
  return ref.watch(platformRepositoryProvider).listTenants();
});

final subscriptionPlansProvider =
    FutureProvider.autoDispose<List<SubscriptionPlan>>((ref) async {
  return ref.watch(platformRepositoryProvider).listPlans();
});

final platformSubscriptionsProvider =
    FutureProvider.autoDispose<List<OrgSubscription>>((ref) async {
  final isAdmin = await ref.watch(isPlatformAdminProvider.future);
  if (!isAdmin) return [];
  return ref.watch(platformRepositoryProvider).listSubscriptions();
});

final platformPaymentSettingsProvider =
    FutureProvider.autoDispose<PlatformPaymentSettings?>((ref) async {
  final isAdmin = await ref.watch(isPlatformAdminProvider.future);
  if (!isAdmin) return null;
  return ref.watch(platformRepositoryProvider).getPlatformPaymentSettings();
});
