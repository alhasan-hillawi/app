import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة أمان رمز الـ PIN لقفل الشاشة وحماية إعدادات التطبيق من التلاعب
class PinSecurityService {
  static final PinSecurityService _instance = PinSecurityService._internal();
  factory PinSecurityService() => _instance;
  PinSecurityService._internal();

  static const String _pinKey = "device_admin_security_pin";
  static const String defaultPin = "0000";

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    mOptions: MacOsOptions(useDataProtectionKeyChain: false),
  );

  /// حفظ رمز الـ PIN في التخزين الآمن
  Future<void> savePin(String pin) async {
    final cleanPin = pin.trim();
    if (cleanPin.length != 4) return;

    try {
      await _secureStorage.write(key: _pinKey, value: cleanPin);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pinKey, cleanPin);
    } catch (_) {}
  }

  /// قراءة رمز الـ PIN الحالي
  Future<String> getPin() async {
    try {
      final securePin = await _secureStorage.read(key: _pinKey);
      if (securePin != null && securePin.trim().length == 4) {
        return securePin.trim();
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final prefPin = prefs.getString(_pinKey);
      if (prefPin != null && prefPin.trim().length == 4) {
        return prefPin.trim();
      }
    } catch (_) {}

    return defaultPin;
  }

  /// التحقق من صحة رمز الـ PIN المدخل
  Future<bool> verifyPin(String inputPin) async {
    final cleanInput = inputPin.trim();
    final savedPin = await getPin();
    return cleanInput == savedPin;
  }

  /// تغيير رمز الـ PIN
  Future<bool> changePin(String oldPin, String newPin) async {
    final isCorrect = await verifyPin(oldPin);
    if (!isCorrect) return false;

    if (newPin.trim().length != 4) return false;

    await savePin(newPin.trim());
    return true;
  }
}
