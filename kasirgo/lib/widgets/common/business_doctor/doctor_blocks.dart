import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_theme.dart';
import '../app_button.dart';

class DoctorBlocks extends StatelessWidget {
  final List blocks;
  final void Function(String value)? onChoice;
  final void Function(String actionKey, String label)? onAction;

  const DoctorBlocks({
    super.key,
    required this.blocks,
    this.onChoice,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final raw in blocks) {
      if (raw is! Map) continue;
      final block = raw.cast<String, dynamic>();
      final widget = _buildBlock(context, block);
      if (widget == null) continue;
      if (children.isNotEmpty) children.add(const SizedBox(height: 10));
      children.add(widget);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget? _buildBlock(BuildContext context, Map<String, dynamic> b) {
    switch (b['type']) {
      case 'text':
        return Text(
          _s(b['text']),
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.45,
            color: AppTheme.textPrimary,
          ),
        );
      case 'card':
        return _card(b);
      case 'gauge':
        return _gauge(b);
      case 'checklist':
        return _checklist(b);
      case 'choices':
        return _choices(b);
      case 'action':
        return _action(b);
      default:
        return null;
    }
  }

  Widget _card(Map<String, dynamic> b) {
    final color = _tone(b['tone']?.toString());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_s(b['title']).isNotEmpty)
            Text(
              _s(b['title']),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          if (_s(b['body']).isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: _s(b['title']).isEmpty ? 0 : 4),
              child: Text(
                _s(b['body']),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _gauge(Map<String, dynamic> b) {
    final value = ((b['value'] as num?)?.toDouble() ?? 0).clamp(0.0, 100.0);
    final color = value >= 70
        ? AppTheme.successColor
        : (value >= 40 ? AppTheme.warningColor : AppTheme.errorColor);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMutedColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _s(b['label']).isEmpty
                      ? 'Skor Kesehatan Usaha'
                      : _s(b['label']),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                value.round().toString(),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 8,
              backgroundColor: AppTheme.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (_s(b['hint']).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _s(b['hint']),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _checklist(Map<String, dynamic> b) {
    final items = (b['items'] as List?) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_s(b['title']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _s(b['title']),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        for (final raw in items)
          if (raw is Map)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    raw['done'] == true
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: raw['done'] == true
                        ? AppTheme.successColor
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _s(raw['text']),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.35,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _choices(Map<String, dynamic> b) {
    final options = (b['options'] as List?) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_s(b['prompt']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _s(b['prompt']),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final raw in options)
              if (raw is Map)
                OutlinedButton(
                  onPressed: onChoice == null
                      ? null
                      : () => onChoice!(_s(raw['value']).isEmpty
                          ? _s(raw['label'])
                          : _s(raw['value'])),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                  child: Text(
                    _s(raw['label']),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
          ],
        ),
      ],
    );
  }

  Widget _action(Map<String, dynamic> b) {
    final label = _s(b['label']);
    return AppButton(
      label: label.isEmpty ? 'Lanjutkan' : label,
      icon: Icons.arrow_forward_rounded,
      height: AppTheme.touchTargetMedium,
      onPressed: onAction == null
          ? null
          : () => onAction!(_s(b['action_key']), label),
    );
  }

  Color _tone(String? tone) {
    switch (tone) {
      case 'success':
        return AppTheme.successColor;
      case 'warning':
        return AppTheme.warningColor;
      case 'danger':
        return AppTheme.errorColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _s(dynamic v) => v?.toString().trim() ?? '';
}
