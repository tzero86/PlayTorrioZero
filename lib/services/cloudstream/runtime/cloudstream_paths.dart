import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CloudStreamPaths {
  static final CloudStreamPaths instance = CloudStreamPaths._();
  CloudStreamPaths._();

  Directory? _baseDir;

  Future<Directory> get baseDir async {
    if (_baseDir != null) return _baseDir!;
    final support = await getApplicationSupportDirectory();
    _baseDir = support;
    return _baseDir!;
  }

  Future<Directory> get runtimeDir async {
    final base = await baseDir;
    final dir = Directory(p.join(base.path, 'cloudstream_runtime'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> get extensionsDir async {
    final base = await baseDir;
    final dir = Directory(p.join(base.path, 'extensions', 'CloudStream'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> get jreDir async {
    final rDir = await runtimeDir;
    return Directory(p.join(rDir.path, 'jre'));
  }

  Future<Directory> get toolsDir async {
    final rDir = await runtimeDir;
    final dir = Directory(p.join(rDir.path, 'tools'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String?> get javaExecutablePath async {
    final jDir = await jreDir;
    if (Platform.isWindows) {
      final exe = File(p.join(jDir.path, 'bin', 'java.exe'));
      if (await exe.exists()) return exe.path;
      // Check subfolder if extracted into root
      final alt = File(p.join(jDir.path, 'jdk-17.0.12+7-jre', 'bin', 'java.exe'));
      if (await alt.exists()) return alt.path;
    } else if (Platform.isMacOS) {
      final macBin = File(p.join(jDir.path, 'Contents', 'Home', 'bin', 'java'));
      if (await macBin.exists()) return macBin.path;
      final standard = File(p.join(jDir.path, 'bin', 'java'));
      if (await standard.exists()) return standard.path;
    } else {
      final linuxBin = File(p.join(jDir.path, 'bin', 'java'));
      if (await linuxBin.exists()) return linuxBin.path;
    }
    return null;
  }

  Future<String> get bridgeJarPath async {
    final rDir = await runtimeDir;
    return p.join(rDir.path, 'anymex_desktop_runtime.jar');
  }

  Future<String> get runtimeApkPath async {
    final rDir = await runtimeDir;
    return p.join(rDir.path, 'anymex_runtime_host.apk');
  }

  Future<String> get dex2jarPath async {
    final tDir = await toolsDir;
    final ext = Platform.isWindows ? '.bat' : '.sh';

    // Check direct
    final direct = p.join(tDir.path, 'd2j-dex2jar$ext');
    if (await File(direct).exists()) return direct;

    // Check inside dex-tools-2.4 or dex-tools subdirectories
    for (final folderName in ['dex-tools-v2.4', 'dex-tools-2.4', 'dex-tools', 'dex-tools-2.1']) {
      final candidate = p.join(tDir.path, folderName, 'd2j-dex2jar$ext');
      if (await File(candidate).exists()) return candidate;
    }

    return p.join(tDir.path, 'dex-tools-v2.4', 'd2j-dex2jar$ext');
  }
}
