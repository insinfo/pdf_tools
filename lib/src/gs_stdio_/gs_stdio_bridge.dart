// gs_stdio_bridge.dart
// ignore_for_file: library_private_types_in_public_api

import 'dart:ffi';

typedef _AttachC = Int32 Function(IntPtr /*inst*/, IntPtr /*user*/, IntPtr /*hW*/);
typedef _AttachD = int Function(int, int, int);
typedef _DetachC = Void Function(IntPtr /*user*/);
typedef _DetachD = void Function(int);

class GsStdioBridge {
  GsStdioBridge._(this._lib);
  final DynamicLibrary _lib;

  late final _AttachD attach =
      _lib.lookupFunction<_AttachC, _AttachD>('GS_AttachStdIO');
  late final _DetachD detach =
      _lib.lookupFunction<_DetachC, _DetachD>('GS_DetachStdIO');

  factory GsStdioBridge.open([String path = 'gs_stdio_bridge.dll']) =>
      GsStdioBridge._(DynamicLibrary.open(path));
}
