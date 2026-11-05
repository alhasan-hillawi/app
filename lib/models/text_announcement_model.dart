import 'package:flutter/material.dart';

/// نموذج بيانات شريحة الإعلان النصي والتنبيه لشاشات العرض الرقمية (Digital Signage OS)
/// يتيح عرض إعلانات فورية وتعميمات إدارية ورسائل ترحيبية بدقة Vector وبدون وسائط
class TextAnnouncementSlide {
  final int id;
  final String title;
  final String body;
  final int duration;
  final Color backgroundColor;
  final Color textColor;
  final String badgeText;
  final Color badgeColor;
  final String iconType;

  TextAnnouncementSlide({
    required this.id,
    required this.title,
    required this.body,
    required this.duration,
    required this.backgroundColor,
    required this.textColor,
    this.badgeText = "إعلان وتنبيه",
    this.badgeColor = const Color(0xFF4F46E5),
    this.iconType = "campaign",
  });

  factory TextAnnouncementSlide.fromJson(Map<String, dynamic> json) {
    final custom = (json['custom_content'] as Map<String, dynamic>?) ?? {};

    final customTitle = custom['title']?.toString().trim();
    final rootTitle = json['title']?.toString().trim();
    final resolvedTitle = (customTitle != null && customTitle.isNotEmpty)
        ? customTitle
        : ((rootTitle != null && rootTitle.isNotEmpty) ? rootTitle : 'إعلان رسمي');

    final bodyText = (custom['body'] ?? custom['content'] ?? custom['message'] ?? custom['text'] ?? '').toString();

    final dur = json['duration'] ?? custom['duration'];
    final int parsedDuration = dur is int
        ? dur
        : (int.tryParse(dur?.toString() ?? '') ?? 15);

    final rawId = json['id'];
    final int parsedId = rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '') ?? 0);

    return TextAnnouncementSlide(
      id: parsedId,
      title: resolvedTitle,
      body: bodyText,
      duration: parsedDuration > 0 ? parsedDuration : 15,
      backgroundColor: _parseColor(
        custom['background_color'] ?? custom['bgColor'],
        const Color(0xFF0F172A),
      ),
      textColor: _parseColor(
        custom['text_color'] ?? custom['color'],
        Colors.white,
      ),
      badgeText: (custom['badge_text'] ?? custom['badge'] ?? "إعلان وتنبيه").toString(),
      badgeColor: _parseColor(
        custom['badge_color'],
        const Color(0xFF4F46E5),
      ),
      iconType: (custom['icon'] ?? custom['icon_type'] ?? "campaign").toString(),
    );
  }

  static Color _parseColor(dynamic hexString, Color defaultColor) {
    if (hexString == null) return defaultColor;
    final str = hexString.toString().trim();
    if (str.isEmpty) return defaultColor;

    try {
      final buffer = StringBuffer();
      final cleanHex = str.replaceFirst('#', '').replaceAll('0x', '');
      if (cleanHex.length == 6) {
        buffer.write('ff');
      }
      buffer.write(cleanHex);
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return defaultColor;
    }
  }
}

