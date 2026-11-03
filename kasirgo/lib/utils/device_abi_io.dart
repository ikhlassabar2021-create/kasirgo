import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

Future<String?> deviceAbi() async {
  if (!Platform.isAndroid) return null;
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    for (final abi in info.supportedAbis) {
      final a = abi.toLowerCase();
      if (a.contains('arm64')) return 'arm64';
      if (a.contains('armeabi')) return 'armeabi_v7a';
      if (a.contains('x86_64')) return 'x86_64';
      if (a.contains('x86')) return 'x86';
    }
    return null;
  } catch (_) {
    return null;
  }
}