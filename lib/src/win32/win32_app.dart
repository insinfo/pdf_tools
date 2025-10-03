// ignore_for_file: camel_case_types, non_constant_identifier_names, curly_braces_in_flow_control_structures, unused_element

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

import 'win32_api.dart';
import 'shim.dart' as shim;

// Mapeamento HWND -> instância
final _appsByHWND = <int, Win32App>{};

// Carrega o shim nativo UMA vez (ajuste o nome/caminho da DLL se precisar)
final shim.Shim _shim = shim.Shim('wndproc_shim.dll');
// ID da mensagem WM_APP usada pelo shim para forwarding
final int _shimMsgForward = _shim.defaultMsg();

// verção nova que usar wndproc_shim.cpp
class Win32App {
  final String _title;
  final int width, height;
  final void Function() _onCreate, _onPaint, _onDestroy;
  final void Function(int, int, int) _onInput;

  int _hwnd = 0;
  bool _running = false;
  bool _created = false;

  int get hwnd => _hwnd;

  bool debug;

  Win32App({
    required String title,
    this.width = 800,
    this.height = 600,
    required void Function() onCreate,
    required void Function() onPaint,
    required void Function(int uMsg, int wParam, int lParam) onInput,
    required void Function() onDestroy,
    this.debug = false,
  })  : _title = title,
        _onCreate = onCreate,
        _onPaint = onPaint,
        _onInput = onInput,
        _onDestroy = onDestroy;

  bool _needsRepaint = true; // pinta 1x após criar

  void requestRepaint() {
    _needsRepaint = true;
    // Acorda a fila de mensagens da janela imediatamente
    PostMessage(_hwnd, WM_NULL, 0, 0);
  }

  Future<void> run() async {
    if (_running) throw Exception('App já em execução');
    _running = true;
    _dbg('[MAIN] Iniciando aplicação…');

    final className = 'DartWin32AppWindowClass'.toNativeUtf16();
    final windowName = _title.toNativeUtf16();
    final msg = calloc<MSG>();

    try {
      final atom = _shim.registerClass(className);
      _dbg('[APP] registerClass atom=$atom');
      if (atom == 0) {
        throw Exception('RegisterClass (shim) falhou (GLE=${GetLastError()})');
      }

      final tid = GetCurrentThreadId();
      _hwnd = _shim.createWindowFwd(
          className, windowName, width, height, tid, _shimMsgForward);
      _dbg('[APP] createWindowFwd hwnd=$_hwnd');
      if (_hwnd == 0) {
        throw Exception(
            'CreateWindowFwd (shim) falhou (GLE=${GetLastError()})');
      }

      _appsByHWND[_hwnd] = this;
      _dbg('[MAP] HWND $_hwnd associado.');

      ShowWindow(_hwnd, SW_SHOW);
      UpdateWindow(_hwnd);

      // FORCE o primeiro frame imediatamente:
      _needsRepaint = true; // marca a flag
      InvalidateRect(_hwnd, nullptr, 0); // agenda WM_PAINT já
      PostMessage(_hwnd, WM_NULL, 0, 0); // acorda a fila (belt & suspenders)

      while (_running) {
        while (PeekMessage(msg, 0, 0, 0, PM_REMOVE) != 0) {
          final m = msg.ref;

          if (m.message == WM_QUIT) {
            _running = false;
            break;
          }

          if (m.message == _shimMsgForward) {
            _handleShimForward(m.wParam, m.lParam);
            continue;
          }

          TranslateMessage(msg);
          DispatchMessage(msg);
        }

        if (!_running) break;

        if (_created && _needsRepaint) {
          _needsRepaint = false;
          InvalidateRect(_hwnd, nullptr, 0); // deixa o WM_PAINT vir normal
        }

        await Future.delayed(const Duration(milliseconds: 8)); // ocioso leve
      }
    } catch (e, s) {
      _dbg('[FATAL] $e\n$s');
    } finally {
      if (_hwnd != 0) _shim.clearForwarding(_hwnd);
      _appsByHWND.remove(_hwnd);
      malloc.free(className);
      malloc.free(windowName);
      calloc.free(msg);
      _dbg('[MAIN] Finalizado.');
    }
  }

  // IMPORTANTE: adicione 'import "dart:io" show exit;' no topo do arquivo.

  void _handleShimForward(int wParam, int lParam) {
    final ptr = Pointer<shim.FwdMsg>.fromAddress(lParam);
    if (ptr.address == 0) return;

    try {
      final uMsg = ptr.ref.uMsg;
      final w = ptr.ref.wParam;
      final l = ptr.ref.lParam;

      switch (uMsg) {
        case WM_CREATE:
          _dbg('[APP] WM_CREATE -> onCreate()');
          _onCreate();
          _created = true;
          _needsRepaint = true;
          InvalidateRect(_hwnd, nullptr, 0);
          PostMessage(_hwnd, WM_NULL, 0, 0);
          return;

        case WM_PAINT:
          final ps = calloc<PAINTSTRUCT>();
          // ignore: unused_local_variable
          final hdc = BeginPaint(_hwnd, ps);
          try {
            if (_created) _onPaint();
          } finally {
            EndPaint(_hwnd, ps);
            calloc.free(ps);
          }
          return;

        case WM_ERASEBKGND:
          _dbg('[APP] WM_ERASEBKGND (ignorado)');
          return;

        case WM_SIZE:
          _dbg('[APP] WM_SIZE -> requestRepaint');
          if (_created) requestRepaint();
          return;

        case WM_CLOSE:
          _dbg('[APP] WM_CLOSE -> DestroyWindow');
          DestroyWindow(_hwnd);
          return;

        case WM_DESTROY:
          _dbg('[APP] WM_DESTROY -> onDestroy() + PostQuitMessage + exit(0)');
          try {
            _onDestroy();
          } catch (e, s) {
            _dbg('[ON_DESTROY] $e\n$s');
          }
          _running = false;
          PostQuitMessage(0);
          // garante que **TODOS** os isolates/timers morram:
          exit(0); // <-- encerra o processo dart
          // ignore: dead_code
          return;

        default:
          _onInput(uMsg, w, l);
          return;
      }
    } catch (e, s) {
      _dbg('[WNDPROC/DART] $e\n$s');
    } finally {
      _shim.freePacket(ptr.cast());
    }
  }

  void close() {
    if (_hwnd != 0) DestroyWindow(_hwnd);
  }

  String _msgName(int m) {
    switch (m) {
      case WM_CREATE:
        return 'WM_CREATE';
      case WM_DESTROY:
        return 'WM_DESTROY';
      case WM_CLOSE:
        return 'WM_CLOSE';
      case WM_SIZE:
        return 'WM_SIZE';
      case WM_ERASEBKGND:
        return 'WM_ERASEBKGND';
      case WM_PAINT:
        return 'WM_PAINT';
      case WM_MOUSEMOVE:
        return 'WM_MOUSEMOVE';
      case WM_LBUTTONDOWN:
        return 'WM_LBUTTONDOWN';
      case WM_LBUTTONUP:
        return 'WM_LBUTTONUP';
      case WM_RBUTTONDOWN:
        return 'WM_RBUTTONDOWN';
      case WM_RBUTTONUP:
        return 'WM_RBUTTONUP';
      case WM_KEYDOWN:
        return 'WM_KEYDOWN';
      case WM_KEYUP:
        return 'WM_KEYUP';
      case WM_CHAR:
        return 'WM_CHAR';
    }
    return '0x${m.toRadixString(16)}';
  }

  void _dbg(String msg) {
    if (debug) {
      // ignore: avoid__dbg
      print(msg);
    }
  }
}
