import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_theme.dart';

class SupporterGate {
  static bool isFree(String? tier) => false;
  static bool isBasic(String? tier) => true;
  static bool isPro(String? tier) => true;

  static Future<String> getOutletTier(String outletId) async {
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('supporters')
          .select('tier')
          .eq('outlet_id', outletId)
          .eq('status', 'active')
          .maybeSingle();

      if (res != null) {
        return res['tier'] as String? ?? 'pendukung';
      }
    } catch (_) {}
    return 'free';
  }

  static Future<int> getMonthlyTransactionCount(String outletId) async => 0;

  static Future<bool> canCreateProduct({
    required String outletId,
    required int currentProductCount,
    String? currentTier,
  }) async => true;

  static Future<bool> canCreateTransaction({
    required String outletId,
    String? currentTier,
  }) async => true;

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
            const Icon(Icons.favorite_rounded, color: AppTheme.secondaryColor),
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
            child: const Text('Tutup', style: TextStyle(color: AppTheme.textSecondary)),
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
            child: const Text('Lihat Program Pendukung'),
          ),
        ],
      ),
    );
  }
}

typedef SubscriptionGate = SupporterGate;
