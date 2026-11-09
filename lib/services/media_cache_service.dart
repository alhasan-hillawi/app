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

/// معلومات تفصيلية عن الملف المخزن في الكاش
class CachedMediaInfo {
  final String url;
  final String filePath;
  final int fileSize;
  final bool isCompleted;
  final int timestamp;

  CachedMediaInfo({
    required this.url,
    required this.filePath,
    required this.fileSize,
    required this.isCompleted,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'filePath': filePath,
        'fileSize': fileSize,
        'isCompleted': isCompleted,
        'timestamp': timestamp,
      };

  factory CachedMediaInfo.fromJson(Map<String, dynamic> json) => CachedMediaInfo(
        url: json['url'] ?? '',
        filePath: json['filePath'] ?? '',
        fileSize: json['fileSize'] ?? 0,
        isCompleted: json['isCompleted'] ?? false,
        timestamp: json['timestamp'] ?? 0,
      );
}

/// خدمة إدارة وتخزين وسائط الفيديو محلياً على القرص (Offline-First Video Cache Service - V2)
/// توفر نظام كاش عالي الموثوقية مع معالجة التنزيل التتابعي لمنع أي اختناق في الشبكة
/// وتضمن تشغيل الفيديوهات بسلاسة تامة ومعدل 60 إطاراً في الثانية بدون أي تقطيع.
class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  factory MediaCacheService() => _instance;
  MediaCacheService._internal();

