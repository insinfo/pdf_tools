// ignore_for_file: non_constant_identifier_names

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:io' show Platform;
import 'qpdf_bindings.dart';

class QpdfException implements Exception {
  QpdfException(this.code, [this.message]);
  final int code;
  final String? message;
  @override
  String toString() =>
      'QpdfException(code=$code${message == null ? '' : ', msg=$message'})';
}

class Qpdf {
  Qpdf(this._b);

  factory Qpdf.open([String? libraryPath]) {
    final path = libraryPath ?? _getLibraryPath();
    return Qpdf(QpdfBindings.open(path));
  }

  /// Retorna o nome do arquivo da biblioteca Ghostscript para o SO atual.
  static String _getLibraryPath() {
    if (Platform.isWindows) {
      return 'qpdf.dll';
    } else if (Platform.isLinux) {
      return 'qpdf.so';
    } else if (Platform.isMacOS) {
      // Bônus: adicionando suporte para macOS também
      return 'qpdf.dylib';
    } else {
      throw UnsupportedError(
          'Sistema operacional não suportado: ${Platform.operatingSystem}');
    }
  }

  final QpdfBindings _b;

  /// Executa uma operação do QPDF a partir de uma lista de argumentos, simulando a linha de comando.
  /// Opcionalmente, pode redirecionar a saída padrão para um [outputPath].
  int run(List<String> args, {String? outputPath}) {
    QpdfJob job = nullptr;
    // O primeiro argumento deve ser o nome do programa, por convenção.
    final fullArgs = ['qpdf', ...args];
    // A API QPDFJob não usa o redirecionamento '-- outputPath', então o outputPath
    // deve estar nos argumentos, geralmente após a flag '-o' ou '--output'.
    // A função _mergePdfs já faz isso corretamente.
    if (outputPath != null) {
      fullArgs.add(outputPath);
    }

    final argv = calloc<Pointer<Utf8>>(fullArgs.length + 1);
    final allocated = <Pointer<Utf8>>[];

    try {
      job = _b.qpdfjob_init();
      if (job == nullptr) throw QpdfException(-1, 'qpdfjob_init falhou.');

      for (var i = 0; i < fullArgs.length; i++) {
        final p = fullArgs[i].toNativeUtf8();
        allocated.add(p);
        argv[i] = p;
      }
      argv[fullArgs.length] = nullptr;

      // Usamos initialize_from_argv em vez de _run_from_argv
      if (_b.qpdfjob_initialize_from_argv(job, argv.cast()) != 0) {
        // A API de Job não tem um _throwError fácil, então retornamos um código de erro.
        // O job é limpo no finally.
        return -1;
      }

      final rc = _b.qpdfjob_run(job);
      if (rc != 0) {
        // A API de Job não parece ter um getter de erro fácil como a API qpdf_data.
        // Retornamos o código de erro diretamente.
        throw QpdfException(rc, 'qpdfjob_run falhou com código $rc');
      }

      return rc;
    } finally {
      if (job != nullptr) {
        final jobPtr = calloc<QpdfJob>()..value = job;
        _b.qpdfjob_cleanup(jobPtr);
        calloc.free(jobPtr);
      }
      for (final p in allocated) {
        calloc.free(p);
      }
      calloc.free(argv);
    }
  }

  /// Este método está correto e usa a API de baixo nível
  int getNumPages(String input,
      {String? password, bool attemptRecovery = false}) {
    QpdfData ctx = nullptr;
    Pointer<Utf8>? cInput, cPass;
    try {
      ctx = _b.qpdf_init();
      if (ctx == nullptr) throw QpdfException(-1, 'qpdf_init falhou.');

      _b.qpdf_set_attempt_recovery(ctx, attemptRecovery ? 1 : 0);

      cInput = input.toNativeUtf8();
      cPass = password == null ? nullptr : password.toNativeUtf8();

      if (_b.qpdf_read(ctx, cInput, cPass) != 0) _throwError(ctx);

      final pages = _b.qpdf_get_num_pages(ctx);
      return pages;
    } finally {
      _cleanup(ctx);
      if (cInput != null) calloc.free(cInput);
      if (cPass != null) calloc.free(cPass);
    }
  }

  void _cleanup(QpdfData ctx) {
    if (ctx != nullptr) {
      final ctxPtr = calloc<QpdfData>();
      ctxPtr.value = ctx;
      _b.qpdf_cleanup(ctxPtr);
      calloc.free(ctxPtr);
    }
  }

  void _throwError(QpdfData ctx) {
    if (_b.qpdf_has_error(ctx) != 0) {
      final err = _b.qpdf_get_error(ctx);
      final msgPtr = _b.qpdf_get_error_full_text(ctx, err);
      final message = msgPtr.toDartString();
      throw QpdfException(-1, message);
    } else {
      throw QpdfException(-1, 'Operação do QPDF falhou sem mensagem de erro.');
    }
  }

  // O método linearize pode ser simplificado para usar o novo método run.
  int linearize(String input, String output, {bool enable = true}) {
    final args = [input, if (enable) '--linearize', '--', output];
    return run(args);
  }
}
