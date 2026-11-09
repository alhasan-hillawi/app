import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../services/cache_cleaner_service.dart';
import '../../services/media_cache_service.dart';
import '../../services/video_fit_service.dart';
import '../../services/telemetry_heartbeat_service.dart';
import '../../services/video_preload_manager.dart';
import '../../models/signage_models.dart';
import '../../models/split_screen_model.dart';
import '../../models/text_announcement_model.dart';
import '../settings/device_settings_dialog.dart';
import '../setup/pairing_screen.dart';
import '../setup/server_config_screen.dart';
import '../common/pin_dialog.dart';
import 'widgets/split_screen_multi_video_widget.dart';
import 'widgets/web_view_signage_widget.dart';
import 'widgets/single_media_widget.dart';
import 'widgets/emergency_alert_overlay_widget.dart';
import 'widgets/digital_clock_widget.dart';
import 'widgets/ticker_marquee_widget.dart';
import 'widgets/text_announcement_slide_widget.dart';

class SignagePlayerScreen extends StatefulWidget {
  final ApiService apiService;

  const SignagePlayerScreen({super.key, required this.apiService});

  @override
  State<SignagePlayerScreen> createState() => _SignagePlayerScreenState();
}

class _SignagePlayerScreenState extends State<SignagePlayerScreen> {
  late final TelemetryHeartbeatService _telemetryService;
  ScreenConfig? _config;
  int _currentItemIndex = 0;
  bool _isLoading = true;

  Timer? _itemDurationTimer;

  // مؤقت عدم الاستجابة (دقيقة واحدة = 60 ثانية)
  int _inactivitySecondsRemaining = 60;
  Timer? _inactivityCountdownTimer;
  bool _isShowingResetDialog = false;

  // إخفاء أيقونة الإعدادات ومؤشر النبض تلقائياً بعد فترة من عدم التفاعل
  bool _showControls = true;
  Timer? _controlsHideTimer;
  Timer? _initialSyncRetryTimer;

  // إشعار نمط توسيع وتقليص الفيديو (HUD Toast)
  String? _fitModeNotification;
  Timer? _fitNotificationTimer;

  void _cycleFitMode() async {
    await VideoFitService().cycleNextMode();
    _showFitNotification(VideoFitService().currentModeTitleAr);
  }

