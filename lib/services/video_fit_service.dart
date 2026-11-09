import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VideoFitMode {
  contain, // عرض كامل الفيديو مع احتواء الأبعاد (بدون أي اقتصاص)
  fill,    // توسيع وتمديد الفيديو لملء كامل أبعاد الشاشة بدون حواف
  cover,   // تغطية كاملة للشاشة مع الحفاظ على النسبة واقتصاص الزوائد
}

/// خدمة إدارة نمط توسيع وتقليص الفيديو على حجم الشاشة
class VideoFitService {
  static final VideoFitService _instance = VideoFitService._internal();
  factory VideoFitService() => _instance;
  VideoFitService._internal();

  static const String _prefKey = 'signage_video_fit_mode';

  // القيمة الافتراضية: contain (عرض كامل الفيديو 100% بدون أي قص)
  final ValueNotifier<VideoFitMode> fitModeNotifier = ValueNotifier<VideoFitMode>(VideoFitMode.contain);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString(_prefKey);
      if (savedStr != null) {
        if (savedStr == 'fill') {
          fitModeNotifier.value = VideoFitMode.fill;
        } else if (savedStr == 'cover') {
          fitModeNotifier.value = VideoFitMode.cover;
        } else {
          fitModeNotifier.value = VideoFitMode.contain;
        }
      }
    } catch (_) {}
  }

  /// التبديل التتابعي بين الأنماط (توسيع / تقليص)
  Future<VideoFitMode> cycleNextMode() async {
    VideoFitMode next;
    switch (fitModeNotifier.value) {
      case VideoFitMode.contain:
        next = VideoFitMode.fill;
        break;
      case VideoFitMode.fill:
        next = VideoFitMode.cover;
        break;
      case VideoFitMode.cover:
        next = VideoFitMode.contain;
        break;
    }
    await setFitMode(next);
    return next;
  }

  /// تعيين نمط محدد
  Future<void> setFitMode(VideoFitMode mode) async {
    fitModeNotifier.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode.name);
    } catch (_) {}
  }

  /// تحويل النمط إلى BoxFit الخاص بـ Flutter
  BoxFit get currentBoxFit {
    switch (fitModeNotifier.value) {
      case VideoFitMode.contain:
        return BoxFit.contain;
      case VideoFitMode.fill:
        return BoxFit.fill;
      case VideoFitMode.cover:
        return BoxFit.cover;
    }
  }

  /// الاسم العربي التوضيحي للنمط
  String get currentModeTitleAr {
    switch (fitModeNotifier.value) {
      case VideoFitMode.contain:
        return "عرض كامل الفيديو (احتواء / بدون قص)";
      case VideoFitMode.fill:
        return "توسيع ملء الشاشة بالكامل (تمديد 100%)";
      case VideoFitMode.cover:
        return "تغطية كاملة للشاشة (توسيع مع اقتصاص الزوائد)";
    }
  }

  IconData get currentModeIcon {
    switch (fitModeNotifier.value) {
      case VideoFitMode.contain:
        return Icons.fit_screen_rounded;
      case VideoFitMode.fill:
        return Icons.aspect_ratio_rounded;
      case VideoFitMode.cover:
        return Icons.fullscreen_rounded;
    }
  }
}
