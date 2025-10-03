// gsx_bridge.dart
// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures, camel_case_types

import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

import 'gsx_bridge_bindings.dart';

/// ---------------- Signatures nativas (espelham o header C) ----------------

typedef _gsx_progress_cb_native = Void Function(
  Int32 page_done,
  Int32 total_pages,
  Pointer<Utf8> line,
  Pointer<Void> user,
);

typedef _gsx_file_cb_native = Void Function(
  Pointer<Utf8> inPath,
  Pointer<Utf8> outPath,
  Pointer<Void> user,
);

/// ---------------- Callbacks em Dart (alto nível) ----------------

typedef ProgressCallback = void Function(
  int pageDone,
  int totalPages,
  String line,
);

typedef FileIterCallback = void Function(String inPath, String outPath);

/// ---------------- Exceções/Cancelamento ----------------

class GsxException implements Exception {
  final int code;
  final String where;
  GsxException(this.code, this.where);
  @override
  String toString() => 'GsxException(code=$code, at=$where)';
}

class GsxCancelToken {
  final Pointer<Int32> _flag = calloc<Int32>();
  void cancel() => _flag.value = 1;
  bool get isCancelled => _flag.value != 0;
  Pointer<Int32> get ptr => _flag;
  void dispose() => calloc.free(_flag);
}

/// ---------------- Shared callback registry ----------------
/// Usa NativeCallable.listener para permitir chamadas de qualquer thread.
/// Mantemos callables singletons, criados sob demanda.
class _CallbackRegistry {
  static final Map<int, ProgressCallback> _progress = {};
  static final Map<int, FileIterCallback> _file = {};
  static int _nextId = 1;

  static NativeCallable<_gsx_progress_cb_native>? _progressCallable;
  static NativeCallable<_gsx_file_cb_native>? _fileCallable;

  static void _progressTrampoline(
    int pageDone,
    int totalPages,
    Pointer<Utf8> line,
    Pointer<Void> user,
  ) {
    final id = user.address;
    final cb = _progress[id];
    if (cb != null) {
      cb(pageDone, totalPages, line == nullptr ? '' : line.toDartString());
    }
  }

  static void _fileTrampoline(
    Pointer<Utf8> inPath,
    Pointer<Utf8> outPath,
    Pointer<Void> user,
  ) {
    final id = user.address;
    final cb = _file[id];
    cb?.call(inPath.toDartString(), outPath.toDartString());
  }

  static Pointer<NativeFunction<_gsx_progress_cb_native>> _progressPtr() {
    _progressCallable ??= NativeCallable<_gsx_progress_cb_native>.listener(
      _progressTrampoline,
    );
    // _progressCallable!.keepIsolateAlive = false; // opcional
    return _progressCallable!.nativeFunction;
  }

  static Pointer<NativeFunction<_gsx_file_cb_native>> _filePtr() {
    _fileCallable ??= NativeCallable<_gsx_file_cb_native>.listener(
      _fileTrampoline,
    );
    // _fileCallable!.keepIsolateAlive = false; // opcional
    return _fileCallable!.nativeFunction;
  }

  static int register({ProgressCallback? onProgress, FileIterCallback? onFile}) {
    final id = _nextId++;
    if (onProgress != null) _progress[id] = onProgress;
    if (onFile != null) _file[id] = onFile;
    return id;
  }

  static void unregister(int id) {
    _progress.remove(id);
    _file.remove(id);
  }

  static void closeAll() {
    _progressCallable?.close(); _progressCallable = null;
    _fileCallable?.close(); _fileCallable = null;
  }
}

/// ---------------- Job handle (async) ----------------

class GsxJob {
  final GsxBridge _gsx;
  final Pointer<Void> _job;
  final int _cbId;
  final GsxCancelToken? _cancel;

  GsxJob(this._gsx, this._job, this._cbId, this._cancel);

  int status() => _gsx._b.api.gsx_job_status(_job);

  int join() {
    final rc = _gsx._b.api.gsx_job_join(_job);
    _dispose();
    if (rc < 0) throw GsxException(rc, 'gsx_job_join');
    return rc;
  }

  void cancel() => _gsx._b.api.gsx_job_cancel(_job);