  void _showFitNotification(String message) {
    _fitNotificationTimer?.cancel();
    setState(() => _fitModeNotification = message);
    _fitNotificationTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _fitModeNotification = null);
    });
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _telemetryService = TelemetryHeartbeatService(
      apiService: widget.apiService,
      onSyncRequired: _onServerSyncRequired,
      onUnpaired: () {
        _promptResetAndRestart(
          reason: "تم إلغاء اقتران هذا الجهاز أو إزالته من لوحة التحكم.",
        );
      },
    );

    _startInactivityCountdown();
    _initialSync();
    _telemetryService.start();
    _resetControlsTimer();
  }

  /// بدء العد التنازلي لمدة دقيقة (60 ثانية) في حال عدم استجابة الخادم
  void _startInactivityCountdown() {
    _inactivityCountdownTimer?.cancel();
    _inactivitySecondsRemaining = 60;
    _inactivityCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_config != null) {
        timer.cancel();
        return;
      }
      if (_inactivitySecondsRemaining > 1) {
        setState(() {
          _inactivitySecondsRemaining--;
        });
      } else {
        timer.cancel();
        setState(() {
          _inactivitySecondsRemaining = 0;
        });
        _promptResetAndRestart(
          reason: "لم يستجب السيرفر خلال دقيقة كاملة، أو قد يكون تم فصل الجهاز من النظام.",
        );
      }
    });
  }

  void _resetControlsTimer() {
    _controlsHideTimer?.cancel();
    setState(() => _showControls = true);
    _controlsHideTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  Future<void> _initialSync() async {
    try {
      final res = await widget.apiService.fetchSyncPayload(0);
      final data = res.data['data'];
      final configJson = data['configuration'];

      if (configJson != null) {
        final newConfig = ScreenConfig.fromJson(Map<String, dynamic>.from(configJson as Map));
        final confirmedRev = data['revision'] ?? newConfig.revision;
        _telemetryService.localRevisionNotifier.value = confirmedRev;

        if (mounted) {
          _initialSyncRetryTimer?.cancel();
          _inactivityCountdownTimer?.cancel();
          setState(() {
            _config = newConfig;
            _isLoading = false;
          });

          _applyOrientation(newConfig.orientation);

          // بدء التخزين المسبق لفيديوهات القائمة في الكاش المحلي لضمان عدم حدوث أي تقطيع
          if (newConfig.playlist?.items != null) {
            MediaCacheService().cachePlaylistVideos(newConfig.playlist!.items);
          }

          _startPlaylistCycle();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);

      // في حال كان الرد 401 Unauthorized أو 404 (تم فصل الجهاز من السيرفر)
      if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 404)) {
        if (mounted) {
          _promptResetAndRestart(
            reason: "تم إلغاء اقتران هذا الجهاز أو إزالته من لوحة التحكم.",
          );
        }
      } else {
        // جدولة إعادة فحص المزامنة مع النظام كل 10 ثوانٍ تلقائياً
        _scheduleInitialSyncRetry();
      }
    }
  }

  void _scheduleInitialSyncRetry() {
    _initialSyncRetryTimer?.cancel();
    if (_config != null) return;
    _initialSyncRetryTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _config == null) {
        _initialSync();
      }
    });
  }

  /// إظهار خيار البدء من جديد للمستخدم مع شرح تأثيره
  Future<void> _promptResetAndRestart({String? reason}) async {
    if (_isShowingResetDialog || !mounted) return;
    _isShowingResetDialog = true;

    final choice = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.settings_backup_restore_rounded, color: Colors.amberAccent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "إعادة التهيئة والبدء من جديد",
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reason ?? "لم يتم استلام أي استجابة من الخادم خلال دقيقة كاملة.",
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                "• عند اختيار البدء من جديد: سيقوم التطبيق بتنظيف ذاكرة الكاش، وحذف التوكن القديم، والانتقال لتحديث رابط السيرفر وإعادة إدخال رمز الاقتران.\n• إذا لم يتم اختيار البدء من جديد: لن يحدث أي تغيير للتطبيق والنظام وسيبقى في وضع الانتظار.",
                style: GoogleFonts.cairo(color: Colors.white60, fontSize: 11, height: 1.5),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("إلغاء / مواصلة الانتظار", style: GoogleFonts.cairo(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              "البدء من جديد",
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    _isShowingResetDialog = false;

    if (choice == true && mounted) {
      await _performResetAndRestart();
    } else {
      // في حال لم يتم اختيار البدء من جديد: لا يحدث أي تغيير للتطبيق والنظام
      if (_config == null && mounted) {
        _startInactivityCountdown();
      }
    }
  }

  /// تنفيذ عملية التنظيف الكاملة والعودة لشاشة إعداد السيرفر ورمز الاقتران
  Future<void> _performResetAndRestart() async {
    _telemetryService.stop();
    _inactivityCountdownTimer?.cancel();
    _itemDurationTimer?.cancel();

    // 1. تنظيف الكاش والذاكرة المؤقتة
    try {
      await CacheCleanerService().clearAllCache();
    } catch (_) {}

    // 2. مسح رمز الاقتران والتوكن القديم
    try {
      await widget.apiService.clearToken();
    } catch (_) {}

    // 3. الانتقال لشاشة إعداد السيرفر لتحديث الرابط والاقتران
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ServerConfigScreen(apiService: widget.apiService)),
      );
    }
  }

  bool _isPlaylistChanged(List<PlaylistItemModel> oldItems, List<PlaylistItemModel> newItems) {
    if (oldItems.length != newItems.length) return true;
    for (int i = 0; i < oldItems.length; i++) {
      final oldItem = oldItems[i];
      final newItem = newItems[i];
      if (oldItem.id != newItem.id ||
          oldItem.url != newItem.url ||
          oldItem.duration != newItem.duration ||
          oldItem.type != newItem.type) {
        return true;
      }
    }
    return false;
  }

  void _onServerSyncRequired(Map<String, dynamic> rawConfig) {
    if (!mounted) return;
    final newConfig = ScreenConfig.fromJson(rawConfig);

    _inactivityCountdownTimer?.cancel();

    final oldItems = _config?.playlist?.items ?? [];
    final newItems = newConfig.playlist?.items ?? [];
    final bool playlistChanged = _config == null ||
        _config?.playlist?.id != newConfig.playlist?.id ||
        _isPlaylistChanged(oldItems, newItems);

    setState(() {
      _config = newConfig;
      _isLoading = false;
    });

    _applyOrientation(newConfig.orientation);

    // إذا لم تتغير قائمة التشغيل، نبقي الفيديو الحالي يعمل بسلاسة دون أي انقطاع
    if (playlistChanged) {
      VideoPreloadManager().pruneUnused(newItems);
      MediaCacheService().cachePlaylistVideos(newItems);
      if (newItems.isNotEmpty && _currentItemIndex >= newItems.length) {
        _currentItemIndex = 0;
      }
      _startPlaylistCycle();
    }
  }

  void _applyOrientation(String orientation) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (orientation == 'portrait') {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
  }

  void _nextSlide() {
    _itemDurationTimer?.cancel();
    final items = _config?.playlist?.items ?? [];
    if (items.isEmpty || !mounted) return;
    setState(() {
      _currentItemIndex = (_currentItemIndex + 1) % items.length;
    });
    _startPlaylistCycle();
  }

  void _startPlaylistCycle() {
    _itemDurationTimer?.cancel();
    final items = _config?.playlist?.items ?? [];
    if (items.isEmpty) return;

    final currentItem = items[_currentItemIndex % items.length];
    final int duration = currentItem.duration > 0 ? currentItem.duration : 15;

    // تسخين وتحميل المقطع التالي في الذاكرة مسبقاً لضمان 0ms انتقال بدون أي تأخير أو فراغ
    VideoPreloadManager().preloadNextItem(items, _currentItemIndex % items.length);

    _itemDurationTimer = Timer(Duration(seconds: duration), () {
      if (mounted && items.isNotEmpty) {
        _nextSlide();
      }
    });
  }

  void _openSettings() async {
    // قفل الحماية: التحقق من رمز PIN قبل فتح الإعدادات لمنع التلاعب
    final isAuthorized = await PinVerificationDialog.show(context);
    if (!isAuthorized || !mounted) return;

    DeviceSettingsDialog.show(context, widget.apiService, () {
      _telemetryService.stop();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PairingScreen(apiService: widget.apiService)),
      );
    });
  }

  @override
  void dispose() {
    _initialSyncRetryTimer?.cancel();
    _inactivityCountdownTimer?.cancel();
    _fitNotificationTimer?.cancel();
    _telemetryService.stop();
    _itemDurationTimer?.cancel();
    _controlsHideTimer?.cancel();
    VideoPreloadManager().disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // شاشة الانتظار مع مؤقت الدقيقة وزر البدء من جديد
    if (_isLoading || _config == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.indigoAccent),
                ),
                const SizedBox(height: 20),
                Text(
                  "جارٍ جلب إعدادات ومزامنة الشاشة...",
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "يطلب التطبيق الاتصال بالإنترنت - يتم إعادة فحص المزامنة مع النظام كل 10 ثوانٍ تلقائياً",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  "في حال عدم الاستجابة أو فصل الجهاز، ستظهر خيارات البدء من جديد خلال ($_inactivitySecondsRemaining ثانية)",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        setState(() => _isLoading = true);
                        _initialSync();
                      },
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: Text("فحص المزامنة الآن", style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _promptResetAndRestart(),
                      icon: const Icon(Icons.settings_backup_restore_rounded, size: 18, color: Colors.amberAccent),
                      label: Text("إعادة البدء الآن", style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final items = _config!.playlist?.items ?? [];
    final currentItem = items.isNotEmpty ? items[_currentItemIndex % items.length] : null;
    final isEmergency = _config!.isEmergencyActive && _config!.emergency != null;

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _resetControlsTimer,
        onDoubleTap: _cycleFitMode, // النقر المزدوج لتبديل نمط التوسيع والتقليص وعرض كامل الفيديو
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            // دعم أزرار ريموت التلفزيون (Menu / Settings)
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.contextMenu ||
                  event.logicalKey == LogicalKeyboardKey.settings) {
                _openSettings();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ==============================================================
              // الطبقة 1: المحتوى الأساسي للشاشة (فيديوهات، ويب، شاشات مقسمة)
              // ==============================================================
              if (currentItem != null)
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildMainContent(currentItem),
                  ),
                )
              else
                const Center(
                  child: Text("لا توجد وسائط مجدولة للعرض حالياً", style: TextStyle(color: Colors.white38)),
                ),

              // ==============================================================
              // الطبقة 2: الساعة الرقمية اللاتينية (أعلى اليسار)
              // ==============================================================
              if (_config!.clockEnabled && !isEmergency)
                Positioned(
                  top: 20,
                  left: 20,
                  child: DigitalClockWidget(
                    is24Hours: _config!.clockFormat == '24h',
                    showDate: true,
                  ),
                ),

              // ==============================================================
              // الطبقة 3: زر الإعدادات فقط (يظهر عند التفاعل ويختفي تلقائياً)
              // ==============================================================
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                top: 16,
                right: _showControls ? 16 : -60,
                child: InkWell(
                  onTap: _openSettings,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                    ),
                    child: const Icon(Icons.settings, color: Colors.white, size: 22),
                  ),
                ),
              ),

              // ==============================================================
              // الطبقة 5: الشريط الإخباري المتدفق الحي (أسفل أو أعلى الشاشة)
              // ==============================================================
              if (_config!.tickerEnabled && !isEmergency)
                Positioned(
                  bottom: _config!.tickerPosition == 'bottom' ? 0 : null,
                  top: _config!.tickerPosition == 'top' ? 0 : null,
                  left: 0,
                  right: 0,
                  child: TickerMarqueeWidget(
                    config: TickerConfigModel(
                      enabled: _config!.tickerEnabled,
                      position: _config!.tickerPosition,
                      text: _config!.tickerText,
                      textColor: TickerConfigModel.parseColor(_config!.tickerTextColor, Colors.white),
                      backgroundColor: TickerConfigModel.parseColor(_config!.tickerBackground, const Color(0xFFB91C1C)),
                      speedSeconds: _config!.tickerSpeedSeconds,
                      direction: _config!.tickerDirection,
                      fontSize: _config!.tickerFontSize,
                    ),
                  ),
                ),

              // ==============================================================
              // الطبقة 6: الاستحواذ الطارئ الفوري (أعلى أولوية Z-Index المطلقة)
              // ==============================================================
              if (isEmergency)
                Positioned.fill(
                  child: EmergencyAlertOverlayWidget(alert: _config!.emergency!),
                ),

              // ==============================================================
              // الطبقة 7: إشعار نمط التوسيع والتقليص المختار (HUD Pill Toast)
              // ==============================================================
              if (_fitModeNotification != null)
                Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C1427).withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.60),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            VideoFitService().currentModeIcon,
                            color: const Color(0xFF00E5FF),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _fitModeNotification!,
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(PlaylistItemModel item) {
    // 1. شريحة الإعلان النصي والتنبيه (بدون ملف وسائط)
    if (item.isTextAnnouncement) {
      final textSlide = TextAnnouncementSlide.fromJson({
        'id': item.id,
        'title': item.title,
        'duration': item.duration,
        'custom_content': item.customContent,
      });

      return TextAnnouncementSlideWidget(
        key: ValueKey("text_${item.id}"),
        slide: textSlide,
        onCompleted: _nextSlide,
      );
    } else if (item.isSplitScreen) {
      final rawZones = (item.customContent?['zones'] ?? item.customContent?['videos']) as List? ?? [];
      final List<SplitZone> zones;
      final currentBase = ApiService.activeBaseUrl;
      if (rawZones.isNotEmpty) {
        zones = rawZones
            .map((z) => SplitZone.fromJson(Map<String, dynamic>.from(z as Map), baseUrl: currentBase))
            .toList();
      } else {
        zones = item.splitZones
            .map((z) => SplitZone(
                  id: z.id,
                  title: z.title,
                  url: ApiService.normalizeMediaUrl(z.url, currentBase),
                  thumbnailUrl: '',
                  type: z.type,
                ))
            .toList();
      }

      final splitSlide = SplitScreenSlide(
        id: item.id,
        title: item.title,
        duration: item.duration,
        layout: item.splitLayout,
        zones: zones,
      );

      return SplitScreenMultiVideoWidget(
        key: ValueKey("split_${item.id}"),
        slide: splitSlide,
      );
    } else if (item.isWebUrl) {
      final webUrl = item.customContent?['url'] ?? item.url ?? '';
      String? htmlContent;
      if (item.customContent != null) {
        htmlContent = item.customContent!['html']?.toString() ??
            (item.type == 'html' ? item.customContent!['content']?.toString() : null);
      }
      return WebViewSignageWidget(
        key: ValueKey("web_${item.id}"),
        url: webUrl,
        htmlContent: htmlContent,
        refreshIntervalSeconds: item.customContent?['refresh_interval'] ?? 0,
      );
    } else {
      return SingleMediaWidget(
        key: ValueKey("media_${item.id}"),
        url: ApiService.normalizeMediaUrl(item.url ?? ''),
        isVideo: item.isVideo,
        onCompleted: _nextSlide,
      );
    }
  }
}
