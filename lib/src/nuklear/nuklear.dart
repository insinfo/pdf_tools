// ignore_for_file: camel_case_types, non_constant_identifier_names, constant_identifier_names, curly_braces_in_flow_control_structures, unused_local_variable
// Nuklear: wrapper de alto nível (GDI)
import 'dart:convert';

import '../win32/win32_api.dart';
import '../win32/win32_app.dart';
import 'nuklear_bindings.dart';

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

extension NuklearBindingsExtras on NuklearBindings {
  int nk_cmd_text_off_string() => nk_cmd_text_off_string();

  /// Lê os `length` bytes do comando e decodifica como UTF-8.
  String nkReadCommandTextUtf8(Pointer<nk_command_text> t) {
    final len = t.ref.length;
    if (len <= 0) return '';
    final pointer = nk_cmd_text_ptr(t); // direto da DLL (sem offset)
    final bytes = pointer.cast<Uint8>().asTypedList(len);
    return utf8.decode(bytes);
  }

  /// Alternativa usando offset (útil se você preferir computar o ponteiro manualmente).
  String nkReadCommandTextUtf8ViaOffset(Pointer<nk_command_text> t) {
    final len = t.ref.length;
    if (len <= 0) return '';
    final off = nk_cmd_text_off_string();
    final base = Pointer<Uint8>.fromAddress(t.address + off);
    final bytes = base.asTypedList(len);
    return utf8.decode(bytes);
  }
}

class Nuklear {
  // --- dependências/estado base ---
  late final Win32App _app;
  late final NuklearBindings _nk;
  final void Function(Nuklear nk) _builder;

  final bool _debug;

  Pointer<nk_font_atlas> _atlas = nullptr;
  Pointer<nk_font> _font = nullptr;
  Pointer<nk_user_font> _fontHandle = nullptr;
  Pointer<nk_context> _ctx = nullptr;

  // --- [CORREÇÃO] Variáveis para o double-buffer ---
  int _memDC = 0, _memBmp = 0, _oldBmp = 0, _bbW = 0, _bbH = 0;

  final _inputQueue = <(int, int, int)>[];

  int width;
  int height;

  Nuklear({
    required String title,
    required this.width,
    required this.height,
    required void Function(Nuklear nk) builder,
    bool debug = false,
  })  : _builder = builder,
        _debug = debug {
    _app = Win32App(
      debug: debug,
      title: title,
      width: width,
      height: height,
      onCreate: _initializeNuklear,
      onPaint: _renderFrame,
      onInput: _handleNuklearInput,
      onDestroy: _cleanup,
    );
  }

  Future<void> run() => _app.run();
  void close() => _app.close();

  // Callbacks Win32App

  void _initializeNuklear() {
    _dbg('[NK] carrega nuklear.dll…');
    final dylib = DynamicLibrary.open('nuklear.dll');
    _nk = NuklearBindings(dylib);

    _ctx = calloc<nk_context>();
    _atlas = calloc<nk_font_atlas>();
    _dbg('[NK] ctx=${_ctx.address} atlas=${_atlas.address}');

    _nk.nk_font_atlas_init_default(_atlas);
    _nk.nk_font_atlas_begin(_atlas);

    _font = _nk.nk_font_atlas_add_default(_atlas, 13.0, nullptr);
    _dbg('[NK] font=${_font.address}');

    final w = calloc<Int>(), h = calloc<Int>();
    _nk.nk_font_atlas_bake(
        _atlas, w, h, nk_font_atlas_format.NK_FONT_ATLAS_RGBA32);
    _dbg('[NK] atlas baked ${w.value}x${h.value}');
    calloc.free(w);
    calloc.free(h);

    final nullTex = calloc<nk_draw_null_texture>();
    _nk.nk_font_atlas_end(_atlas, _nk.nk_handle_id(0), nullTex);
    calloc.free(nullTex);

    _fontHandle = calloc<nk_user_font>();
    if (_font != nullptr) _fontHandle.ref = _font.ref.handle;

    final ok = _nk.nk_init_default(_ctx, _fontHandle);
    _dbg('[NK] nk_init_default -> $ok');
    if (ok == 0) throw Exception('nk_init_default falhou');
  }

