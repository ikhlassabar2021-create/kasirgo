import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';

enum AppBadgeVariant { neutral, info, success, warning, danger, ai }

class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;
  final bool compact;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.neutral,
    this.icon,
    this.compact = false,
  });

  Color get _foreground {
    switch (variant) {
      case AppBadgeVariant.info:
        return AppTheme.primaryColor;
      case AppBadgeVariant.success:
        return AppTheme.successColor;
      case AppBadgeVariant.warning:
        return AppTheme.warningColor;
      case AppBadgeVariant.danger:
        return AppTheme.errorColor;
      case AppBadgeVariant.ai:
        return AppTheme.accentColor;
      case AppBadgeVariant.neutral:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = _foreground;
    final isAi = variant == AppBadgeVariant.ai;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: isAi ? null : fg.withValues(alpha: 0.12),
        gradient: isAi ? AppTheme.aiBadgeGradient : null,
        borderRadius: BorderRadius.circular(20),
        border: isAi ? null : Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 11 : 13, color: isAi ? Colors.white : fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              color: isAi ? Colors.white : fg,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
