import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'cloudstream_paths.dart';

class CloudStreamSidecar {
  static final CloudStreamSidecar instance = CloudStreamSidecar._();
  CloudStreamSidecar._();

  Process? _process;
  bool _initialized = false;
  final _completers = <String, Completer<dynamic>>{};
  final _streamControllers = <String, StreamController<dynamic>>{};
  int _requestId = 0;

  bool get isRunning => _initialized && _process != null;

  Future<void> initialize() async {
    if (_initialized && _process != null) return;

    final paths = CloudStreamPaths.instance;
    final javaPath = await paths.javaExecutablePath;
    final bridgeJarPath = await paths.bridgeJarPath;

    if (javaPath == null || !await File(javaPath).exists()) {
      throw StateError('Java executable not found. Please setup the CloudStream runtime first.');
    }

    if (!await File(bridgeJarPath).exists()) {
      throw StateError('Bridge runtime JAR not found. Please setup the CloudStream runtime first.');
    }

    final completer = Completer<void>();

    debugPrint('[CloudStreamSidecar] Launching sidecar: $javaPath -jar $bridgeJarPath');

    _process = await Process.start(javaPath, [
      '-Dfile.encoding=UTF-8',
      '-Dsun.stdout.encoding=UTF-8',
      '-Dsun.stderr.encoding=UTF-8',
      '-Xms128m',
      '-Xmx512m',
      '-noverify',
      '-jar',
      bridgeJarPath,
    ]);

    _process!.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(_handleStdout, onError: (err) {
      debugPrint('[CloudStreamSidecar] stdout error: $err');
    }, onDone: () {
      debugPrint('[CloudStreamSidecar] Process exited.');
      _initialized = false;
      _process = null;
    });

    _process!.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) {
      if (line.contains('Sidecar Process Started') || line.contains('Runtime initialized')) {
        if (!completer.isCompleted) completer.complete();
      }
    });

    await completer.future.timeout(const Duration(seconds: 12), onTimeout: () {
      if (!completer.isCompleted) {
        debugPrint('[CloudStreamSidecar] Warning: Startup signal timed out, proceeding anyway.');
        completer.complete();
      }
    });

    _initialized = true;
  }

  void _handleStdout(String line) {
    if (line.trim().isEmpty) return;
    try {
      final response = jsonDecode(line);
      final id = response['id']?.toString();
      final data = response['data'];
      final status = response['status']?.toString();

      if (id != null) {
        if (_streamControllers.containsKey(id)) {
          final controller = _streamControllers[id]!;
          if (status == 'completed') {
            _streamControllers.remove(id);
            controller.close();
          } else if (status == 'error') {
            _streamControllers.remove(id);
            controller.addError(data ?? 'Unknown Error');
          } else {
            // Partial link found
            controller.add(data);
          }
        } else if (_completers.containsKey(id)) {
          final completer = _completers.remove(id)!;
          if (status == 'error') {
            completer.completeError(data ?? 'Error from sidecar');
          } else {
            completer.complete(data);
          }
        }
      }
    } catch (e) {
      debugPrint('[CloudStreamSidecar] Failed to decode JSON response: $e');
    }
  }

  Future<dynamic> invokeMethod(
    String method,
    Map<String, dynamic> args, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (!_initialized || _process == null) {
      await initialize();
    }

    final id = (_requestId++).toString();
    final completer = Completer<dynamic>();
    _completers[id] = completer;

    final request = jsonEncode({
      'method': method,
      'args': args,
      'id': id,
    });

    _process!.stdin.writeln(request);

    return completer.future.timeout(timeout, onTimeout: () {
      _completers.remove(id);
      try {
        _process?.stdin.writeln(jsonEncode({
          'method': 'cancel',
          'args': {'id': id},
        }));
      } catch (_) {}
      throw TimeoutException('Sidecar request "$method" timed out after ${timeout.inSeconds}s');
    });
  }

  Stream<dynamic> invokeStreamMethod(
    String method,
    Map<String, dynamic> args, {
    Duration timeout = const Duration(seconds: 60),
  }) {
    if (!_initialized || _process == null) {
      // Return stream that initializes first
      final controller = StreamController<dynamic>();
      initialize().then((_) {
        _startStreamRequest(method, args, controller, timeout);
      }).catchError((err) {
        controller.addError(err);
        controller.close();
      });
      return controller.stream;
    }

    final controller = StreamController<dynamic>();
    _startStreamRequest(method, args, controller, timeout);
    return controller.stream;
  }

  void _startStreamRequest(
    String method,
    Map<String, dynamic> args,
    StreamController<dynamic> controller,
    Duration timeout,
  ) {
    final id = (_requestId++).toString();
    _streamControllers[id] = controller;

    final request = jsonEncode({
      'method': method,
      'args': args,
      'id': id,
    });

    _process!.stdin.writeln(request);

    // Timeout safety
    Timer(timeout, () {
      if (_streamControllers.containsKey(id)) {
        _streamControllers.remove(id);
        if (!controller.isClosed) {
          controller.close();
        }
      }
    });
  }

  void dispose() {
    _completers.clear();
    for (final c in _streamControllers.values) {
      c.close();
    }
    _streamControllers.clear();
    try {
      _process?.kill();
    } catch (_) {}
    _process = null;
    _initialized = false;
  }
}