  void _renderFrame() {
    _processInputQueue();

    final hdcWin = GetDC(_app.hwnd);
   // _dbg('[NK] _renderFrame: hdcWin=$hdcWin');
    try {
      _ensureBackbuffer(hdcWin);
      if (_memDC == 0) {
        // _dbg('[NK] _memDC==0 -> skip');
        return;
      }

      final hdc = _memDC;

      // fundo
      final rect = calloc<RECT>();
      GetClientRect(_app.hwnd, rect);
      final bg = _ctx.ref.style.window.background;
      final hBrush = CreateSolidBrush(_rgbaToColorref(bg));
      FillRect(hdc, rect, hBrush);
      DeleteObject(hBrush);
      calloc.free(rect);

      SetBkMode(hdc, TRANSPARENT);

      // _dbg('[NK] builder start');
      _builder(this); // <- GARANTA que chama begin()/end() aqui
      //_dbg('[NK] builder end');

      final cmdsBefore = _nk.nk__begin(_ctx);
      if (cmdsBefore.address == 0) {
        _dbg(
            '[NK] WARNING: nk__begin retornou null (sem comandos). Sanity paint…');
        // SANITY PAINT: desenhar algo com GDI para testar pipeline
        final pen = CreatePen(PS_SOLID, 2, RGB(255, 0, 0));
        final oldPen = SelectObject(hdc, pen);
        Rectangle(hdc, 10, 10, 200, 100);
        SelectObject(hdc, oldPen);
        DeleteObject(pen);
      }
      // Renderiza
      _renderNuklearToGDI(hdc);
      _nk.nk_clear(_ctx);

      // Blit
      BitBlt(hdcWin, 0, 0, _bbW, _bbH, _memDC, 0, 0, SRCCOPY);
      //_dbg('[NK] BitBlt done ${_bbW}x$_bbH');
    } finally {
      ReleaseDC(_app.hwnd, hdcWin);
    }
  }

  void _processInputQueue() {
    _nk.nk_input_begin(_ctx);

    int processed = 0;
    for (final (uMsg, wParam, lParam) in _inputQueue) {
      switch (uMsg) {
        case WM_MOUSEMOVE:
          _nk.nk_input_motion(_ctx, LOWORD(lParam), HIWORD(lParam));
          break;
        case WM_LBUTTONDOWN:
          _nk.nk_input_button(_ctx, nk_buttons.NK_BUTTON_LEFT, LOWORD(lParam),
              HIWORD(lParam), 1);
          break;
        case WM_LBUTTONUP:
          _nk.nk_input_button(_ctx, nk_buttons.NK_BUTTON_LEFT, LOWORD(lParam),
              HIWORD(lParam), 0);
          break;
        case WM_RBUTTONDOWN:
          _nk.nk_input_button(_ctx, nk_buttons.NK_BUTTON_RIGHT, LOWORD(lParam),
              HIWORD(lParam), 1);
          break;
        case WM_RBUTTONUP:
          _nk.nk_input_button(_ctx, nk_buttons.NK_BUTTON_RIGHT, LOWORD(lParam),
              HIWORD(lParam), 0);
          break;
        case WM_MBUTTONDOWN:
          _nk.nk_input_button(_ctx, nk_buttons.NK_BUTTON_MIDDLE, LOWORD(lParam),
              HIWORD(lParam), 1);
          break;
        case WM_MBUTTONUP:
          _nk.nk_input_button(_ctx, nk_buttons.NK_BUTTON_MIDDLE, LOWORD(lParam),
              HIWORD(lParam), 0);
          break;
        case WM_MOUSEWHEEL:
          final delta = GET_WHEEL_DELTA_WPARAM(wParam);
          final scrollVec = calloc<nk_vec2>()
            ..ref.y = (delta / 120.0).toDouble();
          _nk.nk_input_scroll(_ctx, scrollVec.ref);
          calloc.free(scrollVec);
          break;
        case WM_CHAR:
          _nk.nk_input_unicode(_ctx, wParam);
          break;
        case WM_KEYDOWN:
        case WM_KEYUP:
          final isDown = (uMsg == WM_KEYDOWN) ? 1 : 0;
          switch (wParam) {
            case VK_SHIFT:
              _nk.nk_input_key(_ctx, nk_keys.NK_KEY_SHIFT, isDown);
              break;
            case VK_CONTROL:
              _nk.nk_input_key(_ctx, nk_keys.NK_KEY_CTRL, isDown);
              break;
            case VK_DELETE:
              _nk.nk_input_key(_ctx, nk_keys.NK_KEY_DEL, isDown);
              break;
            case VK_RETURN:
              _nk.nk_input_key(_ctx, nk_keys.NK_KEY_ENTER, isDown);
              break;
            case VK_BACK:
              _nk.nk_input_key(_ctx, nk_keys.NK_KEY_BACKSPACE, isDown);
              break;
            case VK_LEFT:
              _nk.nk_input_key(_ctx, nk_keys.NK_KEY_LEFT, isDown);
              break;
            case VK_RIGHT:
              _nk.nk_input_key(_ctx, nk_keys.NK_KEY_RIGHT, isDown);
              break;
          }
          break;
      }
      processed++;
    }
    if (processed > 0 && _debug)
      //_dbg('[INPUT] eventos processados: $processed');

    _inputQueue.clear();
    _nk.nk_input_end(_ctx);
  }

