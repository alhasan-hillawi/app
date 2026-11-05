import '../services/api_service.dart';

class SplitScreenSlide {
  final int id;
  final String title;
  final int duration;
  final String layout; // 'split_2_vertical', 'split_2_horizontal', 'split_3_main_side', 'split_4_grid'
  final List<SplitZone> zones;

  SplitScreenSlide({
    required this.id,
    required this.title,
    required this.duration,
    required this.layout,
    required this.zones,
  });

  factory SplitScreenSlide.fromJson(Map<String, dynamic> json, {String baseUrl = ""}) {
    final custom = (json['custom_content'] as Map<String, dynamic>?) ?? {};
    final rawZones = (custom['zones'] ?? custom['videos'] ?? json['zones']) as List? ?? [];

    return SplitScreenSlide(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'شاشة مقسمة',
      duration: json['duration'] ?? 20,
      layout: custom['layout'] ?? 'split_2_vertical',
      zones: rawZones.map((z) => SplitZone.fromJson(Map<String, dynamic>.from(z as Map), baseUrl: baseUrl)).toList(),
    );
  }
}

class SplitZone {
  final int id;
  final String title;
  final String url;
  final String thumbnailUrl;
  final String type; // 'video', 'image', 'url', 'text', 'announcement'
  final Map<String, dynamic>? customContent;

  SplitZone({
    required this.id,
    required this.title,
    required this.url,
    required this.thumbnailUrl,
    required this.type,
    this.customContent,
  });

  factory SplitZone.fromJson(Map<String, dynamic> json, {String baseUrl = ""}) {
    String rawUrl = json['url'] ?? (json['media'] != null ? json['media']['url'] : '') ?? '';
    String rawThumb = json['thumbnail_url'] ?? (json['media'] != null ? json['media']['thumbnail_url'] : '') ?? '';

    rawUrl = ApiService.normalizeMediaUrl(rawUrl, baseUrl);
    rawThumb = ApiService.normalizeMediaUrl(rawThumb, baseUrl);

    return SplitZone(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['name'] ?? '',
      url: rawUrl,
      thumbnailUrl: rawThumb,
      type: json['type'] ?? 'video',
      customContent: json['custom_content'],
    );
  }

  bool get isTextAnnouncement =>
      type == 'text' ||
      type == 'announcement' ||
      type == 'notice' ||
      type == 'message';

  bool get isImage {
    if (type == 'image') return true;
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  bool get isWeb =>
      type == 'url' ||
      type == 'web' ||
      type == 'website' ||
      type == 'html' ||
      type == 'app' ||
      type == 'live' ||
      (!isImage && !isTextAnnouncement && (url.contains('youtube.com') || url.contains('youtu.be') || url.endsWith('.html') || url.endsWith('.htm')));

  bool get isVideo => !isImage && !isWeb && !isTextAnnouncement;

  bool get hasValidThumbnail {
    if (thumbnailUrl.isEmpty) return false;
    final lower = thumbnailUrl.toLowerCase();
    if (lower.contains('/stream/')) return false;
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.contains('/thumbs/') ||
        lower.contains('thumb');
  }
}

