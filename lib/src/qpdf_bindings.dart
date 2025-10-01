// C:\MyDartProjects\pdf_tools\lib\src\qpdf_bindings.dart
// ignore_for_file: non_constant_identifier_names, camel_case_types

import 'dart:ffi';
import 'package:ffi/ffi.dart';

typedef QpdfData = Pointer<Void>;
typedef QpdfJob = Pointer<Void>; // NOVO: Handle para o QPDFJob

// --- Assinaturas Nativas ---
typedef _qpdf_init_native = QpdfData Function();
typedef _qpdf_cleanup_native = Void Function(Pointer<QpdfData>);
typedef _qpdf_read_native = Int32 Function(
    QpdfData, Pointer<Utf8>, Pointer<Utf8>);
typedef _qpdf_get_num_pages_native = Int32 Function(QpdfData);
typedef _qpdf_has_error_native = Int32 Function(QpdfData);
typedef _qpdf_get_error_native = QpdfData Function(QpdfData);
typedef _qpdf_get_error_full_text_native = Pointer<Utf8> Function(
    QpdfData, QpdfData);
typedef _qpdf_set_attempt_recovery_native = Void Function(QpdfData, Int32);

// --- NOVAS ASSINATURAS NATIVAS PARA QPDFJOB ---
typedef _qpdfjob_init_native = QpdfJob Function();
typedef _qpdfjob_cleanup_native = Void Function(Pointer<QpdfJob>);
typedef _qpdfjob_initialize_from_argv_native = Int32 Function(
    QpdfJob, Pointer<Pointer<Utf8>>);
typedef _qpdfjob_run_native = Int32 Function(QpdfJob);

// --- Assinaturas Dart ---
typedef qpdf_init_dart = QpdfData Function();
typedef qpdf_cleanup_dart = void Function(Pointer<QpdfData>);
typedef qpdf_read_dart = int Function(QpdfData, Pointer<Utf8>, Pointer<Utf8>);
typedef qpdf_get_num_pages_dart = int Function(QpdfData);
typedef qpdf_has_error_dart = int Function(QpdfData);
typedef qpdf_get_error_dart = QpdfData Function(QpdfData);
typedef qpdf_get_error_full_text_dart = Pointer<Utf8> Function(
    QpdfData, QpdfData);
typedef qpdf_set_attempt_recovery_dart = void Function(QpdfData, int);

// --- NOVAS ASSINATURAS DART PARA QPDFJOB ---
typedef qpdfjob_init_dart = QpdfJob Function();
typedef qpdfjob_cleanup_dart = void Function(Pointer<QpdfJob>);
typedef qpdfjob_initialize_from_argv_dart = int Function(
    QpdfJob, Pointer<Pointer<Utf8>>);
typedef qpdfjob_run_dart = int Function(QpdfJob);

class QpdfBindings {
  Pointer<NativeFunction<T>> lookup<T extends Function>(String s) =>
      _lib.lookup<NativeFunction<T>>(s);

  QpdfBindings(this._lib) {
    // Funções qpdf_ de baixo nível mantidas para getNumPages
    qpdf_init = lookup<_qpdf_init_native>('qpdf_init').asFunction();
    qpdf_cleanup = lookup<_qpdf_cleanup_native>('qpdf_cleanup').asFunction();
    qpdf_read = lookup<_qpdf_read_native>('qpdf_read').asFunction();
    qpdf_get_num_pages =
        lookup<_qpdf_get_num_pages_native>('qpdf_get_num_pages').asFunction();
    qpdf_has_error =
        lookup<_qpdf_has_error_native>('qpdf_has_error').asFunction();
    qpdf_get_error =
        lookup<_qpdf_get_error_native>('qpdf_get_error').asFunction();
    qpdf_get_error_full_text =
        lookup<_qpdf_get_error_full_text_native>('qpdf_get_error_full_text')
            .asFunction();
    qpdf_set_attempt_recovery =
        lookup<_qpdf_set_attempt_recovery_native>('qpdf_set_attempt_recovery')
            .asFunction();

    // Novas funções qpdfjob_ para o método 'run'
    qpdfjob_init = lookup<_qpdfjob_init_native>('qpdfjob_init').asFunction();
    qpdfjob_cleanup =
        lookup<_qpdfjob_cleanup_native>('qpdfjob_cleanup').asFunction();
    qpdfjob_initialize_from_argv = lookup<_qpdfjob_initialize_from_argv_native>(
            'qpdfjob_initialize_from_argv')
        .asFunction();
    qpdfjob_run = lookup<_qpdfjob_run_native>('qpdfjob_run').asFunction();
  }

  final DynamicLibrary _lib;

  // Funções qpdf_
  late final qpdf_init_dart qpdf_init;
  late final qpdf_cleanup_dart qpdf_cleanup;
  late final qpdf_read_dart qpdf_read;
  late final qpdf_get_num_pages_dart qpdf_get_num_pages;
  late final qpdf_has_error_dart qpdf_has_error;
  late final qpdf_get_error_dart qpdf_get_error;
  late final qpdf_get_error_full_text_dart qpdf_get_error_full_text;
  late final qpdf_set_attempt_recovery_dart qpdf_set_attempt_recovery;

  // Funções qpdfjob_
  late final qpdfjob_init_dart qpdfjob_init;
  late final qpdfjob_cleanup_dart qpdfjob_cleanup;
  late final qpdfjob_initialize_from_argv_dart qpdfjob_initialize_from_argv;
  late final qpdfjob_run_dart qpdfjob_run;

  factory QpdfBindings.open([String dllPath = 'qpdf.dll']) =>
      QpdfBindings(DynamicLibrary.open(dllPath));
}