  void _handleNuklearInput(int uMsg, int wParam, int lParam) {
    // Só repassamos pro Nuklear o que ele realmente entende.
    switch (uMsg) {
      case WM_MOUSEMOVE:
      case WM_LBUTTONDOWN:
      case WM_LBUTTONUP:
      case WM_RBUTTONDOWN:
      case WM_RBUTTONUP:
      case WM_MBUTTONDOWN:
      case WM_MBUTTONUP:
      case WM_MOUSEWHEEL:
      case WM_CHAR:
      case WM_KEYDOWN:
      case WM_KEYUP:
      case WM_SIZE:
        _inputQueue.add((uMsg, wParam, lParam));
        _app.requestRepaint(); // repinta apenas quando há input relevante
        break;
      default:
        // IGNORA todo o resto (WM_SETCURSOR, WM_NCHITTEST, WM_GETMINMAXINFO, etc.)
        break;
    }
  }

  void _cleanup() {
    _freeBackbuffer();

    if (_ctx.address != 0) {
      _nk.nk_free(_ctx);
      calloc.free(_ctx);
      _ctx = nullptr;
    }
    if (_atlas.address != 0) {
      _nk.nk_font_atlas_clear(_atlas);
      calloc.free(_atlas);
      _atlas = nullptr;
    }
    if (_fontHandle.address != 0) {
      calloc.free(_fontHandle);
      _fontHandle = nullptr;
    }
  }

  // Funções de gerenciamento do Backbuffer
  void _freeBackbuffer() {
    if (_memDC != 0) {
      if (_oldBmp != 0) SelectObject(_memDC, _oldBmp);
      if (_memBmp != 0) DeleteObject(_memBmp);
      DeleteDC(_memDC);
    }
    _memDC = _memBmp = _oldBmp = 0;
    _bbW = _bbH = 0;
  }

