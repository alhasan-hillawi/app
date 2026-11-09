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

  const DeviceSettingsDialog(
      {super.key, required this.apiService, required this.onUnpaired});

  static Future<void> show(
      BuildContext context, ApiService api, VoidCallback onUnpaired) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          DeviceSettingsDialog(apiService: api, onUnpaired: onUnpaired),
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

  // 1. تبديل وضع الشاشة (أفقي / عمودي)
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

  // 2. تنظيف الكاش
  Future<void> _cleanCache() async {
    setState(() => _isCleaning = true);
    final freedMb = await _cacheService.clearAllCache();
    setState(() => _isCleaning = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "تم تنظيف ذاكرة التخزين المؤقت وتحرير $freedMb MB بنجاح!",
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  // 3. فك الاقتران
  Future<void> _unpair() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text("تأكيد فك الاقتران",
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold, color: Colors.white)),
        content: Text(
            "هل أنت متأكد من فك اقتران هذا الجهاز؟ سيتوقف البث فوراً وسيتطلب إدخال رمز جديد.",
            style: GoogleFonts.cairo(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text("إلغاء",
                  style: GoogleFonts.cairo(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("فك الاقتران الآن",
                style: GoogleFonts.cairo(
                    color: Colors.white, fontWeight: FontWeight.bold)),
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

  // 4. الخروج من التطبيق
  void _exitApplication() {
    SystemNavigator.pop();
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFF1E293B),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 650,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.indigoAccent))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.settings_suggest,
                                color: Colors.indigoAccent, size: 28),
                            const SizedBox(width: 12),
                            Text("إعدادات الجهاز ومنظومة العرض",
                                style: GoogleFonts.cairo(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ],
                        ),
                        IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon:
                                const Icon(Icons.close, color: Colors.white70)),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 28),

                    // مواصفات الجهاز الكاملة
                    Text("بيانات الجهاز والعتاد (Hardware Info):",
                        style: GoogleFonts.cairo(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          _buildRow("معرف الجهاز (UUID):",
                              _deviceSpecs['uuid'] ?? '—'),
                          _buildRow("الطراز والمصنع:",
                              "${_deviceSpecs['brand'] ?? ''} ${_deviceSpecs['model'] ?? 'جهاز عام'}"),
                          _buildRow(
                              "نظام التشغيل:", _deviceSpecs['os'] ?? 'Android'),
                          _buildRow("عنوان الشبكة (IP):",
                              _deviceSpecs['ip'] ?? '127.0.0.1'),
                          _buildRow("التخزين الحر:",
                              _deviceSpecs['disk_free'] ?? 'غير محدد'),
                          _buildRow("إصدار مشغل فلاتر:",
                              _deviceSpecs['app_version'] ?? '1.0.0'),
                          _buildRow("رابط الخادم المعتمد:", _serverUrl),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // الأزرار والإجراءات
                    Text("الإجراءات والتحكم بالعتاد:",
                        style: GoogleFonts.cairo(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    // 1. التحكم بمستوى الصوت وكتم الصوت
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
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
                                        : (_volume < 0.5
                                            ? Icons.volume_down_rounded
                                            : Icons.volume_up_rounded),
                                    color: _isMuted || _volume == 0
                                        ? Colors.redAccent
                                        : Colors.tealAccent,
                                    size: 26,
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "مستوى الصوت: ${_isMuted ? 'مكتوم (Muted)' : '${(_volume * 100).toInt()}%'}",
                                        style: GoogleFonts.cairo(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        _isMuted
                                            ? "الصوت مغلق بالكامل على كافة الشاشات"
                                            : "التحكم بمستوى صوت الفيديوهات والبث",
                                        style: GoogleFonts.cairo(
                                            color: Colors.white54,
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isMuted
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => VolumeService().toggleMute(),
                                icon: Icon(
                                    _isMuted
                                        ? Icons.volume_up_rounded
                                        : Icons.volume_off_rounded,
                                    size: 16,
                                    color: Colors.white),
                                label: Text(
                                  _isMuted ? "إلغاء الكتم" : "كتم الصوت",
                                  style: GoogleFonts.cairo(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => VolumeService().setVolume(0.0),
                                icon: const Icon(Icons.volume_mute_rounded,
                                    color: Colors.white54, size: 20),
                                tooltip: "كتم (0%)",
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: Colors.indigoAccent,
                                    inactiveTrackColor: Colors.white12,
                                    thumbColor: Colors.white,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 7),
                                    overlayColor: Colors.indigoAccent
                                        .withValues(alpha: 0.2),
                                    trackHeight: 4,
                                  ),
                                  child: Slider(
                                    value: _volume,
                                    min: 0.0,
                                    max: 1.0,
                                    divisions: 20,
                                    onChanged: (val) =>
                                        VolumeService().setVolume(val),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => VolumeService().setVolume(1.0),
                                icon: const Icon(Icons.volume_up_rounded,
                                    color: Colors.white54, size: 20),
                                tooltip: "أقصى صوت (100%)",
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // أ. نمط توسيع وتقليص الفيديو على حجم الشاشة
                    ValueListenableBuilder<VideoFitMode>(
                      valueListenable: VideoFitService().fitModeNotifier,
                      builder: (context, mode, _) {
                        return ListTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          tileColor: const Color(0xFF0F172A),
                          leading: Icon(VideoFitService().currentModeIcon,
                              color: const Color(0xFF00E5FF)),
                          title: Text("ملاءمة وتوسيع الفيديو على الشاشة:",
                              style: GoogleFonts.cairo(
                                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text(VideoFitService().currentModeTitleAr,
                              style: GoogleFonts.cairo(
                                  color: const Color(0xFF00E5FF), fontSize: 11)),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F2847),
                                side: const BorderSide(color: Color(0xFF00E5FF))),
                            onPressed: () => VideoFitService().cycleNextMode(),
                            icon: const Icon(Icons.sync, size: 16, color: Color(0xFF00E5FF)),
                            label: Text("تبديل النمط",
                                style: GoogleFonts.cairo(
                                    color: Colors.white, fontSize: 12)),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // ب. تدوير الشاشة
                    ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      tileColor: const Color(0xFF0F172A),
                      leading: Icon(
                          _isLandscape
                              ? Icons.screen_lock_landscape
                              : Icons.screen_lock_portrait,
                          color: Colors.amber),
                      title: Text(
                          "وضع الشاشة: ${_isLandscape ? 'أفقي (Landscape)' : 'عمودي (Portrait)'}",
                          style: GoogleFonts.cairo(
                              color: Colors.white, fontSize: 13)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade800),
                        onPressed: _toggleOrientation,
                        child: Text("تبديل الاتجاه",
                            style: GoogleFonts.cairo(
                                color: Colors.white, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ب. تنظيف الكاش
                    ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      tileColor: const Color(0xFF0F172A),
                      leading: const Icon(Icons.cleaning_services,
                          color: Colors.cyanAccent),
                      title: Text("تنظيف الذاكرة المؤقتة (Clear Cache)",
                          style: GoogleFonts.cairo(
                              color: Colors.white, fontSize: 13)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan.shade800),
                        onPressed: _isCleaning ? null : _cleanCache,
                        child: Text("تنظيف الآن",
                            style: GoogleFonts.cairo(
                                color: Colors.white, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ج. تعديل رابط الخادم
                    ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      tileColor: const Color(0xFF0F172A),
                      leading: const Icon(Icons.cloud_sync_rounded,
                          color: Colors.indigoAccent),
                      title: Text("تعديل رابط الخادم (Server URL)",
                          style: GoogleFonts.cairo(
                              color: Colors.white, fontSize: 13)),
                      subtitle: Text(_serverUrl,
                          style: GoogleFonts.cairo(
                              color: Colors.white38, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigoAccent),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ServerConfigScreen(
                                    apiService: widget.apiService)),
                          );
                        },
                        child: Text("تغيير الرابط",
                            style: GoogleFonts.cairo(
                                color: Colors.white, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // د. فك الاقتران
                    ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      tileColor: const Color(0xFF0F172A),
                      leading: const Icon(Icons.link_off,
                          color: Colors.orangeAccent),
                      title: Text("فك الاقتران بالسيرفر (Unpair)",
                          style: GoogleFonts.cairo(
                              color: Colors.white, fontSize: 13)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade800),
                        onPressed: _unpair,
                        child: Text("فك الارتباط",
                            style: GoogleFonts.cairo(
                                color: Colors.white, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // هـ. الخروج من التطبيق
                    ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      tileColor: const Color(0xFF0F172A),
                      leading: const Icon(Icons.power_settings_new,
                          color: Colors.redAccent),
                      title: Text("الخروج من المشغل (Exit Kiosk)",
                          style: GoogleFonts.cairo(
                              color: Colors.white, fontSize: 13)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade800),
                        onPressed: _exitApplication,
                        child: Text("إغلاق التطبيق",
                            style: GoogleFonts.cairo(
                                color: Colors.white, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.cairo(color: Colors.white60, fontSize: 12)),
          SelectableText(value,
              style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
