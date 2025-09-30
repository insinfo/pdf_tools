// ignore_for_file: non_constant_identifier_names, camel_case_types

import 'dart:ffi';
import 'package:ffi/ffi.dart';

typedef QpdfData = Pointer<Void>;

// --- Assinaturas Nativas ---
typedef _qpdf_init_native = QpdfData Function();
typedef _qpdf_cleanup_native = Void Function(Pointer<QpdfData>);
typedef _qpdf_read_native = Int32 Function(QpdfData, Pointer<Utf8>, Pointer<Utf8>);
typedef _qpdf_get_num_pages_native = Int32 Function(QpdfData);
typedef _qpdf_init_write_native = Int32 Function(QpdfData, Pointer<Utf8>);
typedef _qpdf_set_linearization_native = Void Function(QpdfData, Int32);
typedef _qpdf_write_native = Int32 Function(QpdfData);
typedef _qpdf_has_error_native = Int32 Function(QpdfData);
typedef _qpdf_get_error_native = QpdfData Function(QpdfData);
typedef _qpdf_get_error_full_text_native = Pointer<Utf8> Function(QpdfData, QpdfData);

// --- NOVA FUNÇÃO ---
typedef _qpdf_set_attempt_recovery_native = Void Function(QpdfData, Int32);


// --- Assinaturas Dart ---
typedef qpdf_init_dart = QpdfData Function();
typedef qpdf_cleanup_dart = void Function(Pointer<QpdfData>);
typedef qpdf_read_dart = int Function(QpdfData, Pointer<Utf8>, Pointer<Utf8>);
typedef qpdf_get_num_pages_dart = int Function(QpdfData);
typedef qpdf_init_write_dart = int Function(QpdfData, Pointer<Utf8>);
typedef qpdf_set_linearization_dart = void Function(QpdfData, int);
typedef qpdf_write_dart = int Function(QpdfData);
typedef qpdf_has_error_dart = int Function(QpdfData);
typedef qpdf_get_error_dart = QpdfData Function(QpdfData);
typedef qpdf_get_error_full_text_dart = Pointer<Utf8> Function(QpdfData, QpdfData);

// --- NOVA FUNÇÃO ---
typedef qpdf_set_attempt_recovery_dart = void Function(QpdfData, int);


class QpdfBindings {
  QpdfBindings(this._lib) {
    Pointer<NativeFunction<T>> _lookup<T extends Function>(String s) =>
        _lib.lookup<NativeFunction<T>>(s);

    qpdf_init = _lookup<_qpdf_init_native>('qpdf_init').asFunction();
    qpdf_cleanup = _lookup<_qpdf_cleanup_native>('qpdf_cleanup').asFunction();
    qpdf_read = _lookup<_qpdf_read_native>('qpdf_read').asFunction();
    qpdf_get_num_pages =
        _lookup<_qpdf_get_num_pages_native>('qpdf_get_num_pages').asFunction();
    qpdf_init_write =
        _lookup<_qpdf_init_write_native>('qpdf_init_write').asFunction();
    qpdf_set_linearization =
        _lookup<_qpdf_set_linearization_native>('qpdf_set_linearization')
            .asFunction();
    qpdf_write = _lookup<_qpdf_write_native>('qpdf_write').asFunction();
    qpdf_has_error =
        _lookup<_qpdf_has_error_native>('qpdf_has_error').asFunction();
    qpdf_get_error =
        _lookup<_qpdf_get_error_native>('qpdf_get_error').asFunction();
    qpdf_get_error_full_text =
        _lookup<_qpdf_get_error_full_text_native>('qpdf_get_error_full_text')
            .asFunction();
    
    // --- CARREGAR NOVA FUNÇÃO ---
    qpdf_set_attempt_recovery =
        _lookup<_qpdf_set_attempt_recovery_native>('qpdf_set_attempt_recovery')
            .asFunction();
  }

  final DynamicLibrary _lib;

  late final qpdf_init_dart qpdf_init;
  late final qpdf_cleanup_dart qpdf_cleanup;
  late final qpdf_read_dart qpdf_read;
  late final qpdf_get_num_pages_dart qpdf_get_num_pages;
  late final qpdf_init_write_dart qpdf_init_write;
  late final qpdf_set_linearization_dart qpdf_set_linearization;
  late final qpdf_write_dart qpdf_write;
  late final qpdf_has_error_dart qpdf_has_error;
  late final qpdf_get_error_dart qpdf_get_error;
  late final qpdf_get_error_full_text_dart qpdf_get_error_full_text;
  
  // --- EXPOR NOVA FUNÇÃO ---
  late final qpdf_set_attempt_recovery_dart qpdf_set_attempt_recovery;

  factory QpdfBindings.open([String dllPath = 'qpdf.dll']) =>
      QpdfBindings(DynamicLibrary.open(dllPath));
}