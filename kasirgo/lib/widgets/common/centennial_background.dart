import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Ambient gradient shell untuk semua layar Centennial.
/// Slate 900 base + radial glow Indigo/Purple/Cyan.
class CentennialBackground extends StatelessWidget {
  final Widget child;

  const CentennialBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.backgroundColor,
                  AppTheme.surfaceMutedColor,
                  AppTheme.backgroundColor,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -140,
          left: -100,
          child: _Glow(color: AppTheme.primaryColor.withValues(alpha: 0.10), size: 340),
        ),
        Positioned(
          top: 120,
          right: -140,
          child: _Glow(color: AppTheme.accentColor.withValues(alpha: 0.08), size: 320),
        ),
        Positioned(
          bottom: -160,
          left: 40,
          child: _Glow(color: AppTheme.secondaryColor.withValues(alpha: 0.06), size: 360),
        ),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;

  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Skeleton placeholder bergaya Centennial (anti spinner).
class CentennialSkeleton extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const CentennialSkeleton({
    super.key,
    this.height = 16,
    this.width,
    this.borderRadius,
  });

  @override
  State<CentennialSkeleton> createState() => _CentennialSkeletonState();
}

class _CentennialSkeletonState extends State<CentennialSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 0.75).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Angka nominal uang glanceable: bobot ekstra-tebal, kontras tinggi.
class MoneyText extends StatelessWidget {
  final String value;
  final double size;
  final Color color;

  const MoneyText({
    super.key,
    required this.value,
    this.size = 26,
    this.color = AppTheme.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
