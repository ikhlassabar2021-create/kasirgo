import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';

/// Pemilih satu nilai dari daftar pendek (mis. tipe usaha) tanpa deretan chip
/// horizontal yang memakan lebar layar.
///
/// Tampil sebagai kolom ringkas; saat diketuk membuka bottom sheet berisi
/// daftar pilihan. Bila [allLabel] diisi, daftar mendapat opsi "Semua" yang
/// mengirim `null` ke [onChanged].
class AppDropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String? allLabel;
  final String? hint;
  final IconData prefixIcon;
  final bool enabled;

  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.allLabel,
    this.hint,
    this.prefixIcon = Icons.category_rounded,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    final display = hasValue ? value! : (allLabel ?? hint ?? 'Pilih');
    final muted = !hasValue && allLabel == null;

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      onTap: enabled ? () => _open(context) : null,
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppTheme.surfaceColor,
          prefixIcon: Icon(prefixIcon, size: 20),
          suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: const BorderSide(color: AppTheme.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: const BorderSide(color: AppTheme.borderColor),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        child: Text(
          display,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
            color: muted ? AppTheme.textSecondary : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<_CategoryPick>(
      useSafeArea: true,
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (ctx) {
        final entries = <_CategoryPick>[
          if (allLabel != null)
            _CategoryPick(label: allLabel!, value: null),
          for (final o in options) _CategoryPick(label: o, value: o),
        ];
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Tutup',
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: entries.length,
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      final active = (value ?? '') == (e.value ?? '');
                      return ListTile(
                        title: Text(
                          e.label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color: active
                                ? AppTheme.primaryColor
                                : AppTheme.textPrimary,
                          ),
                        ),
                        trailing: active
                            ? const Icon(Icons.check_circle_rounded,
                                color: AppTheme.primaryColor)
                            : null,
                        onTap: () => Navigator.of(ctx).pop(e),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked != null) onChanged(picked.value);
  }
}

class _CategoryPick {
  final String label;
  final String? value;
  const _CategoryPick({required this.label, required this.value});
}
