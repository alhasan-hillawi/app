import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:disk_space_plus/disk_space_plus.dart';

class DeviceInfoService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final NetworkInfo _networkInfo = NetworkInfo();

  Future<Map<String, dynamic>> getFullDeviceSpecs() async {
    String uuid = 'unknown-device';
    String brand = 'Generic';
    String model = 'Player Box';
    String os = kIsWeb ? 'Web Browser' : (Platform.operatingSystem);
    String? ip = '127.0.0.1';
    String freeDiskStr = 'غير متوفر';

    try {
      // 1. معلومات عنوان IP المحلي
      ip = await _networkInfo.getWifiIP() ?? '127.0.0.1';

      // 2. معلومات نظام التشغيل والعتاد
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        uuid = webInfo.userAgent ?? 'web-client';
        brand = webInfo.browserName.name;
        model = webInfo.platform ?? 'Web Browser';
        os = "Web (${webInfo.browserName.name})";
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        uuid = androidInfo.id.isNotEmpty ? androidInfo.id : (androidInfo.hardware + androidInfo.model);
        brand = androidInfo.brand;
        model = androidInfo.model;
        os = "Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})";
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        uuid = iosInfo.identifierForVendor ?? 'ios-unknown';
        brand = 'Apple';
        model = iosInfo.utsname.machine;
        os = "iOS ${iosInfo.systemVersion}";
      } else if (Platform.isMacOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        uuid = macInfo.systemGUID ?? 'mac-guid';
        brand = 'Apple Mac';
        model = macInfo.model;
        os = "macOS ${macInfo.osRelease}";
      } else if (Platform.isWindows) {
        final winInfo = await _deviceInfo.windowsInfo;
        uuid = winInfo.deviceId;
        brand = 'PC';
        model = winInfo.productName;
        os = "Windows ${winInfo.majorVersion}";
      } else if (Platform.isLinux) {
        final linuxInfo = await _deviceInfo.linuxInfo;
        uuid = linuxInfo.machineId ?? 'linux-machine';
        brand = 'Linux';
        model = linuxInfo.prettyName;
        os = linuxInfo.name;
      }

      // 3. مساحة التخزين الحرة
      final freeDisk = await DiskSpacePlus().getFreeDiskSpace;
      if (freeDisk != null) {
        if (freeDisk > 1024) {
          freeDiskStr = "${(freeDisk / 1024).toStringAsFixed(2)} GB";
        } else {
          freeDiskStr = "${freeDisk.toStringAsFixed(0)} MB";
        }
      }
    } catch (_) {}

    return {
      'uuid': uuid,
      'brand': brand,
      'model': model,
      'os': os,
      'ip': ip,
      'disk_free': freeDiskStr,
      'app_version': '1.0.0+1',
    };
  }
}
