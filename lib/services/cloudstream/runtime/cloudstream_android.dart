import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'cloudstream_paths.dart';

class CloudStreamAndroid {
  static final CloudStreamAndroid instance = CloudStreamAndroid._();
  CloudStreamAndroid._();

  static const _anymeXChannel = MethodChannel('anymeXBridge');
  static const _csChannel = MethodChannel('cloudstreamExtensionBridge');

  bool _initialized = false;

  Future<void> initialize() async {
    if (!Platform.isAndroid || _initialized) return;

    final apkPath = await CloudStreamPaths.instance.runtimeApkPath;
    if (!await File(apkPath).exists()) {
      throw StateError('Runtime APK not found. Please setup the CloudStream runtime first.');
    }

    try {
      final loaded = await _anymeXChannel.invokeMethod<bool>('loadAnymeXRuntimeHost', {
        'path': apkPath,
      });

      if (loaded == true) {
        await _csChannel.invokeMethod('initialize');
        _initialized = true;
        debugPrint('[CloudStreamAndroid] Native host initialized successfully.');
      } else {
        throw StateError('Failed to load AnymeX Runtime Host on Android.');
      }
    } catch (e) {
      debugPrint('[CloudStreamAndroid] Error initializing Android bridge: $e');
      rethrow;
    }
  }

  Future<dynamic> loadPlugin(String path) async {
    if (!_initialized) await initialize();
    return _csChannel.invokeMethod('loadPlugin', {'path': path});
  }

  Future<List<Map<String, dynamic>>> getRegisteredProviders() async {
    if (!_initialized) await initialize();
    final res = await _csChannel.invokeMethod('getRegisteredProviders');
    if (res is List) {
      return res.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }
    return [];
  }

  Future<dynamic> unloadPlugin(String internalName) async {
    if (!_initialized) return;
    return _csChannel.invokeMethod('deletePlugin', {'internalName': internalName});
  }

  Future<dynamic> search({
    required String query,
    required String apiName,
    int page = 1,
  }) async {
    if (!_initialized) await initialize();
    return _csChannel.invokeMethod('search', {
      'query': query,
      'apiName': apiName,
      'page': page,
    });
  }

  Future<dynamic> getDetail({
    required String apiName,
    required String url,
  }) async {
    if (!_initialized) await initialize();
    return _csChannel.invokeMethod('getDetail', {
      'apiName': apiName,
      'url': url,
    });
  }

  Future<dynamic> getVideoList({
    required String apiName,
    required String url,
  }) async {
    if (!_initialized) await initialize();
    return _csChannel.invokeMethod('getVideoList', {
      'apiName': apiName,
      'url': url,
    });
  }

  Future<void> cancelOngoingRequests() async {
    if (!_initialized) return;
    try {
      await _csChannel.invokeMethod('cancelOngoingRequests');
    } catch (_) {}
  }

  Stream<dynamic> getVideoListStream({
    required String apiName,
    required String url,
  }) async* {
    if (!_initialized) await initialize();
    try {
      final res = await getVideoList(apiName: apiName, url: url);
      if (res is List) {
        for (final item in res) {
          yield item;
        }
      } else if (res is Map) {
        yield res;
      }
    } catch (e) {
      debugPrint('[CloudStreamAndroid] getVideoListStream error: $e');
    }
  }
}