  void _ensureBackbuffer(int hdcWin) {
    final rc = calloc<RECT>();
    GetClientRect(_app.hwnd, rc);
    final w = rc.ref.right - rc.ref.left;
    final h = rc.ref.bottom - rc.ref.top;
    calloc.free(rc);

    if (w <= 0 || h <= 0) {
      if (_memDC != 0) _dbg('[NK] backbuffer free (client size $w x $h)');
      _freeBackbuffer();
      return;
    }

    if (_memDC != 0 && _memBmp != 0 && w == _bbW && h == _bbH) return;

    _dbg('[NK] backbuffer (re)create: $w x $h');
    _freeBackbuffer();
    _memDC = CreateCompatibleDC(hdcWin);
    _memBmp = CreateCompatibleBitmap(hdcWin, w, h);
    _oldBmp = SelectObject(_memDC, _memBmp);
    _bbW = w;
    _bbH = h;
    _dbg('[NK] memDC=$_memDC memBmp=$_memBmp oldBmp=$_oldBmp');
  }

  // Renderizador GDI

  int _rgbaToColorref(nk_color c) => (c.b) | (c.g << 8) | (c.r << 16);

  void _renderNuklearToGDI(int hdc) {
    // _frame++;
    int nText = 0, nRect = 0, nRectFilled = 0, nLine = 0, nTri = 0, nCirc = 0;

    int nScissor = 0;
    // int nRect = 0;
    // int nRectFilled = 0;
    // int nText = 0;

    final savedDC = SaveDC(hdc);
    try {
      for (var cmd = _nk.nk__begin(_ctx);
          cmd.address != 0;
          cmd = _nk.nk__next(_ctx, cmd)) {
        switch (cmd.ref.type) {
          case nk_command_type.NK_COMMAND_SCISSOR:
            final sc = cmd.cast<nk_command_scissor>().ref;
            SelectClipRgn(hdc, 0);
            IntersectClipRect(hdc, sc.x, sc.y, sc.x + sc.w, sc.y + sc.h);
            nScissor++;
            break;

          case nk_command_type.NK_COMMAND_RECT:
            final rc = cmd.cast<nk_command_rect>().ref;
            final pen = CreatePen(
                PS_SOLID, rc.line_thickness, _rgbaToColorref(rc.color));
            final oldPen = SelectObject(hdc, pen);
            final oldBrush = SelectObject(hdc, GetStockObject(HOLLOW_BRUSH));
            Rectangle(hdc, rc.x, rc.y, rc.x + rc.w, rc.y + rc.h);
            SelectObject(hdc, oldPen);
            SelectObject(hdc, oldBrush);
            DeleteObject(pen);
            nRect++;
            break;

          case nk_command_type.NK_COMMAND_RECT_FILLED:
            final rf = cmd.cast<nk_command_rect_filled>().ref;
            final hBrush = CreateSolidBrush(_rgbaToColorref(rf.color));
            final r = calloc<RECT>()
              ..ref.left = rf.x
              ..ref.top = rf.y
              ..ref.right = rf.x + rf.w
              ..ref.bottom = rf.y + rf.h;
            FillRect(hdc, r, hBrush);
            DeleteObject(hBrush);
            calloc.free(r);
            nRectFilled++;
            break;

          case nk_command_type.NK_COMMAND_TEXT:
            final t = cmd.cast<nk_command_text>();
            final textCmd = t.ref;
            final fg = textCmd.foreground;
            SetTextColor(hdc, RGB(fg.r, fg.g, fg.b));

            if (textCmd.length > 0) {
              // O valor 48 é um deslocamento fixo calculado para a estrutura  nk_command_text  arquitetura de 64 bits.
              // const int textOffset = 48;
              // final stringPtr = Pointer<Uint8>.fromAddress(t.address + textOffset);
              // final utf8List = stringPtr.asTypedList(textCmd.length);
              // final dartString = utf8.decode(utf8List);
              final dartString = _nk.nkReadCommandTextUtf8(t);
              final utf16Ptr = dartString.toNativeUtf16();
              TextOut(hdc, textCmd.x, textCmd.y, utf16Ptr, dartString.length);
              calloc.free(utf16Ptr);
            }
            nText++;
            break;

          case nk_command_type.NK_COMMAND_LINE:
            final ln = cmd.cast<nk_command_line>().ref;
            final pen = CreatePen(
                PS_SOLID, ln.line_thickness, _rgbaToColorref(ln.color));
            final oldPen = SelectObject(hdc, pen);
            MoveToEx(hdc, ln.begin.x, ln.begin.y, nullptr);
            LineTo(hdc, ln.end.x, ln.end.y);
            SelectObject(hdc, oldPen);
            DeleteObject(pen);
            nLine++;
            break;

          case nk_command_type.NK_COMMAND_TRIANGLE_FILLED:
            final t = cmd.cast<nk_command_triangle_filled>().ref;
            final brush = CreateSolidBrush(_rgbaToColorref(t.color));
            final oldBrush = SelectObject(hdc, brush);
            final points = calloc<POINT>(3);
            points[0].x = t.a.x;
            points[0].y = t.a.y;
            points[1].x = t.b.x;
            points[1].y = t.b.y;
            points[2].x = t.c.x;
            points[2].y = t.c.y;
            Polygon(hdc, points, 3);
            SelectObject(hdc, oldBrush);
            DeleteObject(brush);
            calloc.free(points);
            nTri++;
            break;

          case nk_command_type.NK_COMMAND_CIRCLE_FILLED:
            final c = cmd.cast<nk_command_circle_filled>().ref;
            final brush = CreateSolidBrush(_rgbaToColorref(c.color));
            final pen = CreatePen(PS_SOLID, 1, _rgbaToColorref(c.color));
            final oldBrush = SelectObject(hdc, brush);
            final oldPen = SelectObject(hdc, pen);
            Ellipse(hdc, c.x, c.y, c.x + c.w, c.y + c.h);
            SelectObject(hdc, oldBrush);
            SelectObject(hdc, oldPen);
            DeleteObject(brush);
            DeleteObject(pen);
            nCirc++;
            break;
        }
      }
    } finally {
      RestoreDC(hdc, savedDC);
    }

    // _dbg(
    //     '[NK] cmds: SC=$nScissor TF=$nText RF=$nRectFilled R=$nRect L=$nLine TR=$nTri C=$nCirc');
  }

