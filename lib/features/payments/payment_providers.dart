import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import '../org/org_providers.dart';
import 'payment_models.dart';

/// Non-secret columns only — secrets are column-revoked for authenticated.
const _settingsSelect =
    'id, organization_id, provider, is_live, public_key, currency, business_name, '
    'is_enabled, last_verified_at, notes, created_at, updated_at';

class PaymentRepository {
  PaymentRepository(this._client);
  final SupabaseClient _client;

  Future<PaymentSettings?> getSettings(String orgId,
      {String provider = 'paystack'}) async {
    final row = await _client
        .from('organization_payment_settings')
        .select(_settingsSelect)
        .eq('organization_id', orgId)
        .eq('provider', provider)
        .maybeSingle();
    if (row == null) return null;

    final flags = await _client.rpc(
      'organization_payment_secret_flags',
      params: {
        'p_organization_id': orgId,
        'p_provider': provider,
      },
    );

    final map = Map<String, dynamic>.from(row);
    if (flags is List && flags.isNotEmpty) {
      final f = Map<String, dynamic>.from(flags.first as Map);
      map['has_secret_key'] = f['has_secret_key'] == true;
      map['has_webhook_secret'] = f['has_webhook_secret'] == true;
    }
    return PaymentSettings.fromMap(map);
  }

  /// Upsert non-secret fields only. Secrets go through [setSecrets].
  Future<PaymentSettings> upsertSettings({
    required String organizationId,
    String provider = 'paystack',
    required bool isLive,
    required bool isEnabled,
    String? publicKey,
    String currency = 'KES',
    String? businessName,
    String? notes,
    bool touchVerified = false,
  }) async {
    final existing = await getSettings(organizationId, provider: provider);
    final patch = <String, dynamic>{
      'organization_id': organizationId,
      'provider': provider,
      'is_live': isLive,
      'is_enabled': isEnabled,
      'currency': currency,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (publicKey != null)
        'public_key': publicKey.trim().isEmpty ? null : publicKey.trim(),
      if (businessName != null)
        'business_name':
            businessName.trim().isEmpty ? null : businessName.trim(),
      if (notes != null) 'notes': notes.trim().isEmpty ? null : notes.trim(),
      if (touchVerified)
        'last_verified_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (existing == null) {
      final row = await _client
          .from('organization_payment_settings')
          .insert(patch)
          .select(_settingsSelect)
          .single();
      return PaymentSettings.fromMap(Map<String, dynamic>.from(row));
    }

    final row = await _client
        .from('organization_payment_settings')
        .update(patch)
        .eq('id', existing.id)
        .select(_settingsSelect)
        .single();
    return PaymentSettings.fromMap(Map<String, dynamic>.from(row));
  }

  /// Write secrets via SECURITY DEFINER RPC — values are never returned.
  Future<void> setSecrets({
    required String organizationId,
    String provider = 'paystack',
    String? secretKey,
    String? webhookSecret,
  }) async {
    await _client.rpc(
      'set_organization_payment_secrets',
      params: {
        'p_organization_id': organizationId,
        'p_provider': provider,
        if (secretKey != null && secretKey.trim().isNotEmpty)
          'p_secret_key': secretKey.trim(),
        if (webhookSecret != null && webhookSecret.trim().isNotEmpty)
          'p_webhook_secret': webhookSecret.trim(),
      },
    );
  }

  Future<List<PaymentTransaction>> listTransactions(String orgId,
      {int limit = 50}) async {
    final rows = await _client
        .from('payment_transactions')
        .select()
        .eq('organization_id', orgId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((e) =>
            PaymentTransaction.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<PaymentTransaction> recordTransaction({
    required String organizationId,
    required String reference,
    required double amount,
    String currency = 'KES',
    String status = 'pending',
    String? customerEmail,
    String? customerName,
    String? description,
    String? clientId,
  }) async {
    final row = await _client
        .from('payment_transactions')
        .insert({
          'organization_id': organizationId,
          'reference': reference,
          'amount': amount,
          'currency': currency,
          'status': status,
          if (customerEmail != null) 'customer_email': customerEmail,
          if (customerName != null) 'customer_name': customerName,
          if (description != null) 'description': description,
          if (clientId != null) 'client_id': clientId,
          if (status == 'success')
            'paid_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();
    return PaymentTransaction.fromMap(Map<String, dynamic>.from(row));
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(supabaseClientProvider));
});

final paymentSettingsProvider =
    FutureProvider.autoDispose<PaymentSettings?>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return null;
  return ref.watch(paymentRepositoryProvider).getSettings(org.id);
});

final paymentTransactionsProvider =
    FutureProvider.autoDispose<List<PaymentTransaction>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  return ref.watch(paymentRepositoryProvider).listTransactions(org.id);
});
