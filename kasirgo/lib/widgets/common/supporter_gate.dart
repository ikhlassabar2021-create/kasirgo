import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/supporter_service.dart';

/// Dialog/bottom-sheet singkat untuk fitur yang terkunci Program Pendukung.
Future<void> showSupporterLockedDialog(
  BuildContext context,
  String featureKey,
) async {
  final label = SupporterService.featureLabels[featureKey] ?? 'Fitur ini';
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock_rounded,
                    color: AppTheme.warningColor, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Fitur Program Pendukung',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$label tersedia untuk Pendukung KasirGo (Rp50.000/bulan). '
            'Fitur inti tetap gratis selamanya; pendukung membantu biaya server '
            'dan pengembangan.',
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/owner/settings');
              },
              icon: const Icon(Icons.favorite_rounded, size: 18),
              label: const Text('Lihat Program Pendukung',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Nanti saja',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Cek fitur secara imperatif (untuk tombol aksi). Menampilkan dialog bila terkunci.
Future<bool> requireSupporterFeature(
  BuildContext context,
  WidgetRef ref,
  String featureKey,
) async {
  final outletId = ref.read(currentUserProvider)?.outletId;
  if (outletId == null || outletId.isEmpty) return true;
  final ok = await SupporterService().hasFeature(outletId, featureKey);
  if (!ok && context.mounted) {
    await showSupporterLockedDialog(context, featureKey);
  }
  return ok;
}

/// Widget pembungkus layar: tampilkan [child] bila fitur terbuka, jika tidak
/// tampilkan layar terkunci yang rapi (data lama tidak dihapus, hanya dikunci).
class SupporterFeatureGate extends ConsumerStatefulWidget {
  const SupporterFeatureGate({
    super.key,
    required this.featureKey,
    required this.child,
    this.title,
  });

  final String featureKey;
  final Widget child;
  final String? title;

  @override
  ConsumerState<SupporterFeatureGate> createState() =>
      _SupporterFeatureGateState();
}

class _SupporterFeatureGateState extends ConsumerState<SupporterFeatureGate> {
  bool _loading = true;
  bool _allowed = true;
  Entitlements? _ent;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final svc = SupporterService();
    final allowed = await svc.hasFeature(outletId, widget.featureKey);
    final ent = await svc.getEntitlements(outletId);
    if (mounted) {
      setState(() {
        _allowed = allowed;
        _ent = ent;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }
    if (_allowed) return widget.child;
    return _LockedScaffold(
      title: widget.title ??
          SupporterService.featureLabels[widget.featureKey] ??
          'Fitur Pendukung',
      trialDaysLeft: _ent?.trialDaysLeft ?? 0,
      onUpgrade: () => context.push('/owner/settings'),
    );
  }
}

class _LockedScaffold extends StatelessWidget {
  const _LockedScaffold({
    required this.title,
    required this.onUpgrade,
    this.trialDaysLeft = 0,
  });

  final String title;
  final VoidCallback onUpgrade;
  final int trialDaysLeft;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: AppTheme.warningColor, size: 38),
                ),
                const SizedBox(height: 18),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 10),
                const Text(
                  'Fitur ini bagian dari Program Pendukung KasirGo '
                  '(Rp50.000/bulan). Fitur inti tetap gratis selamanya.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
                ),
                if (trialDaysLeft > 0) ...[
                  const SizedBox(height: 8),
                  Text('Masa trial Anda tersisa $trialDaysLeft hari.',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.successColor)),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onUpgrade,
                    icon: const Icon(Icons.favorite_rounded, size: 18),
                    label: const Text('Dukung KasirGo',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Kembali',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
