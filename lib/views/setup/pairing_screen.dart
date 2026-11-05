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
  final DeviceInfoService _deviceInfo = DeviceInfoService();
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic> _specs = {};

  @override
  void initState() {
    super.initState();
    _fetchSpecs();
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
      String errorMsg = "فشل الاقتران بالرمز ($code): تأكد من صحة الرمز ومن أن الشاشة مخصصة في النظام.";
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
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          Center(
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.tv_rounded, color: Colors.indigoAccent, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    "اقتران شاشة العرض",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "أدخل رمز الاقتران بالحروف الكبيرة (مثال: SC-BDXV)",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(fontSize: 13, color: Colors.white60),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      UpperCaseTextFormatter(),
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                    ],
                    textAlign: TextAlign.center,
                    maxLength: 10,
                    style: GoogleFonts.cairo(
                      fontSize: 30,
                      letterSpacing: 6,
                      fontWeight: FontWeight.bold,
                      color: Colors.amberAccent,
                    ),
                    decoration: InputDecoration(
                      hintText: "SC-BDXV",
                      hintStyle: GoogleFonts.cairo(fontSize: 26, letterSpacing: 4, color: Colors.white24),
                      counterText: "",
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(color: Colors.redAccent, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigoAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isLoading ? null : _submitPairing,
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            "تأكيد الاقتران وبدء البث",
                            style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ServerConfigScreen(apiService: widget.apiService)));
              },
              icon: const Icon(Icons.settings, color: Colors.white38, size: 18),
              label: Text("تغيير رابط الخادم", style: GoogleFonts.cairo(color: Colors.white38, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
