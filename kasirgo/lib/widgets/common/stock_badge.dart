import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';

class StockBadge extends StatelessWidget {
  final int stock;
  final bool showLabel;
  final bool compact;

  const StockBadge({
    super.key,
    required this.stock,
    this.showLabel = false,
    this.compact = true,
  });

  Color get _color {
    if (stock <= 0) return AppTheme.errorColor;
    if (stock <= 10) return AppTheme.warningColor;
    return AppTheme.successColor;
  }

  String get _text {
    if (showLabel) {
      if (stock <= 0) return 'Habis';
      return 'Stok $stock';
    }
    return stock <= 0 ? '0' : '$stock';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? 8 : (compact ? 5 : 7),
        vertical: showLabel ? 3 : (compact ? 2 : 3),
      ),
      decoration: BoxDecoration(
        color: showLabel ? color.withValues(alpha: 0.12) : color,
        borderRadius: BorderRadius.circular(showLabel ? 20 : 6),
        border: showLabel ? Border.all(color: color.withValues(alpha: 0.3)) : null,
      ),
      child: Text(
        _text,
        style: GoogleFonts.inter(
          color: showLabel ? color : Colors.white,
          fontSize: showLabel ? 11 : (compact ? 8.5 : 10),
          fontWeight: FontWeight.w800,
          letterSpacing: showLabel ? 0.2 : 0.5,
        ),
      ),
    );
  }
}