  void _dispose() {
    _gsx._b.api.gsx_job_free(_job);
    _CallbackRegistry.unregister(_cbId);
    _cancel?.dispose();
  }
}

/// ---------------- High-level API ----------------

class GsxBridge {
  GsxBridge._(this._b);
  final GsxBridgeBindings _b;

  factory GsxBridge.open([String? libraryPath]) =>
      GsxBridge._(GsxBridgeBindings.open(libraryPath));

  void dispose() => _CallbackRegistry.closeAll();

  List<String> buildPdfwriteArgs({
    required String input,
    required String output,
    required int dpi,
    required int jpegQuality,
    String? preset,
    int colorMode = GsxColorMode.color,
    int firstPage = 0,
    int lastPage = 0,
  }) {
    const maxA = 64;
    final argv = calloc<Pointer<Utf8>>(maxA);
    try {
      final inP = input.toNativeUtf8();
      final outP = output.toNativeUtf8();
      final preP = (preset ?? '').toNativeUtf8();

      final n = _b.api.gsx_build_pdfwrite_args(
        argv,
        maxA,
        inP,
        outP,
        dpi,
        jpegQuality,
        preP,
        colorMode,
        firstPage,
        lastPage,
      );

      calloc.free(inP);
      calloc.free(outP);
      calloc.free(preP);

      final dartArgs = <String>[];
      final count = n.clamp(0, maxA);
      for (var i = 0; i < count; i++) {
        final p = argv[i];
        if (p == nullptr) break;
        dartArgs.add(p.toDartString());
      }
      return dartArgs;
    } finally {
      _b.api.gsx_free_argv(argv, 0);
      calloc.free(argv);
    }
  }

  int runArgsSync(
    List<String> args, {
    ProgressCallback? onProgress,
    GsxCancelToken? cancel,
  }) {
    final argc = args.length;
    final argv = calloc<Pointer<Utf8>>(argc);
    final alloc = <Pointer<Utf8>>[];

    // ---- token fora do try/finally ----
    final token = cancel ?? GsxCancelToken();
    final createdToken = cancel == null;

    try {
      for (var i = 0; i < argc; i++) {
        final p = args[i].toNativeUtf8();
        alloc.add(p);
        argv[i] = p;
      }

      final id = _CallbackRegistry.register(onProgress: onProgress);
      final user = Pointer<Void>.fromAddress(id);

      final rc = _b.api.gsx_run_args_sync(
        argc,
        argv,
        _CallbackRegistry._progressPtr(),
        user,
        token.ptr,
      );
      _CallbackRegistry.unregister(id);
      if (rc < 0) throw GsxException(rc, 'gsx_run_args_sync');
      return rc;
    } finally {
      for (final p in alloc) calloc.free(p);
      calloc.free(argv);
      if (createdToken) token.dispose();
    }
  }

  int compressFileSync({
    required String inputPath,
    required String outputPath,
    int dpi = 150,
    int jpegQuality = 65,
    String? preset,
    int colorMode = GsxColorMode.color,
    int firstPage = 0,
    int lastPage = 0,
    ProgressCallback? onProgress,
    GsxCancelToken? cancel,
  }) {
    final inP = inputPath.toNativeUtf8();
    final outP = outputPath.toNativeUtf8();
    final preP = (preset ?? '').toNativeUtf8();

    final token = cancel ?? GsxCancelToken();
    final createdToken = cancel == null;

    try {
      final id = _CallbackRegistry.register(onProgress: onProgress);
      final user = Pointer<Void>.fromAddress(id);

      final rc = _b.api.gsx_compress_file_sync(
        inP,
        outP,
        dpi,
        jpegQuality,
        preP,
        colorMode,
        firstPage,
        lastPage,
        _CallbackRegistry._progressPtr(),
        user,
        token.ptr,
      );
      _CallbackRegistry.unregister(id);
      if (rc < 0) throw GsxException(rc, 'gsx_compress_file_sync');
      return rc;
    } finally {
      calloc.free(inP);
      calloc.free(outP);
      calloc.free(preP);
      if (createdToken) token.dispose();
    }
  }