  Directory? _cacheDir;
  File? _indexFile;
  final Map<String, CachedMediaInfo> _cacheIndex = {};
  bool _isInitialized = false;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 180),
      headers: {
        'User-Agent': 'SignagePlayer/1.1 (OfflineCacheEngine)',
      },
    ),
  );

  // قائمة انتظار التنزيل التتابعي لضمان عدم استهلاك باندويث الشبكة ومعالجة التقطيع
  final List<String> _downloadQueue = [];
  bool _isQueueProcessing = false;
  final Map<String, Completer<File?>> _pendingCompleters = {};

  /// تهيئة مجلد التخزين المؤقت وفهرس الكاش
  Future<void> init() async {
    if (_isInitialized && _cacheDir != null && await _cacheDir!.exists()) return;
    try {
      final baseDir = await getApplicationSupportDirectory();
      final dir = Directory('${baseDir.path}/signage_media_cache');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cacheDir = dir;
      _indexFile = File('${dir.path}/cache_index.json');

      await _loadIndex();
      await _validateExistingFiles();

      _isInitialized = true;
      debugPrint('[MediaCache V2] Storage initialized at: ${_cacheDir!.path} with ${_cacheIndex.length} cached items.');
    } catch (e) {
      debugPrint('[MediaCache V2] Init error: $e');
    }
  }

  /// تحميل فهرس الكاش من القرص
  Future<void> _loadIndex() async {
    if (_indexFile == null || !await _indexFile!.exists()) return;
    try {
      final content = await _indexFile!.readAsString();
      if (content.trim().isNotEmpty) {
        final Map<String, dynamic> rawMap = jsonDecode(content);
        _cacheIndex.clear();
        rawMap.forEach((key, val) {
          if (val is Map) {
            _cacheIndex[key] = CachedMediaInfo.fromJson(Map<String, dynamic>.from(val));
          }
        });
      }
    } catch (e) {
      debugPrint('[MediaCache V2] Error loading index: $e');
    }
  }

  /// حفظ فهرس الكاش على القرص
  Future<void> _saveIndex() async {
    if (_indexFile == null) return;
    try {
      final rawMap = _cacheIndex.map((key, val) => MapEntry(key, val.toJson()));
      await _indexFile!.writeAsString(jsonEncode(rawMap), flush: true);
    } catch (e) {
      debugPrint('[MediaCache V2] Error saving index: $e');
    }
  }

  /// فحص سلامة الملفات والتخلص من الملفات غير المكتملة
  Future<void> _validateExistingFiles() async {
    final toRemove = <String>[];
    for (final entry in _cacheIndex.entries) {
      final file = File(entry.value.filePath);
      if (!await file.exists()) {
        toRemove.add(entry.key);
      } else {
        final length = await file.length();
        if (length < 32768 || (entry.value.fileSize > 0 && length < entry.value.fileSize)) {
          try {
            await file.delete();
          } catch (_) {}
          toRemove.add(entry.key);
        }
      }
    }

    if (toRemove.isNotEmpty) {
      for (final key in toRemove) {
        _cacheIndex.remove(key);
      }
      await _saveIndex();
    }
  }

  /// توليد اسم ملف فريد ومستقر بناءً على رابط الفيديو
  String _generateFileName(String url) {
    final cleanUrl = ApiService.normalizeMediaUrl(url).trim();
    final hash = md5.convert(utf8.encode(cleanUrl)).toString();

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

  /// جلب مسار الملف المحلي المخزن في الكاش والتأكد من اكتماله 100%
  Future<File?> getCachedFile(String rawUrl) async {
    await init();
    if (_cacheDir == null) return null;

    final cleanUrl = ApiService.normalizeMediaUrl(rawUrl).trim();
    final info = _cacheIndex[cleanUrl];

    if (info != null && info.isCompleted) {
      final file = File(info.filePath);
      if (await file.exists()) {
        final len = await file.length();
        if (len >= 32768) {
          return file;
        }
      }
    }

    // فحص مباشر على القرص بالاسم المتوقع
    final fileName = _generateFileName(cleanUrl);
    final file = File('${_cacheDir!.path}/$fileName');
    if (await file.exists()) {
      final len = await file.length();
      if (len >= 32768) {
        // تسجيله في الفهرس
        _cacheIndex[cleanUrl] = CachedMediaInfo(
          url: cleanUrl,
          filePath: file.path,
          fileSize: len,
          isCompleted: true,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        _saveIndex();
        return file;
      }
    }

    return null;
  }

  /// التحقق السريع من وجود الفيديو في الكاش
  Future<bool> isCached(String rawUrl) async {
    final file = await getCachedFile(rawUrl);
    return file != null;
  }

  /// طلب تحميل وتخزين الفيديو في الكاش (مع دعم الأولوية العالية)
  Future<File?> downloadAndCache(String rawUrl, {bool highPriority = false}) async {
    final cleanUrl = ApiService.normalizeMediaUrl(rawUrl).trim();
    if (cleanUrl.isEmpty) return null;

    // 1. إذا كان الملف موجوداً مسبقاً، إرجاعه فوراً
    final existingFile = await getCachedFile(cleanUrl);
    if (existingFile != null) {
      return existingFile;
    }

    // 2. إذا كان هناك طلب تحميل جارٍ أو معلق، إرجاع الـ Future المشترك
    if (_pendingCompleters.containsKey(cleanUrl)) {
      if (highPriority) {
        // رفع أولوية الملف إلى مقدمة قائمة الانتظار
        _downloadQueue.remove(cleanUrl);
        _downloadQueue.insert(0, cleanUrl);
      }
      return await _pendingCompleters[cleanUrl]!.future;
    }

    // 3. إضافة الطلب إلى قائمة الانتظار التتابعية
    final completer = Completer<File?>();
    _pendingCompleters[cleanUrl] = completer;

    if (highPriority) {
      _downloadQueue.insert(0, cleanUrl);
    } else {
      _downloadQueue.add(cleanUrl);
    }

    // بدء معالجة الطابور بشكل تتابعي
    _processQueue();

    return await completer.future;
  }

  /// معالج قائمة التنزيل التتابعي (Single-Worker Queue)
  /// يمنع تماماً أي اختناق في الشبكة أو تقطيع في الفيديو المعروض حالياً
  Future<void> _processQueue() async {
    if (_isQueueProcessing) return;
    _isQueueProcessing = true;

    while (_downloadQueue.isNotEmpty) {
      final url = _downloadQueue.removeAt(0);
      final completer = _pendingCompleters[url];

      try {
        await init();
        final fileName = _generateFileName(url);
        final finalPath = '${_cacheDir!.path}/$fileName';
        final tempPath = '${_cacheDir!.path}/$fileName.tmp';

        // التأكد أولاً من عدم وجوده مسبقاً
        final existing = await getCachedFile(url);
        if (existing != null) {
          completer?.complete(existing);
          _pendingCompleters.remove(url);
          continue;
        }

        debugPrint('[MediaCache V2] Starting download: $url');

        final response = await _dio.download(
          url,
          tempPath,
          deleteOnError: true,
        );

        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          final len = await tempFile.length();
          if (len >= 32768 && response.statusCode == 200) {
            final finalFile = await tempFile.rename(finalPath);
            final cachedInfo = CachedMediaInfo(
              url: url,
              filePath: finalFile.path,
              fileSize: len,
              isCompleted: true,
              timestamp: DateTime.now().millisecondsSinceEpoch,
            );
            _cacheIndex[url] = cachedInfo;
            await _saveIndex();

            debugPrint('[MediaCache V2] Cached successfully: $fileName ($len bytes)');
            completer?.complete(finalFile);
          } else {
            try {
              await tempFile.delete();
            } catch (_) {}
            completer?.complete(null);
          }
        } else {
          completer?.complete(null);
        }
      } catch (e) {
        debugPrint('[MediaCache V2] Download failed for $url: $e');
        completer?.complete(null);
      } finally {
        _pendingCompleters.remove(url);
      }

      // استراحة قصيرة بين كل تنزيل وآخر لإراحة المعالج والشبكة
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _isQueueProcessing = false;
  }

  /// الجدولة الذكية لكافة فيديوهات قائمة التشغيل في الخلفية بالتتابع
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

    for (final url in videoUrls) {
      final isReady = await isCached(url);
      if (!isReady) {
        downloadAndCache(url, highPriority: false);
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
        if (entity is File && !entity.path.endsWith('.json') && !entity.path.endsWith('.tmp')) {
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
      _cacheIndex.clear();
      debugPrint('[MediaCache V2] Media cache cleared.');
    } catch (e) {
      debugPrint('[MediaCache V2] Error clearing cache: $e');
    }
  }
}
