import 'dart:async';
import 'dart:io';

import 'cloudstream_sidecar.dart';
import 'cloudstream_android.dart';

class CloudStreamDispatcher {
  static final CloudStreamDispatcher instance = CloudStreamDispatcher._();
  CloudStreamDispatcher._();

  Future<void> initialize() async {
    if (Platform.isAndroid) {
      await CloudStreamAndroid.instance.initialize();
    } else {
      await CloudStreamSidecar.instance.initialize();
    }
  }

  Future<dynamic> loadExtensions(String folderPath) async {
    if (Platform.isAndroid) {
      // Android loads individual .cs3 files from the folder
      final dir = Directory(folderPath);
      final loadedMap = <String, Map<String, dynamic>>{};
      if (await dir.exists()) {
        final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.cs3'));
        for (final f in files) {
          try {
            final res = await CloudStreamAndroid.instance.loadPlugin(f.path);
            if (res is Map) {
              final m = Map<String, dynamic>.from(res);
              final id = m['id']?.toString() ?? m['name']?.toString() ?? '';
              if (id.isNotEmpty) loadedMap[id] = m;
            } else if (res is List) {
              for (final item in res) {
                if (item is Map) {
                  final m = Map<String, dynamic>.from(item);
                  final id = m['id']?.toString() ?? m['name']?.toString() ?? '';
                  if (id.isNotEmpty) loadedMap[id] = m;
                }
              }
            }
          } catch (_) {}
        }
      }
      // Ensure we also query registered providers directly from the runtime bridge
      try {
        final reg = await CloudStreamAndroid.instance.getRegisteredProviders();
        for (final item in reg) {
          final id = item['id']?.toString() ?? item['name']?.toString() ?? '';
          if (id.isNotEmpty) loadedMap[id] = item;
        }
      } catch (_) {}

      return loadedMap.values.toList();
    } else {
      return CloudStreamSidecar.instance.invokeMethod('csLoadExtensions', {
        'folderPath': folderPath,
      });
    }
  }

  Future<dynamic> search({
    required String sourceId,
    required String query,
    int page = 1,
  }) async {
    if (Platform.isAndroid) {
      return CloudStreamAndroid.instance.search(
        query: query,
        apiName: sourceId,
        page: page,
      );
    } else {
      return CloudStreamSidecar.instance.invokeMethod('csSearch', {
        'sourceId': sourceId,
        'query': query,
        'page': page,
      });
    }
  }

  Future<dynamic> getDetail({
    required String sourceId,
    required String url,
  }) async {
    if (Platform.isAndroid) {
      return CloudStreamAndroid.instance.getDetail(
        apiName: sourceId,
        url: url,
      );
    } else {
      return CloudStreamSidecar.instance.invokeMethod('csGetDetail', {
        'sourceId': sourceId,
        'url': url,
      });
    }
  }

  Future<dynamic> getVideoList({
    required String sourceId,
    required String url,
  }) async {
    if (Platform.isAndroid) {
      return CloudStreamAndroid.instance.getVideoList(
        apiName: sourceId,
        url: url,
      );
    } else {
      return CloudStreamSidecar.instance.invokeMethod('csGetVideoList', {
        'sourceId': sourceId,
        'url': url,
      });
    }
  }

  Stream<dynamic> getVideoListStream({
    required String sourceId,
    required String url,
  }) {
    if (Platform.isAndroid) {
      return CloudStreamAndroid.instance.getVideoListStream(
        apiName: sourceId,
        url: url,
      );
    } else {
      return CloudStreamSidecar.instance.invokeStreamMethod('csGetVideoListStream', {
        'sourceId': sourceId,
        'url': url,
      });
    }
  }

  Future<void> unloadExtension(String internalName) async {
    if (Platform.isAndroid) {
      await CloudStreamAndroid.instance.unloadPlugin(internalName);
    } else {
      // Sidecar re-scans folder on next csLoadExtensions
    }
  }

  void cancelOngoingRequests() {
    if (Platform.isAndroid) {
      CloudStreamAndroid.instance.cancelOngoingRequests();
    }
  }

  void dispose() {
    if (!Platform.isAndroid) {
      CloudStreamSidecar.instance.dispose();
    }
  }
}
