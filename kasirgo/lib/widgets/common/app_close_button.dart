import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Tombol tutup (X) bulat yang diletakkan di sudut kanan atas dialog/bottom
/// sheet agar rapi dan mudah dijangkau. Pakai di dalam Stack/Align.
class AppCloseButton extends StatelessWidget {
  const AppCloseButton({
    super.key,
    this.onTap,
    this.color = AppTheme.textSecondary,
    this.size = 20,
  });

  final VoidCallback? onTap;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Icon(Icons.close_rounded, size: size, color: color),
        ),
      ),
    );
  }
}

/// Bungkus konten dialog/sheet agar tombol X otomatis muncul di sudut kanan atas.
class AppDialogSurface extends StatelessWidget {
  const AppDialogSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(padding: padding, child: child),
        Positioned(
          top: 8,
          right: 8,
          child: AppCloseButton(
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }
}
