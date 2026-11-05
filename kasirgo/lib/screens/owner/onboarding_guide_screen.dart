import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../services/onboarding_guide_service.dart';
import '../../services/voice_service.dart';
import '../../widgets/common/centennial_background.dart';
import '../../widgets/guide/guide_mock.dart';

/// Panduan langkah demi langkah bersuara untuk pemilik baru.
///
/// Setiap langkah digambar sebagai simulasi layar ([GuideMock]) dan dibacakan
/// robot pemandu lewat [VoiceService] (persona "partner santai"). Muncul
/// otomatis sekali setelah login pertama, atau dibuka ulang dari kartu
/// "Langkah Awal Berjualan".
class OnboardingGuideScreen extends StatefulWidget {
  final String? outletId;

  const OnboardingGuideScreen({super.key, this.outletId});

  @override
  State<OnboardingGuideScreen> createState() => _OnboardingGuideScreenState();
}

class _OnboardingGuideScreenState extends State<OnboardingGuideScreen> {
  final OnboardingGuideService _service = OnboardingGuideService();
  final VoiceService _voice = VoiceService();

  int _index = 0;
  bool _muted = false;
  bool _voiceReady = false;
  bool _finishing = false;

  OnboardingGuideStep get _step => OnboardingGuideService.steps[_index];
  bool get _isLast => _index == OnboardingGuideService.steps.length - 1;

  @override
  void initState() {
    super.initState();
    _prepareVoice();
  }

  Future<void> _prepareVoice() async {
    await _voice.init(outletId: widget.outletId);
    await _voice.setPersona('partner_santai', persist: false);
    if (!mounted) return;
    setState(() => _voiceReady = _voice.available);
    _speakCurrent();
  }

  void _speakCurrent() {
    if (_muted || !_voiceReady) return;
    _voice.speak(_step.spoken, priority: true);
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    if (_muted) {
      await _voice.stop();
    } else {
      _speakCurrent();
    }
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    setState(() => _index++);
    _speakCurrent();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    await _service.markDone();
    await _voice.stop();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _voice.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: AppTheme.borderColor)),
        title: Text(
          'Panduan Awal Berjualan',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _muted ? 'Nyalakan suara' : 'Matikan suara',
            onPressed: _toggleMute,
            icon: Icon(
              _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
      body: CentennialBackground(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildProgress(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GuideMock(scene: _step.scene, height: 232),
                      const SizedBox(height: 18),
                      Text(
                        _step.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _step.body,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          height: 1.55,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildVoiceRow(),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final total = OnboardingGuideService.steps.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Langkah ${_index + 1} dari $total',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '${(((_index + 1) / total) * 100).round()}%',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_index + 1) / total,
              minHeight: 8,
              backgroundColor: AppTheme.borderColor,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceRow() {
    final available = _voiceReady && !_muted;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(
            available
                ? Icons.hearing_rounded
                : Icons.hearing_disabled_rounded,
            color: available ? AppTheme.primaryColor : AppTheme.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _muted
                  ? 'Suara dimatikan.'
                  : _voiceReady
                      ? 'Suara pemandu aktif.'
                      : 'Suara tidak tersedia di perangkat ini.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                height: 1.35,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          if (_voiceReady)
            TextButton.icon(
              onPressed: _muted ? null : _speakCurrent,
              icon: const Icon(Icons.replay_rounded, size: 16),
              label: const Text('Dengar lagi'),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: _finish,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
            ),
            child: const Text('Lewati'),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _next,
            icon: Icon(
              _isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
              size: 18,
            ),
            label: Text(_isLast ? 'Selesai' : 'Lanjut'),
          ),
        ],
      ),
    );
  }
}