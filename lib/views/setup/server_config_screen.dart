import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../common/app_error_dialog.dart';
import 'pairing_screen.dart';

class ServerConfigScreen extends StatefulWidget {
  final ApiService apiService;

  const ServerConfigScreen({super.key, required this.apiService});

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isTesting = false;
  String? _testMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUrl();
  }

  Future<void> _loadCurrentUrl() async {
    final current = await widget.apiService.getBaseUrl();
    _urlController.text = current;
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testMessage = null;
    });

    final success = await widget.apiService.testConnection(url);

    setState(() {
      _isTesting = false;
      _isSuccess = success;
      _testMessage = success
          ? "تم الاتصال بالخادم بنجاح! جاهز للاقتران."
          : "فشل الاتصال: يرجى التحقق من الرابط والشبكة.";
    });

    if (!success && mounted) {
      AppErrorDialog.show(
        context,
        title: "تعذر الاتصال بالخادم",
        message:
            "لم يتمكن التطبيق من الوصول إلى العنوان:\n$url\nيرجى التأكد من تشغيل السيرفر ومن وجود الجهاز على نفس الشبكة المحلية أو التحقق من المنفذ.",
        error:
            "Target URL: $url\nConnection test returned false (Unreachable host or timeout)",
        onRetry: _testConnection,
      );
    }
  }

  Future<void> _saveAndProceed() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    await widget.apiService.setBaseUrl(url);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => PairingScreen(apiService: widget.apiService)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
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
              const Icon(Icons.cloud_sync_rounded,
                  color: Colors.indigoAccent, size: 64),
              const SizedBox(height: 16),
              Text(
                "إعداد رابط خادم المنظومة",
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                "أدخل عنوان الـ IP أو الدومين الخاص بخادم Digital Signage OS",
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 13, color: Colors.white60),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _urlController,
                textDirection: TextDirection.ltr,
                style: GoogleFonts.cairo(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Server Base URL",
                  labelStyle: GoogleFonts.cairo(color: Colors.white60),
                  hintText: ApiService.defaultUrl,
                  hintStyle: GoogleFonts.cairo(color: Colors.white24),
                  prefixIcon:
                      const Icon(Icons.link, color: Colors.indigoAccent),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    _urlController.text = ApiService.defaultUrl;
                  },
                  icon: const Icon(Icons.restore_rounded,
                      size: 16, color: Colors.indigoAccent),
                  label: Text(
                    "استعادة الرابط الافتراضي للمنظومة (${ApiService.defaultUrl})",
                    style: GoogleFonts.cairo(
                        color: Colors.indigoAccent, fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_testMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _isSuccess
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _isSuccess ? Colors.green : Colors.red),
                  ),
                  child: Row(
                    children: [
                      Icon(_isSuccess ? Icons.check_circle : Icons.error,
                          color: _isSuccess ? Colors.green : Colors.red,
                          size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _testMessage!,
                          style: GoogleFonts.cairo(
                              color: _isSuccess
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.indigoAccent),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isTesting ? null : _testConnection,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.indigoAccent))
                          : const Icon(Icons.network_ping,
                              color: Colors.indigoAccent),
                      label: Text("اختبار الاتصال",
                          style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _saveAndProceed,
                      icon:
                          const Icon(Icons.arrow_forward, color: Colors.white),
                      label: Text("حفظ ومتابعة",
                          style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              if (Navigator.canPop(context)) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        size: 16, color: Colors.white54),
                    label: Text("إلغاء والعودة",
                        style: GoogleFonts.cairo(
                            color: Colors.white54, fontSize: 12)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
