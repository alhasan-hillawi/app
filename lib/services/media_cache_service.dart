import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/signage_models.dart';
import '../models/split_screen_model.dart';
import 'api_service.dart';

/// خدمة إدارة وتخزين وسائط الفيديو محلياً على القرص (Offline-First Video Cache Service)
/// تضمن تشغيل الفيديوهات بسلاسة تامة ومعدل 60 إطاراً في الثانية من الذاكرة المحلية
/// بدون أي تقطيع أو تجميد ناتج عن بطء أو تذبذب شبكة الإنترنت.
class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  factory MediaCacheService() => _instance;
  MediaCacheService._internal();

  Directory? _cacheDir;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 120),
    ),
  );

  // تتبع التحميلات الجارية لمنع تكرار تحميل نفس الملف بالتوازي
  final Map<String, Future<File?>> _activeDownloads = {};

  /// تهيئة مجلد التخزين المؤقت للوسائط
  Future<void> init() async {
    if (_cacheDir != null && await _cacheDir!.exists()) return;
    try {
      final baseDir = await getApplicationSupportDirectory();
      final dir = Directory('${baseDir.path}/signage_media_cache');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cacheDir = dir;
      debugPrint('[MediaCache] Initialized storage at: ${_cacheDir!.path}');
    } catch (e) {
      debugPrint('[MediaCache] Failed to initialize directory: $e');
    }
  }

  /// توليد اسم ملف فريد ومستقر بناءً على رابط الفيديو
  String _generateFileName(String url) {
    final cleanUrl = ApiService.normalizeMediaUrl(url).trim();
    final hash = md5.convert(utf8.encode(cleanUrl)).toString();
    
    // استخراج الامتداد المناسب (.mp4 الافتراضي)
    String ext = '.mp4';
    try {
      final uri = Uri.parse(cleanUrl);
      final lastSegment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      final dotIndex = lastSegment.lastIndexOf('.');
      if (dotIndex != -1 && dotIndex < lastSegment.length - 1) {
        final extractedExt = lastSegment.substring(dotIndex).toLowerCase();
        if (extractedExt.length <= 5 && RegExp(r'^\.[a-z0-9]+$').hasMatch(extractedExt)) {
          ext = extractedExt;
        }
      }
    } catch (_) {}

    return 'media_$hash$ext';
  }

  /// جلب مسار الملف المحلي المخزن في الكاش
  Future<File?> getCachedFile(String rawUrl) async {
    await init();
    if (_cacheDir == null) return null;

    final fileName = _generateFileName(rawUrl);
    final file = File('${_cacheDir!.path}/$fileName');

    if (await file.exists()) {
      final len = await file.length();
      // التأكد من أن الملف غير فارغ ومكتمل
      if (len > 4096) {
        return file;
      } else {
        // حذف الملفات التالفة أو غير المكتملة
        try {
          await file.delete();
        } catch (_) {}
      }
    }
    return null;
  }

  /// التحقق السريع من وجود الفيديو في الكاش
  Future<bool> isCached(String rawUrl) async {
    final file = await getCachedFile(rawUrl);
    return file != null;
  }

  /// تحميل الفيديو وتخزينه في الكاش للاستخدام الدائم
  Future<File?> downloadAndCache(String rawUrl, {bool highPriority = false}) async {
    final cleanUrl = ApiService.normalizeMediaUrl(rawUrl).trim();
    if (cleanUrl.isEmpty) return null;

    // 1. إذا كان الملف موجوداً مسبقاً وسليماً، إرجاعه فوراً دون أي استهلاك للشبكة
    final existingFile = await getCachedFile(cleanUrl);
    if (existingFile != null) {
      return existingFile;
    }

    // 2. إذا كان الملف قيد التحميل حالياً، انتظار نفس الـ Future المشترك
    if (_activeDownloads.containsKey(cleanUrl)) {
      return await _activeDownloads[cleanUrl];
    }

    // 3. بدء عملية التحميل وتخزينه بصيغة مؤقتة (.part) ثم نقله لمنع القراءة غير المكتملة
    final completer = Completer<File?>();
    _activeDownloads[cleanUrl] = completer.future;

    try {
      await init();
      if (_cacheDir == null) {
        completer.complete(null);
        return null;
      }

      final fileName = _generateFileName(cleanUrl);
      final finalPath = '${_cacheDir!.path}/$fileName';
      final tempPath = '${_cacheDir!.path}/$fileName.part';

      debugPrint('[MediaCache] Downloading video to cache: $cleanUrl');

      await _dio.download(
        cleanUrl,
        tempPath,
        deleteOnError: true,
      );

      final tempFile = File(tempPath);
      if (await tempFile.exists() && await tempFile.length() > 4096) {
        final finalFile = await tempFile.rename(finalPath);
        debugPrint('[MediaCache] Video successfully cached: $fileName (${await finalFile.length()} bytes)');
        completer.complete(finalFile);
      } else {
        completer.complete(null);
      }
    } catch (e) {
      debugPrint('[MediaCache] Error downloading video ($cleanUrl): $e');
      completer.complete(null);
    } finally {
      _activeDownloads.remove(cleanUrl);
    }

    return await completer.future;
  }

  /// الفحص المسبق والتحميل التلقائي لكافة فيديوهات قائمة التشغيل في الخلفية
  Future<void> cachePlaylistVideos(List<PlaylistItemModel> items) async {
    await init();
    final List<String> videoUrls = [];

    for (final item in items) {
      if (item.isVideo && item.url != null && item.url!.isNotEmpty) {
        videoUrls.add(item.url!);
      } else if (item.isSplitScreen && item.customContent != null) {
        try {
          final split = SplitScreenSlide.fromJson(item.customContent!);
          for (final zone in split.zones) {
            if (zone.isVideo && zone.url.isNotEmpty) {
              videoUrls.add(zone.url);
            }
          }
        } catch (_) {}
      }
    }

    // تحميل الفيديوهات غير المخزنة في الخلفية بهدوء
    for (final url in videoUrls) {
      final isReady = await isCached(url);
      if (!isReady) {
        downloadAndCache(url);
      }
    }
  }

  /// حساب الحجم الكلي للملفات المخزنة في الكاش بالميجابايت
  Future<double> getCacheSizeMB() async {
    await init();
    if (_cacheDir == null || !await _cacheDir!.exists()) return 0.0;

    int totalBytes = 0;
    try {
      final entities = _cacheDir!.listSync(recursive: false);
      for (final entity in entities) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }
    } catch (_) {}

    return totalBytes / (1024 * 1024);
  }

  /// تفريغ كاش الفيديوهات بالكامل
  Future<void> clearMediaCache() async {
    try {
      await init();
      if (_cacheDir != null && await _cacheDir!.exists()) {
        final entities = _cacheDir!.listSync(recursive: false);
        for (final entity in entities) {
          if (entity is File) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
      debugPrint('[MediaCache] Media cache cleared.');
    } catch (e) {
      debugPrint('[MediaCache] Error clearing cache: $e');
    }
  }
}
