import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../services/ad_service.dart';

/// Slot iklan sponsor sisi PELANGGAN (katalog online / QR meja web).
///
/// WAJAR & non-intrusif: menyatu dalam daftar, tidak popunder, tidak menutupi
/// tombol, tidak ada iklan tersembunyi. Selalu diberi label "Iklan / Sponsor".
/// Widget ini TIDAK boleh dirender di layar owner.
class SponsorAdSlot extends StatefulWidget {
  const SponsorAdSlot({
    super.key,
    required this.outletId,
    this.consentGiven = false,
    this.onConsentChanged,
    this.compact = false,
  });

  final String outletId;
  final bool consentGiven;
  final ValueChanged<bool>? onConsentChanged;
  final bool compact;

  @override
  State<SponsorAdSlot> createState() => _SponsorAdSlotState();
}

class _SponsorAdSlotState extends State<SponsorAdSlot> {
  final _service = AdService();
  AdDecision? _decision;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SponsorAdSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.consentGiven != widget.consentGiven ||
        oldWidget.outletId != widget.outletId) {
      _load();
    }
  }

  Future<void> _load() async {
    final d = await _service.decide(
      outletId: widget.outletId,
      isOwner: false,
      consentGiven: widget.consentGiven,
    );
    if (mounted) setState(() => _decision = d);
  }

  Future<void> _acceptConsent(bool value) async {
    await _service.setConsent(value);
    if (!mounted) return;
    widget.onConsentChanged?.call(value);
    await _load();
  }

  Future<void> _open(SponsorAd ad) async {
    final url = ad.url;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _decision;
    if (d == null) return const SizedBox.shrink();
    if (d.adFree) return const SizedBox.shrink();

    // Minta consent (UU PDP) lebih dulu. `decide()` mengembalikan showAds=false
    // saat consent belum ada, jadi cek ini harus mendahului cek showAds.
    if (d.needsConsent) {
      return _consentCard();
    }

    if (!d.showAds || d.ads.isEmpty) return const SizedBox.shrink();
    if (_index >= d.ads.length) _index = 0;
    final ad = d.ads[_index];

    return Padding(
      padding: EdgeInsets.fromLTRB(
          widget.compact ? 12 : 16, 4, widget.compact ? 12 : 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: ad.url != null && ad.url!.isNotEmpty ? () => _open(ad) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: (ad.imageBytes != null)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            ad.imageBytes!,
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                                Icons.campaign_outlined,
                                color: AppTheme.accentColor,
                                size: 22),
                          ),
                        )
                      : (ad.imageSrc != null && ad.imageSrc!.startsWith('http'))
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                ad.imageSrc!,
                                width: 46,
                                height: 46,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                    Icons.campaign_outlined,
                                    color: AppTheme.accentColor,
                                    size: 22),
                              ),
                            )
                          : const Icon(Icons.campaign_outlined,
                              color: AppTheme.accentColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceMutedColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Iklan Sponsor',
                                style: GoogleFonts.inter(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textSecondary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        ad.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary),
                      ),
                      if (ad.subtitle != null && ad.subtitle!.isNotEmpty)
                        Text(
                          ad.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppTheme.textSecondary),
                        ),
                    ],
                  ),
                ),
                if (ad.ctaLabel != null && ad.ctaLabel!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(ad.ctaLabel!,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _consentCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.privacy_tip_outlined,
                size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Izinkan iklan sponsor?',
                    style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Dengan izin Anda (UU PDP), kami menampilkan iklan sponsor lokal '
                    'yang wajar untuk mendukung aplikasi tetap gratis. Anda bisa menolak.',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        height: 1.35),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _acceptConsent(false),
                        child: const Text('Tolak',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () => _acceptConsent(true),
                        child: const Text('Setuju',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
