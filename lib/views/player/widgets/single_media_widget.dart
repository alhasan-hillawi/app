import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/api_service.dart';
import '../../../services/media_cache_service.dart';
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

    if (duration > Duration.zero && position >= duration - const Duration(milliseconds: 200)) {
      _hasNotifiedCompletion = true;
      widget.onCompleted?.call();
    }
  }

  Future<void> _initVideo() async {
    final normalized = ApiService.normalizeMediaUrl(widget.url);
    _hasNotifiedCompletion = false;

    // 1. فحص إذا كان الفيديو مسخناً ومجهزاً مسبقاً في الذاكرة (Pre-warmed in 0ms)
    final preloaded = VideoPreloadManager().getPreloadedController(normalized);
    if (preloaded != null && preloaded.value.isInitialized) {
      _videoController = preloaded;
      _videoController!.setLooping(true);
      _videoController!.setVolume(VolumeService().effectiveVolume);
      _videoController!.addListener(_videoListener);
      _videoController!.play();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
      return;
    }

    // 2. فحص ما إذا كان الفيديو مخزناً مسبقاً في الكاش المحلي (Local Storage Cache)
    final cachedFile = await MediaCacheService().getCachedFile(normalized);
    if (cachedFile != null) {
      debugPrint('[SingleMedia] Playing video smoothly from local cache: ${cachedFile.path}');
      _videoController = VideoPlayerController.file(cachedFile);
    } else {
      // إذا لم يكتمل تحميله بعد، البدء بالتحميل في الخلفية والتشغيل المؤقت من الشبكة
      MediaCacheService().downloadAndCache(normalized);
      _videoController = VideoPlayerController.networkUrl(Uri.parse(normalized));
    }

    try {
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.setVolume(VolumeService().effectiveVolume);
      _videoController!.addListener(_videoListener);
      _videoController!.play();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('[SingleMedia] Error initializing video: $e (URL: $normalized)');
    }
  }

  @override
  void didUpdateWidget(covariant SingleMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.isVideo != widget.isVideo) {
      _videoController?.removeListener(_videoListener);
      _videoController?.dispose();
      _videoController = null;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVideo) {
      return SizedBox.expand(
        child: CachedNetworkImage(
          imageUrl: widget.url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          // إزالة أي علامة انتظار والانتقال المباشر والفوري
          placeholder: (_, __) => Container(color: Colors.black),
          errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.white24)),
        ),
      );
    }

    // في حال كان الفيديو بانتظار التهيئة: عرض شاشة سوداء نظيفة ومستمرة بدون أي علامة loading
    if (!_isInitialized || _videoController == null) {
      return Container(color: Colors.black);
    }

    // عرض الفيديو بملء الشاشة بالكامل دون أي حواف سوداء
    final videoSize = _videoController!.value.size;
    final width = videoSize.width > 0 ? videoSize.width : 1920.0;
    final height = videoSize.height > 0 ? videoSize.height : 1080.0;

    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: width,
            height: height,
            child: VideoPlayer(_videoController!),
          ),
        ),
      ),
    );
  }
}
