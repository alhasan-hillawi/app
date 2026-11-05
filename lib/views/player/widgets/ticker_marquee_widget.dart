import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:google_fonts/google_fonts.dart';

class TickerConfigModel {
  final bool enabled;
  final String position; // 'bottom' or 'top'
  final String text;
  final Color textColor;
  final Color backgroundColor;
  final int speedSeconds;
  final String direction; // 'rtl' or 'ltr'
  final double fontSize;

  TickerConfigModel({
    required this.enabled,
    required this.position,
    required this.text,
    required this.textColor,
    required this.backgroundColor,
    required this.speedSeconds,
    required this.direction,
    required this.fontSize,
  });

  factory TickerConfigModel.fromJson(Map<String, dynamic> json) {
    return TickerConfigModel(
      enabled: json['enabled'] ?? false,
      position: json['position'] ?? 'bottom',
      text: json['text'] ?? '',
      textColor: parseColor(json['text_color'], Colors.white),
      backgroundColor: parseColor(json['background_color'], const Color(0xFFB91C1C)),
      speedSeconds: json['speed_seconds'] ?? 20,
      direction: json['direction'] ?? 'rtl',
      fontSize: (json['font_size'] as num?)?.toDouble() ?? 22.0,
    );
  }

  static Color parseColor(String? hexString, Color defaultColor) {
    if (hexString == null || hexString.isEmpty) return defaultColor;
    try {
      final clean = hexString.replaceAll('#', '').trim();
      final buffer = StringBuffer();
      if (clean.length == 6) buffer.write('ff');
      buffer.write(clean);
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return defaultColor;
    }
  }
}

class TickerMarqueeWidget extends StatelessWidget {
  final TickerConfigModel config;

  const TickerMarqueeWidget({super.key, required this.config});

  // منشئ بديل للمرونة مع الخصائص الفردية
  factory TickerMarqueeWidget.fromProperties({
    Key? key,
    required String text,
    String backgroundColorHex = '#b91c1c',
    String textColorHex = '#ffffff',
    int speedSeconds = 20,
    String position = 'bottom',
    String direction = 'rtl',
    double fontSize = 22.0,
  }) {
    return TickerMarqueeWidget(
      key: key,
      config: TickerConfigModel(
        enabled: text.trim().isNotEmpty,
        position: position,
        text: text,
        textColor: TickerConfigModel.parseColor(textColorHex, Colors.white),
        backgroundColor: TickerConfigModel.parseColor(backgroundColorHex, const Color(0xFFB91C1C)),
        speedSeconds: speedSeconds,
        direction: direction,
        fontSize: fontSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!config.enabled || config.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final velocity = (screenWidth / (config.speedSeconds > 0 ? config.speedSeconds : 20)).clamp(30.0, 150.0);
    final isRtl = config.direction.toLowerCase() == 'rtl';

    return Container(
      width: double.infinity,
      height: config.fontSize + 24,
      decoration: BoxDecoration(
        color: config.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: Offset(0, config.position == 'bottom' ? -2 : 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // شارة "عاجل" الثابتة في البداية
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: double.infinity,
            color: Colors.black.withValues(alpha: 0.25),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.campaign, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Text(
                  "عاجل",
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // شريط النصوص المتحرك
          Expanded(
            child: Directionality(
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: Marquee(
                text: config.text,
                style: GoogleFonts.cairo(
                  color: config.textColor,
                  fontSize: config.fontSize,
                  fontWeight: FontWeight.bold,
                ),
                scrollAxis: Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.center,
                blankSpace: 80.0,
                velocity: velocity,
                pauseAfterRound: Duration.zero,
                startPadding: 20.0,
                accelerationDuration: const Duration(milliseconds: 500),
                accelerationCurve: Curves.linear,
                decelerationDuration: const Duration(milliseconds: 500),
                decelerationCurve: Curves.easeOut,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
