import 'dart:io';

Future<String?> deviceAbi() async {
  if (!Platform.isAndroid) return null;
  final abi = Abi.current();
  switch (abi) {
    case Abi.androidArm64:
      return 'arm64';
    case Abi.androidArm:
      return 'armeabi_v7a';
    case Abi.androidX64:
      return 'x86_64';
    case Abi.androidIA32:
      return 'x86';
    default:
      return null;
  }
}