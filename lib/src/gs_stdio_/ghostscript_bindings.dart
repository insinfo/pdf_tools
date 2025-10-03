// ignore_for_file: non_constant_identifier_names, camel_case_types, constant_identifier_names, no_leading_underscores_for_local_identifiers, library_private_types_in_public_api
import 'dart:ffi';

const int GS_ARG_ENCODING_UTF8 = 1;

// --- callbacks nativos para set_stdio ---
typedef gs_stdin_cb_native  = Int32 Function(Pointer<Void>, Pointer<Int8>, Int32);
typedef gs_stdin_cb_native_dart  = int Function(Pointer<Void>, Pointer<Int8>, int);

typedef gs_stdout_cb_native = Int32 Function(Pointer<Void>, Pointer<Int8>, Int32);
typedef gs_stdout_cb_native_dart = int Function(Pointer<Void>, Pointer<Int8>, int);

typedef gs_stderr_cb_native = Int32 Function(Pointer<Void>, Pointer<Int8>, Int32);
typedef gs_stderr_cb_native_dart = int Function(Pointer<Void>, Pointer<Int8>, int);

// --- funções nativas ---
typedef _gsapi_new_instance_native      = Int32 Function(Pointer<Pointer<Void>>, Pointer<Void>);
typedef _gsapi_init_with_args_native    = Int32 Function(Pointer<Void>, Int32, Pointer<Pointer<Int8>>);
typedef _gsapi_exit_native              = Int32 Function(Pointer<Void>);
typedef _gsapi_delete_instance_native   = Void  Function(Pointer<Void>);
typedef _gsapi_set_arg_encoding_native  = Int32 Function(Pointer<Void>, Int32);
typedef _gsapi_set_stdio_native         = Int32 Function(
  Pointer<Void>,
  Pointer<NativeFunction<gs_stdin_cb_native>>,
  Pointer<NativeFunction<gs_stdout_cb_native>>,
  Pointer<NativeFunction<gs_stderr_cb_native>>,
);

// --- callables Dart ---
typedef gsapi_new_instance_dart     = int Function(Pointer<Pointer<Void>>, Pointer<Void>);
typedef gsapi_init_with_args_dart   = int Function(Pointer<Void>, int, Pointer<Pointer<Int8>>);
typedef gsapi_exit_dart             = int Function(Pointer<Void>);
typedef gsapi_delete_instance_dart  = void Function(Pointer<Void>);
typedef gsapi_set_arg_encoding_dart = int Function(Pointer<Void>, int);
typedef gsapi_set_stdio_dart        = int Function(
  Pointer<Void>,
  Pointer<NativeFunction<gs_stdin_cb_native>>,
  Pointer<NativeFunction<gs_stdout_cb_native>>,
  Pointer<NativeFunction<gs_stderr_cb_native>>,
);

class GhostscriptBindings {
  GhostscriptBindings(this._lib) {
    Pointer<NativeFunction<T>> _lookup<T extends Function>(String s) =>
        _lib.lookup<NativeFunction<T>>(s);

    gsapi_new_instance     = _lookup<_gsapi_new_instance_native>('gsapi_new_instance').asFunction();
    gsapi_init_with_args   = _lookup<_gsapi_init_with_args_native>('gsapi_init_with_args').asFunction();
    gsapi_exit             = _lookup<_gsapi_exit_native>('gsapi_exit').asFunction();
    gsapi_delete_instance  = _lookup<_gsapi_delete_instance_native>('gsapi_delete_instance').asFunction();
    gsapi_set_arg_encoding = _lookup<_gsapi_set_arg_encoding_native>('gsapi_set_arg_encoding').asFunction();
    gsapi_set_stdio        = _lookup<_gsapi_set_stdio_native>('gsapi_set_stdio').asFunction();
  }

  final DynamicLibrary _lib;

  late final gsapi_new_instance_dart     gsapi_new_instance;
  late final gsapi_init_with_args_dart   gsapi_init_with_args;
  late final gsapi_exit_dart             gsapi_exit;
  late final gsapi_delete_instance_dart  gsapi_delete_instance;
  late final gsapi_set_arg_encoding_dart gsapi_set_arg_encoding;
  late final gsapi_set_stdio_dart        gsapi_set_stdio;

  factory GhostscriptBindings.open([String dllPath = 'gsdll64.dll']) =>
      GhostscriptBindings(DynamicLibrary.open(dllPath));
}