  Uint8List compressBytesSync({
    required Uint8List input,
    int dpi = 150,
    int jpegQuality = 65,
    String? preset,
    int colorMode = GsxColorMode.color,
    ProgressCallback? onProgress,
    GsxCancelToken? cancel,
  }) {
    final inPtr = calloc<Uint8>(input.length);
    inPtr.asTypedList(input.length).setAll(0, input);
    final outBytesPtr = calloc<Pointer<Void>>();
    final outLenPtr = calloc<Uint64>();
    final preP = (preset ?? '').toNativeUtf8();

    final token = cancel ?? GsxCancelToken();
    final createdToken = cancel == null;

    try {
      final id = _CallbackRegistry.register(onProgress: onProgress);
      final user = Pointer<Void>.fromAddress(id);

      final rc = _b.api.gsx_compress_bytes_sync(
        inPtr.cast(),
        input.length,
        outBytesPtr,
        outLenPtr,
        dpi,
        jpegQuality,
        preP,
        colorMode,
        _CallbackRegistry._progressPtr(),
        user,
        token.ptr,
      );
      _CallbackRegistry.unregister(id);
      if (rc < 0) throw GsxException(rc, 'gsx_compress_bytes_sync');

      final outLen = outLenPtr.value;
      final outData = outBytesPtr.value.cast<Uint8>().asTypedList(outLen);
      final copy = Uint8List.fromList(outData);
      _b.api.gsx_free(outBytesPtr.value);
      return copy;
    } finally {
      calloc.free(inPtr);
      calloc.free(outBytesPtr);
      calloc.free(outLenPtr);
      calloc.free(preP);
      if (createdToken) token.dispose();
    }
  }

  GsxJob compressFileAsync({
    required String inputPath,
    required String outputPath,
    int dpi = 150,
    int jpegQuality = 65,
    String? preset,
    int colorMode = GsxColorMode.color,
    int firstPage = 0,
    int lastPage = 0,
    ProgressCallback? onProgress,
    GsxCancelToken? cancel,
  }) {
    final inP = inputPath.toNativeUtf8();
    final outP = outputPath.toNativeUtf8();
    final preP = (preset ?? '').toNativeUtf8();

    final token = cancel ?? GsxCancelToken();
    final createdToken = cancel == null;

    final id = _CallbackRegistry.register(onProgress: onProgress);
    final user = Pointer<Void>.fromAddress(id);

    try {
      final job = _b.api.gsx_compress_file_async(
        inP,
        outP,
        dpi,
        jpegQuality,
        preP,
        colorMode,
        firstPage,
        lastPage,
        _CallbackRegistry._progressPtr(),
        user,
        token.ptr,
      );
      if (job == nullptr) {
        _CallbackRegistry.unregister(id);
        if (createdToken) token.dispose();
        throw GsxException(-1, 'gsx_compress_file_async(null)');
      }
      // Se nós criamos o token, o GsxJob passa a ser o dono e vai descartá-lo.
      return GsxJob(this, job, id, createdToken ? token : null);
    } finally {
      calloc.free(inP);
      calloc.free(outP);
      calloc.free(preP);
    }
  }

  int compressDirSync({
    required String inputDir,
    required String outputDir,
    int dpi = 150,
    int jpegQuality = 65,
    String? preset,
    int colorMode = GsxColorMode.color,
    ProgressCallback? onProgress,
    FileIterCallback? onFile,
    GsxCancelToken? cancel,
  }) {
    final inD = inputDir.toNativeUtf8();
    final outD = outputDir.toNativeUtf8();
    final preP = (preset ?? '').toNativeUtf8();

    final token = cancel ?? GsxCancelToken();
    final createdToken = cancel == null;

    try {
      final id = _CallbackRegistry.register(
        onProgress: onProgress,
        onFile: onFile,
      );
      final user = Pointer<Void>.fromAddress(id);

      final rc = _b.api.gsx_compress_dir_sync(
        inD,
        outD,
        dpi,
        jpegQuality,
        preP,
        colorMode,
        _CallbackRegistry._progressPtr(),
        user,
        token.ptr,
        onFile != null ? _CallbackRegistry._filePtr() : nullptr,
      );
      _CallbackRegistry.unregister(id);

      if (rc < 0) throw GsxException(rc, 'gsx_compress_dir_sync');
      return rc;
    } finally {
      calloc.free(inD);
      calloc.free(outD);
      calloc.free(preP);
      if (createdToken) token.dispose();
    }
  }
}
