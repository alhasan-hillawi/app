import '../services/api_service.dart';

class ScreenConfig {
  final int screenId;
  final String screenUuid;
  final String screenName;
  final int revision;
  final String orientation; // 'landscape' or 'portrait'
  final bool clockEnabled;
  final String clockFormat; // '24h' or '12h'
  final bool tickerEnabled;
  final String tickerPosition; // 'bottom' or 'top'
  final String tickerText;
  final String tickerBackground;
  final String tickerTextColor;
  final int tickerSpeedSeconds;
  final String tickerDirection; // 'rtl' or 'ltr'
  final double tickerFontSize;
  final bool isEmergencyActive;
  final EmergencyAlert? emergency;
  final PlaylistModel? playlist;

  ScreenConfig({
    required this.screenId,
    required this.screenUuid,
    required this.screenName,
    required this.revision,
    required this.orientation,
    required this.clockEnabled,
    required this.clockFormat,
    required this.tickerEnabled,
    required this.tickerPosition,
    required this.tickerText,
    required this.tickerBackground,
    required this.tickerTextColor,
    required this.tickerSpeedSeconds,
    required this.tickerDirection,
    required this.tickerFontSize,
    required this.isEmergencyActive,
    this.emergency,
    this.playlist,
  });

  factory ScreenConfig.fromJson(Map<String, dynamic> json) {
    final screen = json['screen'] ?? {};
    final layout = json['layout'] ?? {};
    final clock = json['clock'] ?? {};
    final ticker = json['ticker'] ?? {};
    final emergencyJson = json['emergency'] ?? {};

    return ScreenConfig(
      screenId: screen['id'] ?? 0,
      screenUuid: screen['uuid'] ?? '',
      screenName: screen['name'] ?? '',
      revision: screen['revision'] ?? 1,
      orientation: layout['orientation'] ?? 'landscape',
      clockEnabled: clock['enabled'] ?? true,
      clockFormat: clock['format'] ?? '24h',
      tickerEnabled: ticker['enabled'] ?? false,
      tickerPosition: ticker['position'] ?? 'bottom',
      tickerText: ticker['text'] ?? '',
      tickerBackground: ticker['background_color'] ?? '#b91c1c',
      tickerTextColor: ticker['text_color'] ?? '#ffffff',
      tickerSpeedSeconds: ticker['speed_seconds'] ?? 20,
      tickerDirection: ticker['direction'] ?? 'rtl',
      tickerFontSize: (ticker['font_size'] as num?)?.toDouble() ?? 22.0,
      isEmergencyActive: emergencyJson['is_active'] ?? false,
      emergency: emergencyJson['is_active'] == true ? EmergencyAlert.fromJson(emergencyJson) : null,
      playlist: json['playlist'] != null ? PlaylistModel.fromJson(json['playlist']) : null,
    );
  }
}

class EmergencyAlert {
  final int? alertId;
  final String title;
  final String message;
  final String alertType; // fire, evacuation, weather, security
  final String severity; // critical, warning, info
  final String displayMode; // fullscreen, banner
  final bool soundAlarm;

  EmergencyAlert({
    this.alertId,
    required this.title,
    required this.message,
    required this.alertType,
    required this.severity,
    required this.displayMode,
    required this.soundAlarm,
  });

  factory EmergencyAlert.fromJson(Map<String, dynamic> json) {
    return EmergencyAlert(
      alertId: json['alert_id'],
      title: json['title'] ?? 'حالة طوارئ قصوى',
      message: json['message'] ?? '',
      alertType: json['alert_type'] ?? 'general',
      severity: json['severity'] ?? 'critical',
      displayMode: json['display_mode'] ?? 'fullscreen',
      soundAlarm: json['sound_alarm'] ?? true,
    );
  }
}

class PlaylistModel {
  final int id;
  final String name;
  final bool loop;
  final List<PlaylistItemModel> items;

  PlaylistModel({required this.id, required this.name, required this.loop, required this.items});

  factory PlaylistModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    return PlaylistModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      loop: json['loop'] ?? true,
      items: rawItems.map((e) => PlaylistItemModel.fromJson(e)).toList(),
    );
  }
}

class PlaylistItemModel {
  final int id;
  final String type; // 'video', 'image', 'url', 'split_screen', 'live'
  final String title;
  final String? url;
  final int duration;
  final Map<String, dynamic>? customContent;

  PlaylistItemModel({
    required this.id,
    required this.type,
    required this.title,
    this.url,
    required this.duration,
    this.customContent,
  });

  factory PlaylistItemModel.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['url'] ?? (json['media'] != null ? json['media']['url'] : null);
    return PlaylistItemModel(
      id: json['id'] ?? 0,
      type: json['type'] ?? 'video',
      title: json['title'] ?? '',
      url: rawUrl != null ? ApiService.normalizeMediaUrl(rawUrl.toString()) : null,
      duration: json['duration'] ?? 15,
      customContent: json['custom_content'],
    );
  }

  bool get isSplitScreen =>
      type == 'split_screen' ||
      type == 'split' ||
      type == 'multi_video' ||
      (customContent != null && (customContent!['zones'] != null || customContent!['videos'] != null));

  bool get isWebUrl {
    if (type == 'url' ||
        type == 'web' ||
        type == 'website' ||
        type == 'webpage' ||
        type == 'html' ||
        type == 'app' ||
        type == 'live') {
      return true;
    }
    final lower = (url ?? '').toLowerCase();
    if (lower.contains('youtube.com') ||
        lower.contains('youtu.be') ||
        lower.endsWith('.html') ||
        lower.endsWith('.htm') ||
        lower.endsWith('.php')) {
      return true;
    }
    return false;
  }

  bool get isImage {
    if (type == 'image') return true;
    final lower = (url ?? '').toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  bool get isTextAnnouncement =>
      type == 'text' ||
      type == 'announcement' ||
      type == 'notice' ||
      type == 'message';

  bool get isVideo => !isImage && !isSplitScreen && !isWebUrl && !isTextAnnouncement;

  String get splitLayout => customContent?['layout'] ?? 'split_2_vertical';

  List<SplitZoneModel> get splitZones {
    final raw = (customContent?['zones'] ?? customContent?['videos'] ?? customContent?['items']) as List? ?? [];
    return raw.map((z) => SplitZoneModel.fromJson(Map<String, dynamic>.from(z as Map))).toList();
  }
}

class SplitZoneModel {
  final int id;
  final String title;
  final String url;
  final String type;

  SplitZoneModel({required this.id, required this.title, required this.url, required this.type});

  factory SplitZoneModel.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['url'] ?? (json['media'] != null ? json['media']['url'] : '') ?? '';
    return SplitZoneModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['name'] ?? '',
      url: ApiService.normalizeMediaUrl(rawUrl.toString()),
      type: json['type'] ?? 'video',
    );
  }
}

