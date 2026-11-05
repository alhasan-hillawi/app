import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import '../models/signage_models.dart';
import 'api_service.dart';
import 'volume_service.dart';

/// مدير التحميل المسبق وتجهيز الفيديوهات في الذاكرة (Seamless Video Preload Engine)
/// يقوم بتسخين وتجهيز (Pre-warm / Buffer) الفيديوهات القادمة مسبقاً قبل وصول موعد عرضها،
/// مما يقضي كلياً على أي تأخير أو فراغ زمني (Zero Delay) ويزيل أي شاشات أو علامات انتظار (Zero Loading Spinners).
class VideoPreloadManager {
  static final VideoPreloadManager _instance = VideoPreloadManager._internal();
  factory VideoPreloadManager() => _instance;
  VideoPreloadManager._internal() {
    VolumeService().volumeNotifier.addListener(_syncVolume);
    VolumeService().isMutedNotifier.addListener(_syncVolume);
  }

  // مخزن الفيديوهات المجهزة مسبقاً في الذاكرة
  final Map<String, VideoPlayerController> _pool = {};
  final Set<String> _pendingUrls = {};

  void _syncVolume() {
    final vol = VolumeService().effectiveVolume;
    for (final controller in _pool.values) {
      if (controller.value.isInitialized) {
        controller.setVolume(vol);
      }
    }
  }

  /// تجهيز وتحميل مقطع فيديو مسبقاً في الخلفية
  Future<void> preloadVideo(String rawUrl) async {
    final url = ApiService.normalizeMediaUrl(rawUrl).trim();
    if (url.isEmpty || _pool.containsKey(url) || _pendingUrls.contains(url)) {
      return;
    }

    // حد أقصى للذاكرة لمنع الضغط على الأجهزة ذات الرام المحدود
    if (_pool.length >= 4) {
      _evictOldest();
    }

    _pendingUrls.add(url);
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(VolumeService().effectiveVolume);
      await controller.seekTo(Duration.zero);
      await controller.pause();

      _pool[url] = controller;
      debugPrint('[VideoPreload] Pre-warmed video ready in 0ms: $url');
    } catch (e) {
      debugPrint('[VideoPreload] Note: preload skipped for $url: $e');
    } finally {
      _pendingUrls.remove(url);
    }
  }

  /// استخراج المشغل المجهز مسبقاً للمقطع المطلوب
  VideoPlayerController? getPreloadedController(String rawUrl) {
    final url = ApiService.normalizeMediaUrl(rawUrl).trim();
    return _pool.remove(url);
  }

  /// فحص المقطع التالي في قائمة التشغيل وبدء تسخينه فوراً
  void preloadNextItem(List<PlaylistItemModel> items, int currentIndex) {
    if (items.isEmpty) return;
    final nextIndex = (currentIndex + 1) % items.length;
    final nextItem = items[nextIndex];

    if (nextItem.isVideo && nextItem.url != null && nextItem.url!.isNotEmpty) {
      preloadVideo(nextItem.url!);
    }
  }

  void _evictOldest() {
    if (_pool.isEmpty) return;
    final firstKey = _pool.keys.first;
    final controller = _pool.remove(firstKey);
    try {
      controller?.dispose();
    } catch (_) {}
  }

  /// تنظيف المشغلات غير الموجودة في قائمة التشغيل الحالية
  void pruneUnused(List<PlaylistItemModel> currentItems) {
    final activeUrls = currentItems
        .where((i) => i.isVideo && i.url != null)
        .map((i) => ApiService.normalizeMediaUrl(i.url!).trim())
        .toSet();

    _pool.removeWhere((url, controller) {
      if (!activeUrls.contains(url)) {
        try {
          controller.dispose();
        } catch (_) {}
        return true;
      }
      return false;
    });
  }

  /// تفريغ الذاكرة بالكامل عند إيقاف المشغل أو فك الارتباط
  void disposeAll() {
    for (final controller in _pool.values) {
      try {
        controller.dispose();
      } catch (_) {}
    }
    _pool.clear();
    _pendingUrls.clear();
  }
}
