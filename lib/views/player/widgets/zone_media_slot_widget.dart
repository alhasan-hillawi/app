import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/split_screen_model.dart';
import '../../../models/text_announcement_model.dart';
import '../../../services/api_service.dart';
import '../../../services/volume_service.dart';
import 'web_view_signage_widget.dart';
import 'text_announcement_slide_widget.dart';

class ZoneMediaSlotWidget extends StatefulWidget {
  final SplitZone zone;
  final bool isAudioEnabled;

  const ZoneMediaSlotWidget({
    super.key,
    required this.zone,
    required this.isAudioEnabled,
  });

  @override
  State<ZoneMediaSlotWidget> createState() => _ZoneMediaSlotWidgetState();
}

class _ZoneMediaSlotWidgetState extends State<ZoneMediaSlotWidget> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    VolumeService().volumeNotifier.addListener(_onVolumeChanged);
    VolumeService().isMutedNotifier.addListener(_onVolumeChanged);
    if (widget.zone.isVideo && widget.zone.url.isNotEmpty) {
      _initVideo();
    }
  }

  void _onVolumeChanged() {
    if (_videoController != null && _isInitialized) {
      _videoController!.setVolume(widget.isAudioEnabled ? VolumeService().effectiveVolume : 0.0);
    }
  }

  Future<void> _initVideo() async {
    final normalizedUrl = ApiService.normalizeMediaUrl(widget.zone.url);
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(normalizedUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(widget.isAudioEnabled ? VolumeService().effectiveVolume : 0.0);
      controller.play();

      if (mounted) {
        setState(() {
          _videoController = controller;
          _isInitialized = true;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('[ZoneMediaSlot] Error initializing video: $e (URL: $normalizedUrl)');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant ZoneMediaSlotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zone.url != widget.zone.url) {
      _videoController?.dispose();
      _videoController = null;
      _isInitialized = false;
      _hasError = false;
      if (widget.zone.isVideo && widget.zone.url.isNotEmpty) {
        _initVideo();
      }
    } else if (_videoController != null && _isInitialized) {
      if (oldWidget.isAudioEnabled != widget.isAudioEnabled) {
        _videoController!.setVolume(widget.isAudioEnabled ? VolumeService().effectiveVolume : 0.0);
      }
    }
  }

  @override
  void dispose() {
    VolumeService().volumeNotifier.removeListener(_onVolumeChanged);
    VolumeService().isMutedNotifier.removeListener(_onVolumeChanged);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. إذا كان نوع المنطقة إعلان نصي أو تعميم
    if (widget.zone.isTextAnnouncement) {
      final textSlide = TextAnnouncementSlide.fromJson({
        'id': widget.zone.id,
        'title': widget.zone.title,
        'custom_content': widget.zone.customContent,
      });
      return SizedBox.expand(
        child: TextAnnouncementSlideWidget(
          key: ValueKey("zone_text_${widget.zone.id}"),
          slide: textSlide,
        ),
      );
    }

    // 2. إذا كان نوع المنطقة صورة (Image)
    if (widget.zone.isImage) {
      return SizedBox.expand(
        child: CachedNetworkImage(
          imageUrl: widget.zone.url,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: Colors.black),
          errorWidget: (_, __, ___) => _buildFallback("تعذر تحميل الصورة"),
        ),
      );
    }

    // 3. إذا كان نوع المنطقة موقع ويب حي أو تطبيق ويب أو يوتيوب
    if (widget.zone.isWeb) {
      return SizedBox.expand(
        child: WebViewSignageWidget(
          key: ValueKey("zone_web_${widget.zone.id}_${widget.zone.url}"),
          url: widget.zone.url,
        ),
      );
    }

    // 4. إذا كان فيديو وحدث خطأ في جلب الملف أو تشغيله
    if (_hasError) {
      return _buildFallback(widget.zone.title.isNotEmpty ? widget.zone.title : "تعذر تشغيل المقطع");
    }

    // 5. أثناء تحميل الفيديو الأولي (عرض الـ Thumbnail إن وجد بدون أي علامة loading)
    if (!_isInitialized || _videoController == null) {
      if (widget.zone.hasValidThumbnail) {
        return CachedNetworkImage(
          imageUrl: widget.zone.thumbnailUrl,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(color: Colors.black),
        );
      }
      return Container(color: Colors.black);
    }

    // 4. تشغيل الفيديو ملء خانة المنطقة بالكامل (Edge-to-Edge)
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

  Widget _buildFallback(String label) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_rounded, color: Colors.amber, size: 36),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            if (widget.zone.url.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.zone.url,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

