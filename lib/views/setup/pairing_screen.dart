import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../services/device_info_service.dart';
import '../player/signage_player_screen.dart';
import '../common/app_error_dialog.dart';
import 'server_config_screen.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class PairingScreen extends StatefulWidget {
  final ApiService apiService;

  const PairingScreen({super.key, required this.apiService});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final DeviceInfoService _deviceInfo = DeviceInfoService();
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic> _specs = {};

  @override
  void initState() {
    super.initState();
    _fetchSpecs();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchSpecs() async {
    final specs = await _deviceInfo.getFullDeviceSpecs();
    if (mounted) setState(() => _specs = specs);
  }

  Future<void> _submitPairing() async {
    String code = _codeController.text.trim().toUpperCase();

    // دعم إدخال الرمز مباشرة أو مع بادئة SC- تلقائياً
    if (!code.startsWith('SC-') && code.length == 4) {
      code = 'SC-$code';
    }

    if (code.isEmpty || code.length < 4) {
      setState(() => _errorMessage = "يرجى إدخال رمز اقتران صحيح بتنسيق SC-XXXX (مثل: SC-BDXV)");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final payload = {
        'pairing_code': code,
        'device_uuid': _specs['uuid'] ?? 'generic-device',
        'device_name': "${_specs['brand'] ?? 'Player'} - ${_specs['model'] ?? 'Display'}",
        'model': _specs['model'] ?? 'Unknown',
        'os_info': _specs['os'] ?? 'Android',
        'app_version': _specs['app_version'] ?? '1.0.0+1',
      };

      final response = await widget.apiService.pairDevice(payload);
      final data = response.data['data'];
      final token = data['token'];

      // حفظ التوكن
      await widget.apiService.saveToken(token);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SignagePlayerScreen(apiService: widget.apiService)),
        );
      }
    } catch (e) {
      String errorMsg = "فشل الاقتران بالرمز ($code): تأكد من صحة الرمز ومن أن الشاشة مضافة في لوحة التحكم.";
      if (e is DioException) {
        if (e.response?.data != null && e.response?.data is Map) {
          final serverMsg = e.response?.data['message'];
          if (serverMsg != null) errorMsg = serverMsg.toString();
        } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
          errorMsg = "انتهت مهلة الاتصال بالخادم. يرجى التحقق من استقرار اتصال الشبكة.";
        } else if (e.type == DioExceptionType.connectionError) {
          errorMsg = "تعذر الاتصال بعنوان الخادم. يرجى التأكد من تشغيل السيرفر وصحة عنوان الـ IP والمنفذ.";
        }
      }

      setState(() {
        _isLoading = false;
        _errorMessage = errorMsg;
      });

      if (mounted) {
        AppErrorDialog.show(
          context,
          title: "خطأ في اقتران الشاشة",
          message: errorMsg,
          error: e,
          onRetry: _submitPairing,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          final shortestSide = math.min(screenWidth, screenHeight);
          final isPortrait = screenHeight > screenWidth;

          // مقاييس ديناميكية متناسقة مع جميع أحجام الشاشات
          final logoSize = (shortestSide * (isPortrait ? 0.28 : 0.20)).clamp(95.0, 170.0);
          final titleFontSize = (shortestSide * (isPortrait ? 0.080 : 0.060)).clamp(30.0, 48.0);
          final subtitleFontSize = (shortestSide * (isPortrait ? 0.034 : 0.026)).clamp(13.0, 19.0);
          final websiteFontSize = (shortestSide * (isPortrait ? 0.030 : 0.022)).clamp(12.0, 17.0);
          final inputFontSize = (shortestSide * (isPortrait ? 0.065 : 0.045)).clamp(22.0, 36.0);
          final cardWidth = (screenWidth * (isPortrait ? 0.90 : 0.55)).clamp(320.0, 580.0);
          final verticalPadding = (screenHeight * 0.02).clamp(12.0, 36.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. خلفية متدرجة سينمائية داكنة مطابقة لهوية النظام
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.0, -0.2),
                    radius: 1.2,
                    colors: [
                      Color(0xFF0F1B38),
                      Color(0xFF090E22),
                      Color(0xFF050711),
                    ],
                    stops: [0.0, 0.60, 1.0],
                  ),
                ),
              ),

              // 2. هالة ضوئية ناعمة في الخلفية لتعزيز جمالية النيون
              Center(
                child: Container(
                  width: cardWidth * 0.9,
                  height: cardWidth * 0.9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF00E5FF).withValues(alpha: 0.12),
                        const Color(0xFF7C3AED).withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.50, 1.0],
                    ),
                  ),
                ),
              ),

              // 3. المحتوى الرئيسي القابل للتمرير لتفادي التداخل عند ظهور لوحة المفاتيح
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: verticalPadding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // بطاقة الاقتران الزجاجية الفاخرة (Glassmorphic Card)
                        Container(
                          width: cardWidth,
                          padding: EdgeInsets.symmetric(
                            horizontal: (cardWidth * 0.07).clamp(20.0, 40.0),
                            vertical: (cardWidth * 0.06).clamp(24.0, 38.0),
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C1427).withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                                blurRadius: 35,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.60),
                                blurRadius: 25,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // أ. الشعار بدقة عالية مع ظل نيون جذاب
                              Center(
                                child: Container(
                                  width: logoSize,
                                  height: logoSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                                        blurRadius: 30,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/images/sohob_logo.png',
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // ب. كلمة "سُحبْ" بخط كايرو العريض المتوهج
                              Text(
                                "سُحبْ",
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: GoogleFonts.cairo(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                  height: 1.2,
                                  shadows: [
                                    Shadow(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.80),
                                      blurRadius: 18,
                                    ),
                                    Shadow(
                                      color: const Color(0xFF38BDF8).withValues(alpha: 0.50),
                                      blurRadius: 28,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 6),

                              // ج. عبارة "منظومة ادارة الشاشات وبث الطوارئ"
                              Text(
                                "منظومة ادارة الشاشات وبث الطوارئ",
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: GoogleFonts.cairo(
                                  fontSize: subtitleFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFCBD5E1),
                                  height: 1.3,
                                  letterSpacing: 0.5,
                                  shadows: [
                                    Shadow(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.30),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 18),

                              // خط فاصل زخرفي نيون
                              Center(
                                child: Container(
                                  width: 90,
                                  height: 2,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Color(0xFF00E5FF),
                                        Color(0xFF818CF8),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 22),

                              // د. عنوان توضيحي لحقل اقتران الشاشة
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.tv_rounded, color: Color(0xFF00E5FF), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "رمز اقتران الشاشة العرض",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.cairo(
                                      fontSize: subtitleFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              Text(
                                "أدخل رمز الاقتران الظاهر في لوحة التحكم (مثال: SC-BDXV)",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  fontSize: (subtitleFontSize * 0.85).clamp(11.0, 14.0),
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // هـ. حقل إدخال رمز الاقتران المصمم بأسلوب عصري
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF060B18),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: _errorMessage != null
                                        ? Colors.redAccent.withValues(alpha: 0.8)
                                        : const Color(0xFF00E5FF).withValues(alpha: 0.45),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_errorMessage != null ? Colors.redAccent : const Color(0xFF00E5FF))
                                          .withValues(alpha: 0.12),
                                      blurRadius: 15,
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: _codeController,
                                  focusNode: _focusNode,
                                  keyboardType: TextInputType.text,
                                  textCapitalization: TextCapitalization.characters,
                                  inputFormatters: [
                                    UpperCaseTextFormatter(),
                                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                                  ],
                                  textAlign: TextAlign.center,
                                  maxLength: 10,
                                  style: GoogleFonts.cairo(
                                    fontSize: inputFontSize,
                                    letterSpacing: 6,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF00F0FF),
                                    shadows: [
                                      Shadow(
                                        color: const Color(0xFF00F0FF).withValues(alpha: 0.65),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "SC-BDXV",
                                    hintStyle: GoogleFonts.cairo(
                                      fontSize: inputFontSize * 0.85,
                                      letterSpacing: 4,
                                      color: Colors.white24,
                                    ),
                                    counterText: "",
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                    border: InputBorder.none,
                                  ),
                                  onSubmitted: (_) => _submitPairing(),
                                ),
                              ),

                              // رسالة الخطأ في حال وجودها
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          textAlign: TextAlign.right,
                                          style: GoogleFonts.cairo(
                                            color: Colors.redAccent.shade100,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 22),

                              // و. زر تأكيد الاقتران مع تأثير النيون والتحميل
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF00E5FF),
                                      Color(0xFF4F46E5),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                                      blurRadius: 20,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: _isLoading ? null : _submitPairing,
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.link_rounded, color: Colors.white, size: 22),
                                            const SizedBox(width: 10),
                                            Text(
                                              "تأكيد الاقتران وبدء البث",
                                              style: GoogleFonts.cairo(
                                                fontSize: (subtitleFontSize * 1.05).clamp(15.0, 18.0),
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: verticalPadding * 1.2),

                        // 4. في الأسفل: شارة الموقع الرسمي www.sohob.dev
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: (shortestSide * 0.040).clamp(16.0, 28.0),
                            vertical: (shortestSide * 0.015).clamp(8.0, 12.0),
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C1427).withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.40),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.language_rounded,
                                size: websiteFontSize * 1.2,
                                color: const Color(0xFF00E5FF),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "www.sohob.dev",
                                textDirection: TextDirection.ltr,
                                style: GoogleFonts.cairo(
                                  fontSize: websiteFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFF1F5F9),
                                  letterSpacing: 1.2,
                                  shadows: [
                                    Shadow(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.60),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 5. زر إعدادات الخادم الفني (في الركن السفلي الأيمن بهدوء وأناقة)
              Positioned(
                bottom: 16,
                right: 16,
                child: SafeArea(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ServerConfigScreen(apiService: widget.apiService),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C1427).withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.settings_outlined, color: Colors.white54, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              "إعدادات الخادم",
                              style: GoogleFonts.cairo(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
