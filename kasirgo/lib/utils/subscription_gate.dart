import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_theme.dart';
import '../config/constants.dart';

class SubscriptionGate {
  static const int freeMaxProducts = AppConstants.freeTierMaxProducts; // 500
  static const int freeMaxMonthlyTransactions = 500;

  static bool isFree(String? tier) {
    if (tier == null) return true;
    final t = tier.trim().toLowerCase();
    return t.isEmpty || t == 'free';
  }

  static bool isBasic(String? tier) {
    return tier?.trim().toLowerCase() == 'basic_25';
  }

  static bool isPro(String? tier) {
    return tier?.trim().toLowerCase() == 'pro_50';
  }

  static Future<String> getOutletTier(String outletId) async {
    try {
      final client = Supabase.instance.client;
      final outletRes = await client
          .from('outlets')
          .select('subscription_tier, subscription_expiry')
          .eq('id', outletId)
          .maybeSingle();

      if (outletRes != null) {
        final tier = outletRes['subscription_tier'] as String? ?? 'free';
        final expiryStr = outletRes['subscription_expiry'] as String?;
        if (expiryStr != null) {
          final expiry = DateTime.tryParse(expiryStr);
          if (expiry != null && expiry.isBefore(DateTime.now())) {
            return 'free';
          }
        }
        return tier;
      }
    } catch (_) {}
    return 'free';
  }

  static Future<int> getMonthlyTransactionCount(String outletId) async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
      final client = Supabase.instance.client;
      final res = await client
          .from('transactions')
          .select('id')
          .eq('outlet_id', outletId)
          .gte('created_at', startOfMonth);

      return (res as List).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> canCreateProduct({
    required String outletId,
    required int currentProductCount,
    String? currentTier,
  }) async {
    final tier = currentTier ?? await getOutletTier(outletId);
    if (!isFree(tier)) return true;
    return currentProductCount < freeMaxProducts;
  }

  static Future<bool> canCreateTransaction({
    required String outletId,
    String? currentTier,
  }) async {
    final tier = currentTier ?? await getOutletTier(outletId);
    if (!isFree(tier)) return true;
    final count = await getMonthlyTransactionCount(outletId);
    return count < freeMaxMonthlyTransactions;
  }

  static void showUpgradeDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.stars_rounded, color: AppTheme.warningColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nanti Saja', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/owner/settings');
            },
            child: const Text('Upgrade Sekarang'),
          ),
        ],
      ),
    );
  }
}
