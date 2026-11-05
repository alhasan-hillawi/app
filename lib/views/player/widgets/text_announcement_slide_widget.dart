import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/text_announcement_model.dart';

/// ويدجت شريحة الإعلان النصي والتنبيه لشاشات العرض الرقمية (Digital Signage OS)
/// يعتمد تصميم البطاقة الزجاجية الحديثة (Glassmorphism) مع تدرج لوني عميق ثلاثي الأبعاد
/// وشريط تقدم زمني مباشر (Live Duration Progress Bar)
class TextAnnouncementSlideWidget extends StatefulWidget {
  final TextAnnouncementSlide slide;
  final VoidCallback? onCompleted;

  const TextAnnouncementSlideWidget({
    super.key,
    required this.slide,
    this.onCompleted,
  });

  @override
  State<TextAnnouncementSlideWidget> createState() => _TextAnnouncementSlideWidgetState();
}

class _TextAnnouncementSlideWidgetState extends State<TextAnnouncementSlideWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // مؤقت مدة بقاء الشريحة مع شريط التقدم اللحظي
    final durationSeconds = widget.slide.duration > 0 ? widget.slide.duration : 15;
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: durationSeconds),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _progressController,
      curve: const Interval(0.0, 0.15, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressController,
        curve: const Interval(0.0, 0.20, curve: Curves.easeOutCubic),
      ),
    );

    _progressController.forward().whenComplete(() {
      if (mounted && widget.onCompleted != null) {
        widget.onCompleted!();
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slide;
    final bg = slide.backgroundColor;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        // تدرج لوني عميق ثلاثي الأبعاد يعطي فخامة ووضوحاً فائقاً للشاشة
        gradient: RadialGradient(
          center: const Alignment(0.0, -0.2),
          radius: 1.2,
          colors: [
            Color.lerp(bg, Colors.white, 0.08) ?? bg,
            bg,
            Color.lerp(bg, Colors.black, 0.45) ?? bg,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. أشكال ضوئية هادئة في الخلفية تعطي عمقاً بصرياً (Radial Glows)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: slide.badgeColor.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),

          // 2. المحتوى المركزي داخل بطاقة زجاجية مريحة للعين (Glassmorphism Central Card)
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxHeight < 400 || constraints.maxWidth < 600;
                    final titleSize = isCompact ? 24.0 : 40.0;
                    final bodySize = isCompact ? 14.0 : 22.0;
                    final cardPaddingH = isCompact ? 24.0 : 56.0;
                    final cardPaddingV = isCompact ? 24.0 : 44.0;

                    return Container(
                      constraints: const BoxConstraints(maxWidth: 1050),
                      margin: EdgeInsets.symmetric(
                        horizontal: isCompact ? 16 : 48,
                        vertical: isCompact ? 16 : 36,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: cardPaddingH,
                        vertical: cardPaddingV,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(isCompact ? 24 : 36),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // أ. شارة الإعلان العلوية (Badge)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: slide.badgeColor.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: slide.badgeColor.withValues(alpha: 0.55),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_resolveIcon(slide.iconType), color: slide.textColor, size: isCompact ? 16 : 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    slide.badgeText,
                                    style: GoogleFonts.cairo(
                                      fontSize: isCompact ? 12 : 14,
                                      fontWeight: FontWeight.bold,
                                      color: slide.textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isCompact ? 16 : 26),

                            // ب. العنوان الرئيسي الضخم بخط Cairo Black (w900)
                            Text(
                              slide.title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: titleSize,
                                fontWeight: FontWeight.w900,
                                color: slide.textColor,
                                height: 1.3,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isCompact ? 14 : 22),

                            // خط فاصل زخرفي ناعم بتدرج لوني
                            Container(
                              width: 120,
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    slide.badgeColor,
                                    Colors.transparent,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            SizedBox(height: isCompact ? 14 : 22),

                            // ج. جسم الإعلان أو النص التفصيلي
                            if (slide.body.isNotEmpty)
                              Text(
                                slide.body,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  fontSize: bodySize,
                                  fontWeight: FontWeight.w600,
                                  color: slide.textColor.withValues(alpha: 0.92),
                                  height: 1.65,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // 3. شريط مؤشر الوقت المتبقي للشريحة في الأسفل (Live Progress Bar)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: _progressController.value,
                  minHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(slide.badgeColor),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _resolveIcon(String icon) {
    switch (icon.toLowerCase().trim()) {
      case 'info':
      case 'information':
        return Icons.info_outline_rounded;
      case 'warning':
      case 'alert':
        return Icons.warning_amber_rounded;
      case 'event':
      case 'calendar':
        return Icons.event_available_rounded;
      case 'celebration':
      case 'party':
        return Icons.celebration_rounded;
      case 'notification':
      case 'bell':
        return Icons.notifications_active_rounded;
      case 'star':
      case 'vip':
        return Icons.star_rounded;
      case 'ramadan':
      case 'crescent':
        return Icons.nightlight_round;
      case 'campaign':
      case 'announcement':
      default:
        return Icons.campaign_rounded;
    }
  }
}
