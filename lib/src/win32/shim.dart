import 'dart:ffi';
import 'package:ffi/ffi.dart';

typedef _ShimRegisterClassC = Uint16 Function(Pointer<Utf16>);
typedef _ShimCreateWindowC = IntPtr Function(
    Pointer<Utf16>, Pointer<Utf16>, Int32, Int32);
typedef _ShimSetForwardingC = Void Function(
    IntPtr /*HWND*/, Uint32 /*tid*/, Uint32 /*msg*/);

typedef _ShimClearForwardingC = Void Function(IntPtr);
typedef _ShimFreePacketC = Void Function(Pointer<Void>);
typedef _ShimDefaultMsgC = Uint32 Function();

typedef _ShimCreateWindowFwdC = IntPtr Function(
    Pointer<Utf16>, Pointer<Utf16>, Int32, Int32, Uint32, Uint32);

class Shim {
  late final DynamicLibrary _dll;

  late final int Function(Pointer<Utf16>) registerClass =
      _dll.lookupFunction<_ShimRegisterClassC, int Function(Pointer<Utf16>)>(
          'Shim_RegisterClass');

  late final int Function(Pointer<Utf16>, Pointer<Utf16>, int, int)
      createWindow = _dll.lookupFunction<
          _ShimCreateWindowC,
          int Function(
              Pointer<Utf16>, Pointer<Utf16>, int, int)>('Shim_CreateWindow');

  late final void Function(int, int, int) setForwarding =
      _dll.lookupFunction<_ShimSetForwardingC, void Function(int, int, int)>(
          'Shim_SetForwarding');

  late final void Function(int) clearForwarding =
      _dll.lookupFunction<_ShimClearForwardingC, void Function(int)>(
          'Shim_ClearForwarding');

  late final void Function(Pointer<Void>) freePacket =
      _dll.lookupFunction<_ShimFreePacketC, void Function(Pointer<Void>)>(
          'Shim_FreePacket');

  late final int Function() defaultMsg =
      _dll.lookupFunction<_ShimDefaultMsgC, int Function()>(
          'Shim_DefaultForwardMsg');

  late final int Function(Pointer<Utf16>, Pointer<Utf16>, int, int, int, int)
      createWindowFwd = _dll.lookupFunction<_ShimCreateWindowFwdC,
          int Function(Pointer<Utf16>, Pointer<Utf16>, int, int, int, int)>(
    'Shim_CreateWindowFwd',
  );

  Shim(String path) {
    _dll = DynamicLibrary.open(path);
  }
}

final class FwdMsg extends Struct {
  @Uint32()
  external int uMsg;
  @IntPtr()
  external int wParam;
  @IntPtr()
  external int lParam;
}
