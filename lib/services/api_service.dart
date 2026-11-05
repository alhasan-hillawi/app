import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String defaultUrl = "https://digitalsignature.sohob.dev";
  static String activeBaseUrl = defaultUrl;
  static const String _urlKey = "server_base_url";
  static const String _tokenKey = "device_sanctum_token";

  late Dio dio;
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage(
    mOptions: MacOsOptions(useDataProtectionKeyChain: false),
  );

  ApiService() {
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // إضافة Interceptor لتمرير التوكن وتحديث الـ Base URL تلقائياً في كل استدعاء
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final baseUrl = await getBaseUrl();
          options.baseUrl = "$baseUrl/api/v1";

          final token = await readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          return handler.next(e);
        },
      ),
    );
  }

  /// جلب رابط السيرفر الأساسي المخزن مع الترقية التلقائية إلى الرابط الرسمي
  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_urlKey) ?? defaultUrl;
    // ترقية الروابط المحلية السابقة تلقائياً إلى الرابط السحابي الرسمي الافتراضي
    if (url == "http://127.0.0.1:8000" || url == "http://localhost:8000" || url == "http://127.0.0.1:8001") {
      activeBaseUrl = defaultUrl;
      await prefs.setString(_urlKey, defaultUrl);
      return defaultUrl;
    }
    activeBaseUrl = url;
    return url;
  }

  /// استعادة رابط السيرفر الافتراضي للمنظومة
  Future<void> resetBaseUrlToDefault() async {
    await setBaseUrl(defaultUrl);
  }

  /// تصحيح وتوحيد روابط الوسائط (فيديوهات أو صور) لربطها بالسيرفر الفعال تلقائياً
  static String normalizeMediaUrl(String rawUrl, [String? baseUrl]) {
    if (rawUrl.isEmpty) return rawUrl;
    final targetBase = (baseUrl != null && baseUrl.isNotEmpty) ? baseUrl : activeBaseUrl;
    final cleanBase = targetBase.trim().replaceAll(RegExp(r'/+$'), '');

    // 1. إذا كان المسار نسبياً مثل /media/stream/43 أو /storage/...
    if (rawUrl.startsWith('/')) {
      return "$cleanBase$rawUrl";
    }

    // 2. إذا كان الرابط كاملاً لكن يحمل رابط هوست/منفذ مختلف (مثل 8001 بدلاً من 8000 أو localhost بدلاً من IP)
    try {
      final uri = Uri.parse(rawUrl);
      final baseUri = Uri.parse(cleanBase);

      final isLocal = (uri.host == 'localhost' || uri.host == '127.0.0.1') &&
                      (baseUri.host == 'localhost' || baseUri.host == '127.0.0.1');
      final isMediaEndpoint = uri.path.startsWith('/media/') || uri.path.startsWith('/storage/');

      if (isMediaEndpoint || isLocal) {
        return uri.replace(
          scheme: baseUri.scheme,
          host: baseUri.host,
          port: baseUri.hasPort ? baseUri.port : null,
        ).toString();
      }
    } catch (_) {}

    return rawUrl;
  }

  /// التحقق هل تم إدخال رابط سيرفر مسبقاً
  Future<bool> hasConfiguredBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_urlKey);
  }

  /// حفظ رابط السيرفر الأساسي بعد تنظيفه من الفواصل الزائدة
  Future<void> setBaseUrl(String newUrl) async {
    final cleanUrl = newUrl.trim().replaceAll(RegExp(r'/+$'), '');
    activeBaseUrl = cleanUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, cleanUrl);
  }

  /// اختبار الاتصال بالسيرفر
  Future<bool> testConnection(String targetUrl) async {
    try {
      final cleanUrl = targetUrl.trim().replaceAll(RegExp(r'/+$'), '');
      final testDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      // فحص Endpoint عام
      final res = await testDio.post("$cleanUrl/api/v1/device/pair", data: {});
      return res.statusCode != null && res.statusCode! < 500;
    } catch (e) {
      if (e is DioException && e.response != null) {
        // استجابة 422 Unprocessable أو 400 تثبت أن السيرفر يعمل ويستقبل الطلبات
        return true;
      }
      return false;
    }
  }

  // إدارة توكن Sanctum مع حماية fallback في حال عدم توفر Keychain في بيئة التطوير
  Future<void> saveToken(String token) async {
    try {
      await secureStorage.write(key: _tokenKey, value: token);
    } catch (_) {
      // بديل تلقائي لبيئة macOS Sandbox عند غياب Keychain entitlement
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    }
  }

  Future<String?> readToken() async {
    try {
      final token = await secureStorage.read(key: _tokenKey);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> clearToken() async {
    try {
      await secureStorage.delete(key: _tokenKey);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<bool> hasToken() async {
    final token = await readToken();
    return token != null && token.isNotEmpty;
  }

  // 1. اقتران الجهاز
  Future<Response> pairDevice(Map<String, dynamic> data) async => await dio.post('/device/pair', data: data);

  // 2. إرسال نبضة الجهاز الدورية
  Future<Response> sendHeartbeat(int revision, String appVersion) async =>
      await dio.post('/device/heartbeat', data: {'current_revision': revision, 'app_version': appVersion});

  // 3. جلب حمولة المزامنة الكاملة
  Future<Response> fetchSyncPayload(int revision) async =>
      await dio.get('/device/sync', queryParameters: {'revision': revision});

  // 4. استعلام عن بيانات الجهاز المقترن
  Future<Response> fetchDeviceInfo() async => await dio.get('/device/me');

  // 5. فك اقتران الجهاز
  Future<Response> unpairDevice() async => await dio.post('/device/unpair');
}
