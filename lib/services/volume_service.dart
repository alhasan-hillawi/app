import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة إدارة مستوى الصوت وكتم الصوت على مستوى التطبيق بالكامل
class VolumeService {
  static final VolumeService _instance = VolumeService._internal();
  factory VolumeService() => _instance;
  VolumeService._internal();

  static const String _volumeKey = 'app_volume_level';
  static const String _mutedKey = 'app_is_muted';

  final ValueNotifier<double> volumeNotifier = ValueNotifier<double>(1.0);
  final ValueNotifier<bool> isMutedNotifier = ValueNotifier<bool>(false);

  double get volume => volumeNotifier.value;
  bool get isMuted => isMutedNotifier.value;

  /// مستوى الصوت الفعلي الذي يتم تمريره لمشغلات الفيديو (0.0 عند الكتم أو القيمة الحالية)
  double get effectiveVolume => isMuted ? 0.0 : volume;

  /// تهيئة الخدمة واستعادة القيم المحفوظة من التخزين المحلي
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVolume = prefs.getDouble(_volumeKey) ?? 1.0;
      final savedMuted = prefs.getBool(_mutedKey) ?? false;

      volumeNotifier.value = savedVolume.clamp(0.0, 1.0);
      isMutedNotifier.value = savedMuted;
    } catch (_) {}
  }

  /// ضبط مستوى الصوت وحفظه (من 0.0 إلى 1.0)
  Future<void> setVolume(double newVolume) async {
    final clamped = newVolume.clamp(0.0, 1.0);
    volumeNotifier.value = clamped;

    if (clamped == 0.0) {
      isMutedNotifier.value = true;
    } else if (isMuted) {
      isMutedNotifier.value = false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_volumeKey, clamped);
      await prefs.setBool(_mutedKey, isMutedNotifier.value);
    } catch (_) {}
  }

  /// تفعيل أو إلغاء كتم الصوت
  Future<void> setMuted(bool muted) async {
    isMutedNotifier.value = muted;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mutedKey, muted);
    } catch (_) {}
  }

  /// تبديل كتم الصوت (Mute / Unmute Toggle)
  Future<void> toggleMute() async {
    await setMuted(!isMutedNotifier.value);
  }
}

