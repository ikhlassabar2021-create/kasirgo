import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

/// Bubble Glass 3D - permukaan kaca menggelembung dengan kilau (specular
/// highlight) dan bayangan berlapis sehingga terlihat timbul/dimensi.
///
/// Dipakai untuk logo & tombol utama owner (Design System v3).
class BubbleGlass extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final List<Color>? colors;
  final bool highlight;
  final bool glow;
  final bool pressed;

  const BubbleGlass({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.radius = AppTheme.radiusMedium,
    this.colors,
    this.highlight = true,
    this.glow = true,
    this.pressed = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = colors ??
        const [AppTheme.primaryColor, AppTheme.secondaryColor];

    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
        boxShadow: [
          if (glow)
            BoxShadow(
              color: palette.last.withValues(alpha: pressed ? 0.20 : 0.38),
              blurRadius: pressed ? 8 : 16,
              offset: Offset(0, pressed ? 3 : 7),
            ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.10),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            if (highlight)
              Positioned(
                top: -radius * 0.9,
                left: -radius * 0.6,
                child: IgnorePointer(
                  child: Container(
                    width: (width ?? 64) * 0.9,
                    height: (height ?? 64) * 0.9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.55),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (highlight)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            Center(child: child),
          ],
        ),
      ),
    );
  }
}

/// Tombol dengan efek Bubble Glass 3D (state pressed menyusut lembut).
class BubbleGlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final List<Color>? colors;
  final EdgeInsetsGeometry padding;
  final bool expanded;
  final String? tooltip;

  const BubbleGlassButton({
    super.key,
    required this.child,
    this.onTap,
    this.radius = AppTheme.radiusMedium,
    this.colors,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.expanded = false,
    this.tooltip,
  });

  @override
  State<BubbleGlassButton> createState() => _BubbleGlassButtonState();
}

class _BubbleGlassButtonState extends State<BubbleGlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Widget button = MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: AppTheme.durationFast,
          curve: AppTheme.curveDefault,
          child: BubbleGlass(
            radius: widget.radius,
            colors: widget.colors,
            padding: widget.padding,
            pressed: _pressed,
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.expanded) {
      button = SizedBox(width: double.infinity, child: button);
    }
    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}
