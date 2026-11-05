import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';

class AppErrorDialog extends StatefulWidget {
  final String title;
  final String message;
  final dynamic error;
  final VoidCallback? onRetry;

  const AppErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.error,
    this.onRetry,
  });

  static bool _isShowing = false;

  /// إظهار نافذة الخطأ في أي مكان في التطبيق
  static Future<void> show(
    BuildContext context, {
    String title = "تنبيه: حدث خطأ",
    required String message,
    dynamic error,
    VoidCallback? onRetry,
  }) async {
    _isShowing = true;
    try {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => AppErrorDialog(
          title: title,
          message: message,
          error: error,
          onRetry: onRetry,
        ),
      );
    } finally {
      _isShowing = false;
    }
  }

  /// إظهار الخطأ باستخدام GlobalKey للـ Navigator في الحالات العامة
  static void showGlobal(
    GlobalKey<NavigatorState> navigatorKey, {
    String title = "تنبيه: حدث خطأ",
    required String message,
    dynamic error,
    VoidCallback? onRetry,
  }) {
    if (_isShowing) return;
    final context = navigatorKey.currentContext;
    if (context != null) {
      show(context, title: title, message: message, error: error, onRetry: onRetry);
    }
  }

  @override
  State<AppErrorDialog> createState() => _AppErrorDialogState();
}

class _AppErrorDialogState extends State<AppErrorDialog> {
  bool _showDetails = false;

  String _formatErrorDetails() {
    if (widget.error == null) return "لا توجد تفاصيل فنية إضافية.";

    final err = widget.error;
    if (err is DioException) {
      final buffer = StringBuffer();
      buffer.writeln("DioException Type: ${err.type}");
      buffer.writeln("URL: ${err.requestOptions.uri}");
      buffer.writeln("Method: ${err.requestOptions.method}");
      buffer.writeln("Status Code: ${err.response?.statusCode ?? 'No Response'}");
      if (err.message != null) buffer.writeln("Message: ${err.message}");
      if (err.response?.data != null) buffer.writeln("Response Data: ${err.response?.data}");
      return buffer.toString();
    }

    return err.toString();
  }

  void _copyToClipboard() {
    final text = "${widget.title}\n${widget.message}\n\nالتفاصيل الفنية:\n${_formatErrorDetails()}";
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("تم نسخ تفاصيل الخطأ للحافظة", style: GoogleFonts.cairo()),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = _formatErrorDetails();

    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // نص الرسالة
              Text(
                widget.message,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),

              // زر إظهار/إخفاء التفاصيل الفنية
              InkWell(
                onTap: () => setState(() => _showDetails = !_showDetails),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _showDetails ? "إخفاء التفاصيل الفنية" : "عرض التفاصيل الفنية للخطأ",
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.indigoAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        _showDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.indigoAccent,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              // صندوق التفاصيل الفنية
              if (_showDetails) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SelectableText(
                        details,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.amberAccent,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onPressed: _copyToClipboard,
                          icon: const Icon(Icons.copy, size: 14, color: Colors.white70),
                          label: Text("نسخ التفاصيل", style: GoogleFonts.cairo(fontSize: 11, color: Colors.white70)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            "إغلاق",
            style: GoogleFonts.cairo(color: Colors.white60),
          ),
        ),
        if (widget.onRetry != null)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              widget.onRetry!();
            },
            icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
            label: Text(
              "إعادة المحاولة",
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}