  void requestRepaint() {
    _app.requestRepaint();
  }

  // Widgets de alto nível (sem alterações)

  bool begin(String title,
      {required double x,
      required double y,
      required double width,
      required double height,
      int flags = 0}) {
    final titlePtr = title.toNativeUtf8();
    final bounds = _nk.nk_rect1(x, y, width, height);
    final result = _nk.nk_begin(_ctx, titlePtr.cast(), bounds, flags);
    calloc.free(titlePtr);
    // if (_debug && _frame % 60 == 0) {
    //   _dbg('[BEGIN] "$title" => ${result != 0 ? 'visible' : 'hidden'}');
    // }
    return result != 0;
  }

  void end() => _nk.nk_end(_ctx);

  bool groupBegin(String title, {int flags = 0}) {
    final titlePtr = title.toNativeUtf8();
    final result = _nk.nk_group_begin(_ctx, titlePtr.cast(), flags);
    calloc.free(titlePtr);
    return result != 0;
  }

  void groupEnd() => _nk.nk_group_end(_ctx);

  void layoutRowDynamic({double height = 30, int columns = 1}) =>
      _nk.nk_layout_row_dynamic(_ctx, height, columns);

  void spacing(int columns) => _nk.nk_spacing(_ctx, columns);

  void label(String text, {int alignment = nk_text_alignment.NK_TEXT_LEFT}) {
    final textPtr = text.toNativeUtf8();
    _nk.nk_label(_ctx, textPtr.cast(), alignment);
    calloc.free(textPtr);
  }

  bool button(String text) {
    final textPtr = text.toNativeUtf8();
    final result = _nk.nk_button_label(_ctx, textPtr.cast());
    calloc.free(textPtr);
    return result != 0;
  }

