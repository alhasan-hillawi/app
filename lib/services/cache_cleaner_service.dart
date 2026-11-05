import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

class CacheCleanerService {
  /// تنظيف كافة الملفات المؤقتة وإرجاع حجم الميجابايت المحررة
  Future<String> clearAllCache() async {
    int totalBytesFreed = 0;

    try {
      // 1. تنظيف مجلد التخزين المؤقت المؤقت
      final tempDir = await getTemporaryDirectory();
      totalBytesFreed += await _deleteDirectoryContents(tempDir);

      // 2. تنظيف مجلد كاش التطبيق العام
      final appSupportDir = await getApplicationSupportDirectory();
      totalBytesFreed += await _deleteDirectoryContents(appSupportDir);

      // 3. تنظيف كاش الصور في الذاكرة العشوائية لـ Flutter
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (e) {
      // استمرار حتى لو تعذر حذف بعض الملفات المقفولة
    }

    final double mbFreed = totalBytesFreed / (1024 * 1024);
    return mbFreed.toStringAsFixed(2);
  }

  Future<int> _deleteDirectoryContents(Directory dir) async {
    int bytes = 0;
    if (await dir.exists()) {
      final List<FileSystemEntity> entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        try {
          if (entity is File) {
            bytes += await entity.length();
            await entity.delete();
          }
        } catch (_) {}
      }
    }
    return bytes;
  }
}

