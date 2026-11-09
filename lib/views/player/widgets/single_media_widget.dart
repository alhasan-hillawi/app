import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/api_service.dart';
import '../../../services/media_cache_service.dart';
import '../../../services/video_fit_service.dart';
import '../../../services/volume_service.dart';
import '../../../services/video_preload_manager.dart';

class SingleMediaWidget extends StatefulWidget {
  final String url;
  final bool isVideo;
  final VoidCallback? onCompleted;

  const SingleMediaWidget({
    super.key,
    required this.url,
    required this.isVideo,
    this.onCompleted,
  });

  @override
  State<SingleMediaWidget> createState() => _SingleMediaWidgetState();
}

class _SingleMediaWidgetState extends State<SingleMediaWidget> {
  VideoPlayerController? _videoController;
  VideoPlayerController? _previousController; // للاحتفاظ بالإطار الأخير ومنع أي شاشة سوداء أثناء التبديل
  bool _isInitialized = false;
  bool _hasNotifiedCompletion = false;

  @override
  void initState() {
    super.initState();
    VolumeService().volumeNotifier.addListener(_onVolumeChanged);
    VolumeService().isMutedNotifier.addListener(_onVolumeChanged);
    if (widget.isVideo) {
      _initVideo();
    }
  }

  void _onVolumeChanged() {
    if (_videoController != null && _isInitialized) {
      _videoController!.setVolume(VolumeService().effectiveVolume);
    }
  }

  void _videoListener() {
    if (!mounted || _videoController == null || !_isInitialized || _hasNotifiedCompletion) return;
    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;

    if (duration > Duration.zero && position >= duration - const Duration(milliseconds: 250)) {
      _hasNotifiedCompletion = true;
      widget.onCompleted?.call();
    }
  }

  Future<void> _initVideo() async {
    final normalized = ApiService.normalizeMediaUrl(widget.url);
    _hasNotifiedCompletion = false;

    // 1. فحص إذا كان الفيديو مجهزاً مسبقاً في الذاكرة (Pre-warmed in 0ms)
    final preloaded = VideoPreloadManager().getPreloadedController(normalized);
    if (preloaded != null && preloaded.value.isInitialized) {
      _swapToController(preloaded);
      return;
    }

    // 2. فحص الكاش المحلي المكتمل 100% لتشغيل محلي صلب وخالٍ تماماً من التقطيع
    final cachedFile = await MediaCacheService().getCachedFile(normalized);
    VideoPlayerController newController;

    if (cachedFile != null) {
      debugPrint('[SingleMedia] Playing video locally from cache: ${cachedFile.path}');
      newController = VideoPlayerController.file(
        cachedFile,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
    } else {
      // تنزيل الملف في الخلفية بأولوية عالية للمرات القادمة
      MediaCacheService().downloadAndCache(normalized, highPriority: true);
      debugPrint('[SingleMedia] Cache miss. Streaming via network temporarily: $normalized');
      newController = VideoPlayerController.networkUrl(
        Uri.parse(normalized),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
    }

    try {
      await newController.initialize();
      _swapToController(newController);
    } catch (e) {
      debugPrint('[SingleMedia] Error initializing video controller: $e (URL: $normalized)');
      newController.dispose();
    }
  }

  void _swapToController(VideoPlayerController newController) {
    if (!mounted) {
      newController.dispose();
      return;
    }

    newController.setLooping(true);
    newController.setVolume(VolumeService().effectiveVolume);
    newController.addListener(_videoListener);
    newController.play();

    final old = _videoController;
    setState(() {
      _previousController = old;
      _videoController = newController;
      _isInitialized = true;
    });

    // تفريغ المشغل السابق بعد استقرار المشغل الجديد بسلاسة
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted && _previousController != null) {
        _previousController!.removeListener(_videoListener);
        _previousController!.dispose();
        _previousController = null;
      }
    });
  }

  @override
  void didUpdateWidget(covariant SingleMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.isVideo != widget.isVideo) {
      _isInitialized = false;
      _hasNotifiedCompletion = false;
      if (widget.isVideo) {
        _initVideo();
      }
    }
  }

  @override
  void dispose() {
    VolumeService().volumeNotifier.removeListener(_onVolumeChanged);
    VolumeService().isMutedNotifier.removeListener(_onVolumeChanged);
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _previousController?.removeListener(_videoListener);
    _previousController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoFitMode>(
      valueListenable: VideoFitService().fitModeNotifier,
      builder: (context, _, __) {
        final fit = VideoFitService().currentBoxFit;

        // 1. عرض الصور بدقة ونمط الملاءمة المختار
        if (!widget.isVideo) {
          return SizedBox.expand(
            child: CachedNetworkImage(
              imageUrl: widget.url,
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              placeholder: (_, __) => Container(color: Colors.black),
              errorWidget: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, size: 48, color: Colors.white24),
              ),
            ),
          );
        }

        // 2. في حال كان الفيديو بانتظار التهيئة وكان هناك مشغل سابق، إبقاؤه معروضاً لمنع الوميض الأسود
        final activeController = (_isInitialized && _videoController != null)
            ? _videoController
            : _previousController;

        if (activeController == null || !activeController.value.isInitialized) {
          return Container(color: Colors.black);
        }

        final videoSize = activeController.value.size;
        final width = videoSize.width > 0 ? videoSize.width : 1920.0;
        final height = videoSize.height > 0 ? videoSize.height : 1080.0;

        return Container(
          color: Colors.black,
          child: ClipRect(
            child: SizedBox.expand(
              child: FittedBox(
                fit: fit,
                alignment: Alignment.center,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: VideoPlayer(activeController),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
