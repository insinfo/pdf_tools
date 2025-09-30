// ignore_for_file: non_constant_identifier_names

import 'dart:ffi';
import 'package:ffi/ffi.dart';

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
  factory Qpdf.open([String dllPath = 'qpdf.dll']) =>
      Qpdf(QpdfBindings.open(dllPath));

  final QpdfBindings _b;

  int linearize(String input, String output,
      {String? password, bool enable = true, bool attemptRecovery = false}) {
    QpdfData ctx = nullptr;
    Pointer<Utf8>? cInput, cOutput, cPass;

    try {
      ctx = _b.qpdf_init();
      if (ctx == nullptr) throw QpdfException(-1, 'qpdf_init falhou.');

      // Desativa a tentativa de reparo para falhar rapidamente
      _b.qpdf_set_attempt_recovery(ctx, attemptRecovery ? 1 : 0);

      cInput = input.toNativeUtf8();
      cPass = password == null ? nullptr : password.toNativeUtf8();
      if (_b.qpdf_read(ctx, cInput, cPass) != 0) _throwError(ctx);

      cOutput = output.toNativeUtf8();
      if (_b.qpdf_init_write(ctx, cOutput) != 0) _throwError(ctx);

      _b.qpdf_set_linearization(ctx, enable ? 1 : 0);

      if (_b.qpdf_write(ctx) != 0) _throwError(ctx);

      return 0;
    } finally {
      _cleanup(ctx);
      if (cInput != null) calloc.free(cInput);
      if (cOutput != null) calloc.free(cOutput);
      if (cPass != null) calloc.free(cPass);
    }
  }

  int getNumPages(String input, {String? password, bool attemptRecovery = false}) {
    QpdfData ctx = nullptr;
    Pointer<Utf8>? cInput, cPass;
    try {
      ctx = _b.qpdf_init();
      if (ctx == nullptr) throw QpdfException(-1, 'qpdf_init falhou.');

      // Desativa a tentativa de reparo para falhar rapidamente
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
}