  int combo(String currentItem, double popupHeight, List<String> items) {
    int selectedIndex = items.indexOf(currentItem);
    final size = calloc<nk_vec2>()
      ..ref.x = 400
      ..ref.y = popupHeight;
    final labelPtr = currentItem.toNativeUtf8();

    if (_nk.nk_combo_begin_label(_ctx, labelPtr.cast(), size.ref) != 0) {
      bool shouldClose = false;
      layoutRowDynamic(height: 25, columns: 1);

      for (int i = 0; i < items.length; i++) {
        final itemPtr = items[i].toNativeUtf8();
        final clicked = _nk.nk_combo_item_label(
            _ctx, itemPtr.cast(), nk_text_alignment.NK_TEXT_LEFT);
        calloc.free(itemPtr);

        if (clicked != 0) {
          selectedIndex = i;
          shouldClose = true;
        }
      }

      if (shouldClose) {
        _nk.nk_combo_close(_ctx);
      }
      _nk.nk_combo_end(_ctx);
    }

    calloc.free(size);
    calloc.free(labelPtr);
    return selectedIndex;
  }

  void propertyInt(String name,
      {required int min,
      required TextEditingController controller,
      required int max,
      required int step,
      required double incPerPixel}) {
    final namePtr = name.toNativeUtf8();
    final value = int.tryParse(controller.text) ?? min;
    final valuePtr = calloc<Int32>()..value = value;
    _nk.nk_property_int(
        _ctx, namePtr.cast(), min, valuePtr.cast(), max, step, incPerPixel);
    if (valuePtr.value != value) controller.text = valuePtr.value.toString();
    calloc.free(namePtr);
    calloc.free(valuePtr);
  }

  void progress(int currentValue, int max) {
    final progressPtr = calloc<nk_size>()..value = currentValue;
    _nk.nk_progress(_ctx, progressPtr, max, 0); // 0 = not modifiable
    calloc.free(progressPtr);
  }

  int editString(int flags, TextEditingController controller) {
    const maxLen = 256;
    final bufferPtr = calloc<Uint8>(maxLen);
    final initialText = controller.text.toNativeUtf8();
    final initialBytes =
        initialText.cast<Uint8>().asTypedList(initialText.length);
    if (initialBytes.length < maxLen) {
      bufferPtr.asTypedList(maxLen).setAll(0, initialBytes);
    }
    calloc.free(initialText);

    final lengthPtr = calloc<Int32>()..value = initialBytes.length;
    final result = _nk.nk_edit_string(
        _ctx, flags, bufferPtr.cast(), lengthPtr.cast(), maxLen, nullptr);

    final newLength = lengthPtr.value;
    controller.text = bufferPtr.cast<Utf8>().toDartString(length: newLength);
    calloc.free(bufferPtr);
    calloc.free(lengthPtr);
    return result;
  }

  String? showOpenFileDialog(
      {String title = 'Abrir',
      String filter = 'Todos os Arquivos\x00*.*\x00'}) {
    final ofn = calloc<OPENFILENAMEW>();
    final filePtr = calloc<Uint16>(MAX_PATH).cast<Utf16>();
    final titlePtr = title.toNativeUtf16();
    final filterPtr = filter.toNativeUtf16();
    try {
      ofn.ref
        ..lStructSize = sizeOf<OPENFILENAMEW>()
        ..hwndOwner = _app.hwnd
        ..lpstrFile = filePtr
        ..nMaxFile = MAX_PATH
        ..lpstrTitle = titlePtr
        ..lpstrFilter = filterPtr
        ..Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_NOCHANGEDIR;
      if (GetOpenFileName(ofn) != 0) return filePtr.toDartString();
    } finally {
      calloc.free(ofn);
      calloc.free(filePtr);
      calloc.free(titlePtr);
      calloc.free(filterPtr);
    }
    return null;
  }

  String? showOpenFolderDialog({String title = 'Selecionar Pasta'}) {
    final path = showOpenFileDialog(title: title);
    return path != null ? p.dirname(path) : null;
  }

  // Util
  void _dbg(String msg) {
    if (_debug) {
      // ignore: avoid__dbg
      print(msg);
    }
  }
}

// Controller simples para compatibilidade com a API
class TextEditingController {
  String text;
  TextEditingController({this.text = ''});
}
