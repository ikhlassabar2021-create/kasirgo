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
      foregroundDecoration: highlight
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  Colors.white.withValues(alpha: 0.30),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            )
          : null,
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

/// Tombol Bubble Glass 3D dengan API yang kompatibel dengan [ElevatedButton]
/// dan [FilledButton], sehingga bisa dipakai sebagai pengganti langsung.
///
/// Warna latar/teks/radius/tinggi dibaca dari [style] (mis. hasil
/// `ElevatedButton.styleFrom(backgroundColor: ...)`), lalu dirender sebagai
/// permukaan kaca menggelembung dengan kilau + bayangan berlapis.
class BubbleButton extends StatefulWidget {
  const BubbleButton({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.statesController,
    this.child,
  }) : icon = null,
       label = null;

  const BubbleButton.icon({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.statesController,
    required this.icon,
    required this.label,
  }) : child = null;

  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;
  final WidgetStatesController? statesController;
  final Widget? child;
  final Widget? icon;
  final Widget? label;

  @override
  State<BubbleButton> createState() => _BubbleButtonState();
}

class _BubbleButtonState extends State<BubbleButton> {
  bool _pressed = false;
  bool _hovered = false;

  Set<WidgetState> get _states => <WidgetState>{
    if (widget.onPressed == null) WidgetState.disabled,
    if (_pressed) WidgetState.pressed,
    if (_hovered) WidgetState.hovered,
  };

  OutlinedBorder? get _shape => widget.style?.shape?.resolve(_states);

  Color? get _backgroundColor =>
      widget.style?.backgroundColor?.resolve(_states);

  Color? get _foregroundColor =>
      widget.style?.foregroundColor?.resolve(_states);

  Size? get _minSize => widget.style?.minimumSize?.resolve(_states);

  EdgeInsetsGeometry? get _paddingStyle =>
      widget.style?.padding?.resolve(_states);

  double _radius() {
    final shape = _shape;
    if (shape is RoundedRectangleBorder) {
      final radius = shape.borderRadius.resolve(Directionality.of(context));
      if (radius.topLeft.x > 0) return radius.topLeft.x;
    }
    return AppTheme.radiusMedium;
  }

  double _minHeight() {
    final size = _minSize;
    if (size == null) return AppTheme.touchTargetMedium;
    if (size.height.isFinite && size.height > 0) return size.height;
    return AppTheme.touchTargetMedium;
  }

  EdgeInsetsGeometry _padding() =>
      _paddingStyle ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 12);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    var background = _backgroundColor ?? AppTheme.primaryColor;
    // Latar transparan (dulu dipakai untuk overlay gradasi manual) tidak
    // menghasilkan permukaan kaca yang terlihat -> pakai warna brand.
    if (background.a < 0.1) background = AppTheme.primaryColor;
    final resolvedForeground = _foregroundColor;
    final isLight = background.computeLuminance() > 0.72;
    final foreground = resolvedForeground ??
        (isLight ? AppTheme.textPrimary : Colors.white);

    final base = enabled ? background : Color.lerp(background, AppTheme.borderColor, 0.62)!;
    final palette = <Color>[
      base,
      isLight
          ? Color.lerp(base, AppTheme.borderColor, 0.75)!
          : Color.lerp(base, Colors.black, enabled ? 0.20 : 0.08)!,
    ];

    Widget content = widget.icon != null
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme.merge(
                data: IconThemeData(size: 20, color: foreground),
                child: widget.icon!,
              ),
              const SizedBox(width: 8),
              Flexible(child: widget.label ?? const SizedBox.shrink()),
            ],
          )
        : (widget.child ?? const SizedBox.shrink());

    content = DefaultTextStyle.merge(
      style: TextStyle(
        color: foreground,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      textAlign: TextAlign.center,
      child: IconTheme.merge(
        data: IconThemeData(color: foreground, size: 20),
        child: content,
      ),
    );

    Widget button = MouseRegion(
      cursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : (_hovered && enabled ? 1.01 : 1.0),
          duration: AppTheme.durationFast,
          curve: AppTheme.curveDefault,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: _minHeight()),
            child: BubbleGlass(
              radius: _radius(),
              colors: palette,
              padding: _padding(),
              glow: enabled,
              pressed: _pressed,
              child: content,
            ),
          ),
        ),
      ),
    );

    button = Semantics(
      button: true,
      enabled: enabled,
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        child: button,
      ),
    );

    final minWidth = _minSize?.width;
    if (minWidth != null && minWidth.isInfinite) {
      button = SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}
