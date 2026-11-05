import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';

enum DeviceSyncStatus {
  onlineSynced,
  syncing,
  laggingNeedsSync,
  offlineNoNetwork,
  serverUnreachable,
}

/// خدمة القياس عن بُعد والمزامنة الحية مع النظام المركزي
/// تقوم بفحص الاتصال بالإنترنت وإرسال نبضة المزامنة كل 5 ثوانٍ
class TelemetryHeartbeatService {
  final ApiService apiService;
  final ValueNotifier<DeviceSyncStatus> statusNotifier = ValueNotifier(DeviceSyncStatus.onlineSynced);
  final ValueNotifier<int> localRevisionNotifier = ValueNotifier(0);
  final ValueNotifier<int> serverRevisionNotifier = ValueNotifier(0);

  // تم تقليل دورة المزامنة إلى 5 ثوانٍ لتحديث فوري لحظي للشاشات
  static const Duration defaultHeartbeatInterval = Duration(seconds: 5);

  Timer? _heartbeatTimer;
  StreamSubscription? _connectivitySubscription;
  bool _isProcessing = false;
  final Function(Map<String, dynamic> newConfig) onSyncRequired;
  final VoidCallback? onUnpaired;

  TelemetryHeartbeatService({
    required this.apiService,
    required this.onSyncRequired,
    this.onUnpaired,
    int initialRevision = 0,
  }) {
    localRevisionNotifier.value = initialRevision;
  }

  /// بدء تشغيل مؤقت المزامنة كل 5 ثوانٍ مع مراقبة حية لشبكة الجهاز
  void start() {
    stop();

    // 1. فحص الاتصال وإرسال نبضة مزامنة فورية عند بدء التشغيل
    _sendPulse();

    // 2. جدولة النبضة الدورية كل 5 ثوانٍ
    _heartbeatTimer = Timer.periodic(defaultHeartbeatInterval, (_) => _sendPulse());

    // 3. مراقبة حالة الشبكة: عند انقطاع الاتصال يطلب الاتصال فوراً، وعند عودته يعيد فحص المزامنة فوراً
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final bool hasNoNetwork = results.contains(ConnectivityResult.none) || results.isEmpty;
      if (hasNoNetwork) {
        debugPrint('[Telemetry] Network disconnected. Requiring internet connection.');
        statusNotifier.value = DeviceSyncStatus.offlineNoNetwork;
      } else {
        debugPrint('[Telemetry] Network connected. Immediately re-checking sync with system.');
        _sendPulse();
      }
    });
  }

  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// إرسال نبضة التحقق والمزامنة مع فحص توفر الإنترنت
  Future<void> _sendPulse() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // فحص توفر اتصال بالشبكة أولاً
      final connectivityResults = await Connectivity().checkConnectivity();
      final bool hasNoNetwork = connectivityResults.contains(ConnectivityResult.none) || connectivityResults.isEmpty;
      if (hasNoNetwork) {
        statusNotifier.value = DeviceSyncStatus.offlineNoNetwork;
        return;
      }

      final res = await apiService.sendHeartbeat(
        localRevisionNotifier.value,
        "1.0.0+1",
      );

      if (res.statusCode == 200 && res.data['success'] == true) {
        final data = res.data['data'];
        final int serverRev = data['server_revision'] ?? 0;
        final bool needsSync = data['needs_sync'] ?? false;

        serverRevisionNotifier.value = serverRev;

        if (needsSync || serverRev > localRevisionNotifier.value) {
          statusNotifier.value = DeviceSyncStatus.syncing;
          await _performFullSync(serverRev);
        } else {
          statusNotifier.value = DeviceSyncStatus.onlineSynced;
        }
      } else {
        if (res.statusCode == 401 || res.statusCode == 404) {
          onUnpaired?.call();
        }
        statusNotifier.value = DeviceSyncStatus.serverUnreachable;
      }
    } catch (e) {
      if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 404)) {
        onUnpaired?.call();
      }
      statusNotifier.value = DeviceSyncStatus.serverUnreachable;
    } finally {
      _isProcessing = false;
    }
  }

  /// جلب الحمولة الكاملة للشاشة عند وجود مراجعة أحدث
  Future<void> _performFullSync(int targetServerRev) async {
    try {
      final res = await apiService.fetchSyncPayload(localRevisionNotifier.value);
      if (res.statusCode == 200 && res.data['success'] == true) {
        final config = res.data['data']['configuration'];
        final int confirmedRev = res.data['data']['revision'] ?? targetServerRev;

        if (config != null) {
          // إشعار واجهة العرض بالحمولة والتحديثات الجديدة
          onSyncRequired(Map<String, dynamic>.from(config as Map));
        }

        // اعتماد رقم المراجعة المحلي الجديد
        localRevisionNotifier.value = confirmedRev;
        statusNotifier.value = DeviceSyncStatus.onlineSynced;
      } else if (res.statusCode == 401 || res.statusCode == 404) {
        onUnpaired?.call();
      }
    } catch (e) {
      if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 404)) {
        onUnpaired?.call();
      }
      statusNotifier.value = DeviceSyncStatus.laggingNeedsSync;
    }
  }

  /// طلب فحص فوري للمزامنة مع النظام
  Future<void> triggerManualSync() async {
    await _sendPulse();
  }
}
