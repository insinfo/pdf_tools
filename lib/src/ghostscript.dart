// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'ghostscript_bindings.dart';

class GhostscriptException implements Exception {
  GhostscriptException(this.code, [this.message]);
  final int code;
  final String? message;
  @override
  String toString() =>
      'GhostscriptException(code=$code${message == null ? '' : ', msg=$message'})';
}

class Ghostscript {
  Ghostscript(this._bindings);
  factory Ghostscript.open([String dllPath = 'gsdll64.dll']) =>
      Ghostscript(GhostscriptBindings.open(dllPath));

  final GhostscriptBindings _bindings;

  int run(List<String> args, {bool throwOnError = true}) {
    final fullArgs = ['gs', ...args];
    final argc = fullArgs.length;

    final instancePtr = calloc<Pointer<Void>>();
    Pointer<Void>? instance;
    final argv = calloc<Pointer<Int8>>(argc);
    final allocated = <Pointer<Int8>>[];

    try {
      final rNew = _bindings.gsapi_new_instance(instancePtr, nullptr);
      if (rNew < 0) return _maybeThrow(rNew, throwOnError);
      instance = instancePtr.value;

      final rEnc =
          _bindings.gsapi_set_arg_encoding(instance, GS_ARG_ENCODING_UTF8);
      if (rEnc < 0) return _maybeThrow(rEnc, throwOnError);

      for (var i = 0; i < argc; i++) {
        final p = fullArgs[i].toNativeUtf8();
        final c = p.cast<Int8>();
        allocated.add(c);
        argv[i] = c;
      }

      final rInit = _bindings.gsapi_init_with_args(instance, argc, argv);
      final rExit = _bindings.gsapi_exit(instance);

      if (rInit < 0) return _maybeThrow(rInit, throwOnError);
      if (rExit < 0) return _maybeThrow(rExit, throwOnError);
      return rInit;
    } finally {
      for (final p in allocated) calloc.free(p);
      calloc.free(argv);
      final inst = instance;
      if (inst != null) _bindings.gsapi_delete_instance(inst);
      calloc.free(instancePtr);
    }
  }

  // ---------- PROGRESSO ----------
  static final Map<int, _LineEmitter> _emitters = {};

  static int _stdinCB(Pointer<Void> handle, Pointer<Int8> buf, int size) => 0;

  static int _stdoutCB(Pointer<Void> handle, Pointer<Int8> data, int len) {
    if (len <= 0) return 0;
    final em = _emitters[handle.address];
    if (em != null) {
      final bytes = data.cast<Uint8>().asTypedList(len);
      final chunk = utf8.decode(bytes, allowMalformed: true);
      em.add(chunk);
    }
    return len;
  }

  static int _stderrCB(Pointer<Void> handle, Pointer<Int8> data, int len) =>
      _stdoutCB(handle, data, len);

  int runWithProgress(List<String> args, void Function(String line) onLine,
      {bool throwOnError = true}) {
    final fullArgs = ['gs', ...args];
    final argc = fullArgs.length;

    final instancePtr = calloc<Pointer<Void>>();
    Pointer<Void>? instance;
    final argv = calloc<Pointer<Int8>>(argc);
    final allocated = <Pointer<Int8>>[];

    final handle = calloc<Int8>(1).cast<Void>();

    try {
      final rNew = _bindings.gsapi_new_instance(instancePtr, handle);
      if (rNew < 0) return _maybeThrow(rNew, throwOnError);
      instance = instancePtr.value;

      final rEnc =
          _bindings.gsapi_set_arg_encoding(instance, GS_ARG_ENCODING_UTF8);
      if (rEnc < 0) return _maybeThrow(rEnc, throwOnError);

      final rStdio = _bindings.gsapi_set_stdio(
        instance,
        Pointer.fromFunction<gs_stdin_cb_native>(_stdinCB, 0),
        Pointer.fromFunction<gs_stdout_cb_native>(_stdoutCB, 0),
        Pointer.fromFunction<gs_stderr_cb_native>(_stderrCB, 0),
      );
      if (rStdio < 0) return _maybeThrow(rStdio, throwOnError);

      _emitters[handle.address] = _LineEmitter(onLine);

      for (var i = 0; i < argc; i++) {
        final p = fullArgs[i].toNativeUtf8();
        final c = p.cast<Int8>();
        allocated.add(c);
        argv[i] = c;
      }

      final rInit = _bindings.gsapi_init_with_args(instance, argc, argv);
      final rExit = _bindings.gsapi_exit(instance);

      _emitters[handle.address]?.close();

      if (rInit < 0) return _maybeThrow(rInit, throwOnError);
      if (rExit < 0) return _maybeThrow(rExit, throwOnError);
      return rInit;
    } finally {
      _emitters.remove(handle.address);
      calloc.free(handle.cast<Int8>());
      for (final p in allocated) calloc.free(p);
      calloc.free(argv);
      final inst = instance;
      if (inst != null) _bindings.gsapi_delete_instance(inst);
      calloc.free(instancePtr);
    }
  }

  int _maybeThrow(int code, bool throwOnError) {
    if (throwOnError && code < 0) throw GhostscriptException(code);
    return code;
  }
}

class _LineEmitter {
  _LineEmitter(this.onLine);
  final void Function(String) onLine;
  String _buf = '';
  void add(String chunk) {
    _buf += chunk;
    while (true) {
      final i = _buf.indexOf('\n');
      if (i < 0) break;
      var line = _buf.substring(0, i);
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      onLine(line);
      _buf = _buf.substring(i + 1);
    }
  }

  void close() {
    if (_buf.isNotEmpty) {
      onLine(_buf);
      _buf = '';
    }
  }
}