import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import '../org/org_providers.dart';
import 'payment_models.dart';

class PaymentRepository {
  PaymentRepository(this._client);
  final SupabaseClient _client;

  Future<PaymentSettings?> getSettings(String orgId, {String provider = 'paystack'}) async {
    final row = await _client
        .from('organization_payment_settings')
        .select()
        .eq('organization_id', orgId)
        .eq('provider', provider)
        .maybeSingle();
    if (row == null) return null;
    return PaymentSettings.fromMap(Map<String, dynamic>.from(row));
  }

  Future<PaymentSettings> upsertSettings({
    required String organizationId,
    String provider = 'paystack',
    required bool isLive,
    required bool isEnabled,
    String? publicKey,
    String? secretKey,
    String? webhookSecret,
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
      if (publicKey != null) 'public_key': publicKey.trim().isEmpty ? null : publicKey.trim(),
      if (businessName != null)
        'business_name': businessName.trim().isEmpty ? null : businessName.trim(),
      if (notes != null) 'notes': notes.trim().isEmpty ? null : notes.trim(),
      if (touchVerified) 'last_verified_at': DateTime.now().toUtc().toIso8601String(),
    };

    // Only overwrite secret if user entered a new non-empty value
    if (secretKey != null && secretKey.trim().isNotEmpty) {
      patch['secret_key'] = secretKey.trim();
    }
    if (webhookSecret != null && webhookSecret.trim().isNotEmpty) {
      patch['webhook_secret'] = webhookSecret.trim();
    }

    if (existing == null) {
      final row = await _client
          .from('organization_payment_settings')
          .insert(patch)
          .select()
          .single();
      return PaymentSettings.fromMap(Map<String, dynamic>.from(row));
    }

    final row = await _client
        .from('organization_payment_settings')
        .update(patch)
        .eq('id', existing.id)
        .select()
        .single();
    return PaymentSettings.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<PaymentTransaction>> listTransactions(String orgId, {int limit = 50}) async {
    final rows = await _client
        .from('payment_transactions')
        .select()
        .eq('organization_id', orgId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((e) => PaymentTransaction.fromMap(Map<String, dynamic>.from(e as Map)))
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
          if (status == 'success') 'paid_at': DateTime.now().toUtc().toIso8601String(),
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
