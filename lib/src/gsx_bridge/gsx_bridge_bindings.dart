// ignore_for_file: non_constant_identifier_names, camel_case_types, library_private_types_in_public_api

import 'dart:ffi';
import 'dart:io' show Platform;
import 'package:ffi/ffi.dart';

/// Enum C (espelho numérico)
class GsxColorMode {
  static const int color = 0;
  static const int gray = 1;
  static const int bilevel = 2;
}

/// C: typedef void (GSX_CALL *gsx_progress_cb)
///        (int page_done,int total_pages,const char* line,void* user);
typedef GsxProgressCbNative = Void Function(
  Int32 page_done,
  Int32 total_pages,
  Pointer<Utf8> line,
  Pointer<Void> user,
);

/// C: typedef void (GSX_CALL *gsx_file_cb)
///        (const char* in_path,const char* out_path,void* user);
typedef GsxFileCbNative = Void Function(
  Pointer<Utf8> in_path,
  Pointer<Utf8> out_path,
  Pointer<Void> user,
);

class _Lib {
  final DynamicLibrary lib;
  _Lib(this.lib);

  // -------- Contexto --------
  late final Pointer<Void> Function() gsx_create_context =
      lib.lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
        'gsx_create_context',
      );

  late final void Function(Pointer<Void>) gsx_destroy_context =
      lib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
        'gsx_destroy_context',
      );

  // -------- Helpers de argv --------
  late final int Function(
    Pointer<Pointer<Utf8>> argvOut,
    int maxArgv,
    Pointer<Utf8> inPath,
    Pointer<Utf8> outPath,
    int dpi,
    int jpegQuality,
    Pointer<Utf8> presetOrNull,
    int mode,
    int firstPage,
    int lastPage,
  ) gsx_build_pdfwrite_args = lib.lookupFunction<
      Int32 Function(
        Pointer<Pointer<Utf8>>,
        Int32,
        Pointer<Utf8>,
        Pointer<Utf8>,
        Int32,
        Int32,
        Pointer<Utf8>,
        Int32,
        Int32,
        Int32,
      ),
      int Function(
        Pointer<Pointer<Utf8>>,
        int,
        Pointer<Utf8>,
        Pointer<Utf8>,
        int,
        int,
        Pointer<Utf8>,
        int,
        int,
        int,
      )>('gsx_build_pdfwrite_args');

  late final void Function(Pointer<Pointer<Utf8>>, int) gsx_free_argv =
      lib.lookupFunction<Void Function(Pointer<Pointer<Utf8>>, Int32),
          void Function(Pointer<Pointer<Utf8>>, int)>('gsx_free_argv');

  // -------- Execuções síncronas --------
  late final int Function(
    int argc,
    Pointer<Pointer<Utf8>> argv,
    Pointer<NativeFunction<GsxProgressCbNative>> onProgress,
    Pointer<Void> user,
    Pointer<Int32> cancelFlagOrNull,
  ) gsx_run_args_sync = lib.lookupFunction<
      Int32 Function(
        Int32,
        Pointer<Pointer<Utf8>>,
        Pointer<NativeFunction<GsxProgressCbNative>>,
        Pointer<Void>,
        Pointer<Int32>,
      ),
      int Function(
        int,
        Pointer<Pointer<Utf8>>,
        Pointer<NativeFunction<GsxProgressCbNative>>,
        Pointer<Void>,
        Pointer<Int32>,
      )>('gsx_run_args_sync');

  late final int Function(
    Pointer<Utf8> inPath,
    Pointer<Utf8> outPath,
    int dpi,
    int jpegQuality,
    Pointer<Utf8> presetOrNull,
    int mode,
    int firstPage,
    int lastPage,
    Pointer<NativeFunction<GsxProgressCbNative>> onProgress,
    Pointer<Void> user,
    Pointer<Int32> cancelFlagOrNull,
  ) gsx_compress_file_sync = lib.lookupFunction<
      Int32 Function(
        Pointer<Utf8>,
        Pointer<Utf8>,
        Int32,
        Int32,
        Pointer<Utf8>,
        Int32,
        Int32,
        Int32,
        Pointer<NativeFunction<GsxProgressCbNative>>,
        Pointer<Void>,
        Pointer<Int32>,
      ),
      int Function(
        Pointer<Utf8>,
        Pointer<Utf8>,
        int,
        int,
        Pointer<Utf8>,
        int,
        int,
        int,
        Pointer<NativeFunction<GsxProgressCbNative>>,
        Pointer<Void>,
        Pointer<Int32>,
      )>('gsx_compress_file_sync');

  late final int Function(
    Pointer<Void> inBytes,
    int inLen, // C: Uint64
    Pointer<Pointer<Void>> outBytes,
    Pointer<Uint64> outLen,
    int dpi,
    int jpegQuality,
    Pointer<Utf8> presetOrNull,
    int mode,
    Pointer<NativeFunction<GsxProgressCbNative>> onProgress,
    Pointer<Void> user,
    Pointer<Int32> cancelFlagOrNull,
  ) gsx_compress_bytes_sync = lib.lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Uint64,
        Pointer<Pointer<Void>>,
        Pointer<Uint64>,
        Int32,
        Int32,
        Pointer<Utf8>,
        Int32,
        Pointer<NativeFunction<GsxProgressCbNative>>,
        Pointer<Void>,
        Pointer<Int32>,
      ),
      int Function(
        Pointer<Void>,
        int,
        Pointer<Pointer<Void>>,
        Pointer<Uint64>,
        int,
        int,
        Pointer<Utf8>,
        int,
        Pointer<NativeFunction<GsxProgressCbNative>>,
        Pointer<Void>,
        Pointer<Int32>,
      )>('gsx_compress_bytes_sync');

  // -------- Assíncrono (job) --------
  late final Pointer<Void> Function(
    Pointer<Utf8> inPath,
    Pointer<Utf8> outPath,
    int dpi,
    int jpegQuality,
    Pointer<Utf8> presetOrNull,
    int mode,
    int firstPage,
    int lastPage,
    Pointer<NativeFunction<GsxProgressCbNative>> onProgress,
    Pointer<Void> user,
    Pointer<Int32> cancelFlagOrNull,
  ) gsx_compress_file_async = lib.lookupFunction<
      Pointer<Void> Function(
        Pointer<Utf8>,
        Pointer<Utf8>,
        Int32,
        Int32,
        Pointer<Utf8>,
        Int32,
        Int32,
        Int32,
        Pointer<NativeFunction<GsxProgressCbNative>>,
        Pointer<Void>,
        Pointer<Int32>,
      ),
      Pointer<Void> Function(
        Pointer<Utf8>,
        Pointer<Utf8>,
        int,
        int,
        Pointer<Utf8>,
        int,
        int,
        int,
        Pointer<NativeFunction<GsxProgressCbNative>>,
        Pointer<Void>,
        Pointer<Int32>,
      )>('gsx_compress_file_async');

  late final int Function(Pointer<Void>) gsx_job_status =
      lib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
        'gsx_job_status',
      );

  late final int Function(Pointer<Void>) gsx_job_join =
      lib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
        'gsx_job_join',
      );

  late final void Function(Pointer<Void>) gsx_job_cancel =
      lib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
        'gsx_job_cancel',
      );

  late final void Function(Pointer<Void>) gsx_job_free =
      lib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
        'gsx_job_free',
      );

  // -------- Dir -> Dir --------
  late final int Function(
    Pointer<Utf8> inDir,
    Pointer<Utf8> outDir,
    int dpi,
    int jpegQuality,
    Pointer<Utf8> presetOrNull,
    int mode,
    Pointer<NativeFunction<GsxProgressCbNative>> onProgress,
    Pointer<Void> user,
    Pointer<Int32> cancelFlagOrNull,
    Pointer<NativeFunction<GsxFileCbNative>> onFileOrNull,
  ) gsx_compress_dir_sync = lib.lookupFunction<
      Int32 Function(
        Pointer<Utf8>,
        Pointer<Utf8>,
        Int32,
        Int32,
        Pointer<Utf8>,
        Int32,
        Pointer<NativeFunction<GsxProgressCbNative>>,
        Pointer<Void>,
        Pointer<Int32>,
        Pointer<NativeFunction<GsxFileCbNative>>,
      ),
      int Function(
        Pointer<Utf8>,
        Pointer<Utf8>,
        int,
        int,
        Pointer<Utf8>,
        int,
        Pointer<NativeFunction<GsxProgressCbNative>>,
        Pointer<Void>,
        Pointer<Int32>,
        Pointer<NativeFunction<GsxFileCbNative>>,
      )>('gsx_compress_dir_sync');

  // -------- Util --------
  late final void Function(Pointer<Void>) gsx_free =
      lib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
        'gsx_free',
      );
}

class GsxBridgeBindings {
  GsxBridgeBindings._(this._lib);
  final _Lib _lib;

  static String _defaultLibName() {
    if (Platform.isWindows) return 'gsx_bridge.dll';
    if (Platform.isMacOS) return 'libgsx_bridge.dylib';
    return 'libgsx_bridge.so';
  }

  factory GsxBridgeBindings.open([String? path]) {
    final lib = DynamicLibrary.open(path ?? _defaultLibName());
    return GsxBridgeBindings._(_Lib(lib));
  }

  _Lib get api => _lib;
}
