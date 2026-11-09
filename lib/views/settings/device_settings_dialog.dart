import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../services/device_info_service.dart';
import '../../services/cache_cleaner_service.dart';
import '../../services/video_fit_service.dart';
import '../../services/volume_service.dart';
import '../setup/server_config_screen.dart';

class DeviceSettingsDialog extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onUnpaired;

  const DeviceSettingsDialog({
    super.key,
    required this.apiService,
    required this.onUnpaired,
  });

  static Future<void> show(BuildContext context, ApiService api, VoidCallback onUnpaired) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => DeviceSettingsDialog(apiService: api, onUnpaired: onUnpaired),
    );
  }

  @override
  State<DeviceSettingsDialog> createState() => _DeviceSettingsDialogState();
}

class _DeviceSettingsDialogState extends State<DeviceSettingsDialog> {
  final DeviceInfoService _infoService = DeviceInfoService();
  final CacheCleanerService _cacheService = CacheCleanerService();

  Map<String, dynamic> _deviceSpecs = {};
  bool _isLoading = true;
  bool _isCleaning = false;
  bool _isLandscape = true;
  String _serverUrl = "";
  double _volume = 1.0;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _volume = VolumeService().volume;
    _isMuted = VolumeService().isMuted;
    VolumeService().volumeNotifier.addListener(_onVolumeChanged);
    VolumeService().isMutedNotifier.addListener(_onVolumeChanged);
    _loadData();
  }

  void _onVolumeChanged() {
    if (mounted) {
      setState(() {
        _volume = VolumeService().volume;
        _isMuted = VolumeService().isMuted;
      });
    }
  }

  @override
  void dispose() {
    VolumeService().volumeNotifier.removeListener(_onVolumeChanged);
    VolumeService().isMutedNotifier.removeListener(_onVolumeChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    final specs = await _infoService.getFullDeviceSpecs();
    final url = await widget.apiService.getBaseUrl();
    if (mounted) {
      setState(() {
        _deviceSpecs = specs;
        _serverUrl = url;
        _isLoading = false;
      });
    }
  }

  // تبديل وضع الشاشة (أفقي / عمودي)
  void _toggleOrientation() {
    setState(() => _isLandscape = !_isLandscape);
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  // تنظيف الكاش
  Future<void> _cleanCache() async {
    setState(() => _isCleaning = true);
    final freedMb = await _cacheService.clearAllCache();
    setState(() => _isCleaning = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "تم تنظيف الذاكرة المؤقتة وتحرير $freedMb MB بنجاح!",
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // فك الاقتران
  Future<void> _unpair() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "تأكيد فك الاقتران",
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: Text(
          "هل أنت متأكد من فك اقتران هذا الجهاز؟ سيتوقف البث فوراً وسيتطلب إدخال رمز جديد.",
          style: GoogleFonts.cairo(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("فك الاقتران الآن",
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.apiService.unpairDevice();
      } catch (_) {}
      await widget.apiService.clearToken();
      if (mounted) {
        Navigator.pop(context);
        widget.onUnpaired();
      }
    }
  }

  // الخروج من التطبيق
  void _exitApplication() {
    SystemNavigator.pop();
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.88).clamp(320.0, 480.0);
    final dialogMaxHeight = (screenSize.height * 0.82).clamp(360.0, 580.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: dialogMaxHeight),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.25), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // شريط العنوان مع زر X للإغلاق السريع
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.settings, color: Color(0xFF00E5FF), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "إعدادات المشغل",
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      // زر X المخصص للإغلاق السلس
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 20),

                  // محتوى الإعدادات القابل للتمرير بدقة وتناسق
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. بطاقة مواصفات الجهاز السريعة
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF070B18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              children: [
                                _buildRow("معرف الشاشة:", _deviceSpecs['uuid'] ?? '—'),
                                _buildRow("الجهاز والموديل:", "${_deviceSpecs['brand'] ?? ''} ${_deviceSpecs['model'] ?? 'عرض عام'}"),
                                _buildRow("عنوان الـ IP:", _deviceSpecs['ip'] ?? '127.0.0.1'),
                                _buildRow("المساحة المتوفرة:", _deviceSpecs['disk_free'] ?? 'غير محدد'),
                                _buildRow("إصدار التطبيق:", _deviceSpecs['app_version'] ?? '1.1.0'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 2. نمط توسيع وتقليص الفيديو على حجم الشاشة
                          ValueListenableBuilder<VideoFitMode>(
                            valueListenable: VideoFitService().fitModeNotifier,
                            builder: (context, mode, _) {
                              return _buildActionTile(
                                icon: VideoFitService().currentModeIcon,
                                iconColor: const Color(0xFF00E5FF),
                                title: "ملاءمة وتوسيع الفيديو:",
                                subtitle: VideoFitService().currentModeTitleAr,
                                actionText: "تبديل النمط",
                                actionColor: const Color(0xFF0C243B),
                                onAction: () => VideoFitService().cycleNextMode(),
                              );
                            },
                          ),
                          const SizedBox(height: 8),

                          // 3. التحكم بمستوى الصوت
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF070B18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          _isMuted || _volume == 0
                                              ? Icons.volume_off_rounded
                                              : (_volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                                          color: _isMuted || _volume == 0 ? Colors.redAccent : const Color(0xFF00E5FF),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "مستوى الصوت: ${_isMuted ? 'مكتوم' : '${(_volume * 100).toInt()}%'}",
                                          style: GoogleFonts.cairo(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                      height: 28,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _isMuted ? Colors.green.shade800 : Colors.red.shade800,
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: () => VolumeService().toggleMute(),
                                        child: Text(
                                          _isMuted ? "تشغيل" : "كتم",
                                          style: GoogleFonts.cairo(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    trackHeight: 3,
                                  ),
                                  child: Slider(
                                    value: _isMuted ? 0.0 : _volume,
                                    onChanged: (val) => VolumeService().setVolume(val),
                                    activeColor: const Color(0xFF00E5FF),
                                    inactiveColor: Colors.white12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 4. تدوير اتجاه الشاشة
                          _buildActionTile(
                            icon: _isLandscape ? Icons.screen_lock_landscape : Icons.screen_lock_portrait,
                            iconColor: Colors.amber,
                            title: "اتجاه الشاشة:",
                            subtitle: _isLandscape ? "أفقي (Landscape)" : "عمودي (Portrait)",
                            actionText: "تبديل",
                            actionColor: Colors.amber.shade900,
                            onAction: _toggleOrientation,
                          ),
                          const SizedBox(height: 8),

                          // 5. تنظيف الكاش
                          _buildActionTile(
                            icon: Icons.cleaning_services_rounded,
                            iconColor: Colors.cyanAccent,
                            title: "تنظيف الذاكرة المؤقتة:",
                            subtitle: "حذف الملفات المؤقتة لتحرير المساحة",
                            actionText: _isCleaning ? "جاري..." : "تنظيف",
                            actionColor: Colors.cyan.shade900,
                            onAction: _isCleaning ? null : _cleanCache,
                          ),
                          const SizedBox(height: 8),

                          // 6. تعديل رابط الخادم
                          _buildActionTile(
                            icon: Icons.cloud_sync_rounded,
                            iconColor: Colors.indigoAccent,
                            title: "رابط الخادم المعتمد:",
                            subtitle: _serverUrl,
                            actionText: "تغيير",
                            actionColor: Colors.indigo.shade800,
                            onAction: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ServerConfigScreen(apiService: widget.apiService),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),

                          // 7. فك الاقتران
                          _buildActionTile(
                            icon: Icons.link_off_rounded,
                            iconColor: Colors.orangeAccent,
                            title: "فك اقتران الشاشة:",
                            subtitle: "فصل الشاشة من السيرفر وإعادة ضبطها",
                            actionText: "فك الارتباط",
                            actionColor: Colors.orange.shade900,
                            onAction: _unpair,
                          ),
                          const SizedBox(height: 8),

                          // 8. إغلاق التطبيق
                          _buildActionTile(
                            icon: Icons.power_settings_new_rounded,
                            iconColor: Colors.redAccent,
                            title: "إغلاق المشغل:",
                            subtitle: "الخروج التام من التطبيق",
                            actionText: "إغلاق",
                            actionColor: Colors.red.shade900,
                            onAction: _exitApplication,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.cairo(color: Colors.white54, fontSize: 11)),
          const SizedBox(width: 8),
          Flexible(
            child: SelectableText(
              value,
              textAlign: TextAlign.left,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String actionText,
    required Color actionColor,
    required VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF070B18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(color: Colors.white54, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: actionColor,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onAction,
              child: Text(
                actionText,
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
