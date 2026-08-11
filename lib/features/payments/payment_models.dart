class PaymentSettings {
  const PaymentSettings({
    required this.id,
    required this.organizationId,
    this.provider = 'paystack',
    this.isLive = false,
    this.publicKey,
    this.currency = 'KES',
    this.businessName,
    this.isEnabled = false,
    this.lastVerifiedAt,
    this.notes,
    this.hasSecretKey = false,
    this.hasWebhookSecret = false,
  });

  final String id;
  final String organizationId;
  final String provider;
  final bool isLive;
  final String? publicKey;
  final String currency;
  final String? businessName;
  final bool isEnabled;
  final DateTime? lastVerifiedAt;
  final String? notes;

  /// Server-side flags only — secrets never leave the database to the client.
  final bool hasSecretKey;
  final bool hasWebhookSecret;

  factory PaymentSettings.fromMap(Map<String, dynamic> m) => PaymentSettings(
        id: m['id'] as String,
        organizationId: m['organization_id'] as String,
        provider: m['provider'] as String? ?? 'paystack',
        isLive: m['is_live'] as bool? ?? false,
        publicKey: m['public_key'] as String?,
        currency: m['currency'] as String? ?? 'KES',
        businessName: m['business_name'] as String?,
        isEnabled: m['is_enabled'] as bool? ?? false,
        lastVerifiedAt: m['last_verified_at'] != null
            ? DateTime.tryParse(m['last_verified_at'].toString())
            : null,
        notes: m['notes'] as String?,
        hasSecretKey: m['has_secret_key'] as bool? ?? false,
        hasWebhookSecret: m['has_webhook_secret'] as bool? ?? false,
      );

  bool get hasPublicKey => publicKey != null && publicKey!.trim().isNotEmpty;
  bool get isConfigured => hasPublicKey && hasSecretKey;

  String get statusLabel {
    if (!isEnabled) return 'Disabled';
    if (!isConfigured) return 'Incomplete';
    return isLive ? 'Live' : 'Test mode';
  }

  static String maskKey(String? key) {
    if (key == null || key.isEmpty) return 'Not set';
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 8)}••••${key.substring(key.length - 4)}';
  }
}

class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    required this.organizationId,
    required this.reference,
    this.provider = 'paystack',
    this.amount = 0,
    this.currency = 'KES',
    this.status = 'pending',
    this.customerEmail,
    this.customerName,
    this.description,
    this.clientId,
    this.paidAt,
    this.createdAt,
  });

  final String id;
  final String organizationId;
  final String reference;
  final String provider;
  final double amount;
  final String currency;
  final String status;
  final String? customerEmail;
  final String? customerName;
  final String? description;
  final String? clientId;
  final DateTime? paidAt;
  final DateTime? createdAt;

  factory PaymentTransaction.fromMap(Map<String, dynamic> m) =>
      PaymentTransaction(
        id: m['id'] as String,
        organizationId: m['organization_id'] as String,
        reference: m['reference'] as String,
        provider: m['provider'] as String? ?? 'paystack',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        currency: m['currency'] as String? ?? 'KES',
        status: m['status'] as String? ?? 'pending',
        customerEmail: m['customer_email'] as String?,
        customerName: m['customer_name'] as String?,
        description: m['description'] as String?,
        clientId: m['client_id'] as String?,
        paidAt: m['paid_at'] != null
            ? DateTime.tryParse(m['paid_at'].toString())
            : null,
        createdAt: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'].toString())
            : null,
      );
}
