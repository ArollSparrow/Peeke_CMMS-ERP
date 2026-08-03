class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.amount = 0,
    this.currency = 'KES',
    this.interval = 'month',
    this.isActive = true,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final double amount;
  final String currency;
  final String interval;
  final bool isActive;

  factory SubscriptionPlan.fromMap(Map<String, dynamic> m) => SubscriptionPlan(
        id: m['id'] as String,
        code: m['code'] as String,
        name: m['name'] as String,
        description: m['description'] as String?,
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        currency: m['currency'] as String? ?? 'KES',
        interval: m['interval'] as String? ?? 'month',
        isActive: m['is_active'] as bool? ?? true,
      );

  String get priceLabel =>
      '$currency ${amount.toStringAsFixed(0)} / $interval';
}

class OrgSubscription {
  const OrgSubscription({
    required this.id,
    required this.organizationId,
    this.planId,
    this.status = 'trialing',
    this.amount,
    this.currency = 'KES',
    this.billingInterval = 'month',
    this.trialEndsAt,
    this.currentPeriodEnd,
    this.lastPaymentAt,
    this.notes,
    this.organizationName,
    this.organizationSlug,
    this.planName,
  });

  final String id;
  final String organizationId;
  final String? planId;
  final String status;
  final double? amount;
  final String currency;
  final String billingInterval;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEnd;
  final DateTime? lastPaymentAt;
  final String? notes;
  final String? organizationName;
  final String? organizationSlug;
  final String? planName;

  factory OrgSubscription.fromMap(Map<String, dynamic> m) {
    final org = m['organizations'] as Map<String, dynamic>?;
    final plan = m['subscription_plans'] as Map<String, dynamic>?;
    return OrgSubscription(
      id: m['id'] as String,
      organizationId: m['organization_id'] as String,
      planId: m['plan_id'] as String?,
      status: m['status'] as String? ?? 'trialing',
      amount: (m['amount'] as num?)?.toDouble(),
      currency: m['currency'] as String? ?? 'KES',
      billingInterval: m['billing_interval'] as String? ?? 'month',
      trialEndsAt: m['trial_ends_at'] != null
          ? DateTime.tryParse(m['trial_ends_at'].toString())
          : null,
      currentPeriodEnd: m['current_period_end'] != null
          ? DateTime.tryParse(m['current_period_end'].toString())
          : null,
      lastPaymentAt: m['last_payment_at'] != null
          ? DateTime.tryParse(m['last_payment_at'].toString())
          : null,
      notes: m['notes'] as String?,
      organizationName: org?['name'] as String?,
      organizationSlug: org?['slug'] as String?,
      planName: plan?['name'] as String?,
    );
  }
}

class PlatformPaymentSettings {
  const PlatformPaymentSettings({
    required this.id,
    this.provider = 'paystack',
    this.isLive = false,
    this.publicKey,
    this.secretKey,
    this.currency = 'KES',
    this.businessName,
    this.isEnabled = false,
  });

  final String id;
  final String provider;
  final bool isLive;
  final String? publicKey;
  final String? secretKey;
  final String currency;
  final String? businessName;
  final bool isEnabled;

  factory PlatformPaymentSettings.fromMap(Map<String, dynamic> m) =>
      PlatformPaymentSettings(
        id: m['id'] as String,
        provider: m['provider'] as String? ?? 'paystack',
        isLive: m['is_live'] as bool? ?? false,
        publicKey: m['public_key'] as String?,
        secretKey: m['secret_key'] as String?,
        currency: m['currency'] as String? ?? 'KES',
        businessName: m['business_name'] as String?,
        isEnabled: m['is_enabled'] as bool? ?? false,
      );

  bool get isConfigured =>
      (publicKey?.isNotEmpty ?? false) && (secretKey?.isNotEmpty ?? false);

  static String maskKey(String? key) {
    if (key == null || key.isEmpty) return 'Not set';
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 8)}••••${key.substring(key.length - 4)}';
  }
}

class TenantOrgSummary {
  const TenantOrgSummary({
    required this.id,
    required this.name,
    required this.slug,
    this.status = 'active',
    this.createdAt,
    this.subscriptionStatus,
    this.planName,
  });

  final String id;
  final String name;
  final String slug;
  final String status;
  final DateTime? createdAt;
  final String? subscriptionStatus;
  final String? planName;

  factory TenantOrgSummary.fromMap(Map<String, dynamic> m) => TenantOrgSummary(
        id: m['id'] as String,
        name: m['name'] as String,
        slug: m['slug'] as String,
        status: m['status'] as String? ?? 'active',
        createdAt: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'].toString())
            : null,
      );
}
