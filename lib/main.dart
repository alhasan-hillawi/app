import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'services/api_service.dart';
import 'services/volume_service.dart';
import 'views/common/app_error_dialog.dart';
import 'views/setup/pairing_screen.dart';
import 'views/player/signage_player_screen.dart';
import 'views/splash/splash_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة بيانات اللغات والتاريخ لمكتبة intl
  try {
    await initializeDateFormatting('ar_SA', null);
  } catch (_) {}

  // تهيئة خدمة الصوت واستعادة الإعدادات المحفوظة
  try {
    await VolumeService().init();
  } catch (_) {}

  // تهيئة منصة WebView لضمان عملها بسلاسة على كافة المنصات وتفادي استثناءات المنصة
  if (!kIsWeb) {
    try {
      if (WebViewPlatform.instance == null) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          AndroidWebViewPlatform.registerWith();
        } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
          WebKitWebViewPlatform.registerWith();
        }
      }
    } catch (e) {
      debugPrint('[Main] WebView platform registration note: $e');
    }
  }

  // تعطيل جلب الخطوط من الإنترنت والاعتماد على الخطوط المرفقة محلياً
  GoogleFonts.config.allowRuntimeFetching = false;

  // اصطياد الأخطاء غير المعالجة وعرضها في Alert Dialog للمستخدم
  FlutterError.onError = (details) {
    FlutterError.presentError(details);

    final errString = details.exception.toString();
    // تجاهل استثناءات الصور التي تتكفل بها الودجت الفرعية عبر errorWidget
    if (errString.contains('ImageCodecException') ||
        errString.contains('NetworkImageLoadException') ||
        errString.contains('Failed to load network image')) {
      return;
    }

    AppErrorDialog.showGlobal(
      rootNavigatorKey,
      title: "خطأ برمجي في الواجهة",
      message: details.exceptionAsString(),
      error: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    final errString = error.toString();
    if (errString.contains('ImageCodecException') ||
        errString.contains('NetworkImageLoadException') ||
        errString.contains('Failed to load network image')) {
      return true;
    }

    AppErrorDialog.showGlobal(
      rootNavigatorKey,
      title: "خطأ غير متوقع في النظام",
      message: error.toString(),
      error: stack,
    );
    return true;
  };

  // منع سكون الشاشة وإبقاؤها مضاءة 24/7 لشاشات العرض التجارية
  try {
    await WakelockPlus.enable();
  } catch (_) {}

  // تشغيل ملء الشاشة وإخفاء أشرطة النظام
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final apiService = ApiService();
  await apiService.getBaseUrl();
  final hasToken = await apiService.hasToken();

  Widget initialScreen;
  if (!hasToken) {
    initialScreen = PairingScreen(apiService: apiService);
  } else {
    initialScreen = SignagePlayerScreen(apiService: apiService);
  }

  runApp(DigitalSignageApp(
    apiService: apiService,
    initialScreen: initialScreen,
  ));
}

class DigitalSignageApp extends StatelessWidget {
  final ApiService apiService;
  final Widget initialScreen;

  const DigitalSignageApp({super.key, required this.apiService, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Digital Signage OS Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Cairo',
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.indigoAccent,
          surface: Color(0xFF1E293B),
        ),
      ),
      home: SplashScreen(
        apiService: apiService,
        nextScreen: initialScreen,
      ),
    );
  }
}
