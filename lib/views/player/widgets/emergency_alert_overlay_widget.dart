import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/signage_models.dart';

class EmergencyAlertOverlayWidget extends StatefulWidget {
  final EmergencyAlert alert;

  const EmergencyAlertOverlayWidget({super.key, required this.alert});

  @override
  State<EmergencyAlertOverlayWidget> createState() => _EmergencyAlertOverlayWidgetState();
}

class _EmergencyAlertOverlayWidgetState extends State<EmergencyAlertOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);

    if (widget.alert.soundAlarm) {
      _startSiren();
    }
  }

  Future<void> _startSiren() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/siren.mp3'));
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.alert.displayMode == 'banner') {
      return _buildBannerAlert();
    }
    return _buildFullscreenAlert();
  }

  // 1. نمط الاستحواذ الكامل (Fullscreen Mode) المتجاوب مع كافة أحجام الشاشات
  Widget _buildFullscreenAlert() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final baseColor = widget.alert.severity == 'critical'
            ? const Color(0xFFDC2626)
            : (widget.alert.severity == 'warning' ? const Color(0xFFD97706) : const Color(0xFF2563EB));
        final darkColor = widget.alert.severity == 'critical'
            ? const Color(0xFF450A0A)
            : (widget.alert.severity == 'warning' ? const Color(0xFF451A03) : const Color(0xFF1E3A8A));

        final animatedBg = Color.lerp(baseColor, darkColor, _pulseController.value)!;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: animatedBg,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // تكييف الأبعاد للعمل بنعومة على الهواتف الأفقية (iPhone landscape) وحتى شاشات 4K/TV
                final isCompact = constraints.maxHeight < 550;
                final iconSize = isCompact ? 44.0 : 80.0;
                final iconPadding = isCompact ? 12.0 : 20.0;
                final titleFontSize = isCompact ? 22.0 : 40.0;
                final messageFontSize = isCompact ? 14.0 : 24.0;
                final spacing = isCompact ? 10.0 : 20.0;
                final hPadding = isCompact ? 24.0 : 48.0;
                final vPadding = isCompact ? 14.0 : 28.0;

                return Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // أيقونة الخطر بحجم متكيف مع تأثير نبض
                        Transform.scale(
                          scale: 1.0 + (_pulseController.value * 0.1),
                          child: Container(
                            padding: EdgeInsets.all(iconPadding),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getEmergencyIcon(widget.alert.alertType),
                              size: iconSize,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(height: spacing),

                        // العنوان الرئيسي للطوارئ
                        Text(
                          "🚨 ${widget.alert.title} 🚨",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: spacing),

                        // بطاقة تعليمات الإخلاء والسلامة
                        Container(
                          constraints: const BoxConstraints(maxWidth: 1000),
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 18 : 32,
                            vertical: isCompact ? 12 : 20,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(isCompact ? 16 : 24),
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          child: Text(
                            widget.alert.message,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: messageFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                        ),
                        SizedBox(height: spacing),

                        // شريط توجيهي ثابت
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 14 : 20,
                            vertical: isCompact ? 6 : 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            "نظام إدارة الطوارئ والسلامة العامة • اتبع مخارج الطوارئ فوراً",
                            style: GoogleFonts.cairo(
                              fontSize: isCompact ? 11 : 13,
                              fontWeight: FontWeight.bold,
                              color: baseColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // 2. نمط الشريط التحذيري البارز (Banner Mode)
  Widget _buildBannerAlert() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(_getEmergencyIcon(widget.alert.alertType), color: Colors.white, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.alert.title,
                      style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      widget.alert.message,
                      style: GoogleFonts.cairo(fontSize: 12, color: Colors.white.withValues(alpha: 0.95)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getEmergencyIcon(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return Icons.local_fire_department_rounded;
      case 'evacuation':
        return Icons.run_circle_rounded;
      case 'security':
        return Icons.shield_rounded;
      case 'weather':
        return Icons.thunderstorm_rounded;
      case 'medical':
        return Icons.medical_services_rounded;
      default:
        return Icons.warning_rounded;
    }
  }
}
