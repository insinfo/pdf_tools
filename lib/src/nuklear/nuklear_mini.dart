// ignore_for_file: deprecated_member_use

import 'dart:ffi';
import 'dart:convert';
import 'package:ffi/ffi.dart';

import 'package:pdf_tools/src/win32/win32_api.dart';
import 'package:pdf_tools/src/win32/win32_app.dart';
import 'package:pdf_tools/src/nuklear/nuklear_bindings.dart';

class NuklearMini {
  late final Win32App _app;
  late final NuklearBindings _nk;
  Pointer<nk_context> _ctx = nullptr;
  Pointer<nk_font_atlas> _atlas = nullptr;
  Pointer<nk_user_font> _uf = nullptr;
  int _frame = 0;

  int _memDC = 0, _memBmp = 0, _oldBmp = 0, _bbW = 0, _bbH = 0;

  NuklearMini({required String title, int width = 600, int height = 400}) {
    _app = Win32App(
      title: title,
      width: width,
      height: height,
      onCreate: _onCreate,
      onPaint: _onPaint,
      onInput: (a, b, c) {},
      onDestroy: _onDestroy,
    );
  }

  Future<void> run() => _app.run();

  void _onCreate() {
    print('[INIT] carregando nuklear.dll…');
    final dl = DynamicLibrary.open('nuklear.dll');
    _nk = NuklearBindings(dl);
    _ctx = calloc<nk_context>();
    _atlas = calloc<nk_font_atlas>();
    _uf = calloc<nk_user_font>();

    _nk.nk_font_atlas_init_default(_atlas);
    _nk.nk_font_atlas_begin(_atlas);
    final font = _nk.nk_font_atlas_add_default(_atlas, 13.0, nullptr);
    final w = calloc<Int>(), h = calloc<Int>();
    _nk.nk_font_atlas_bake(
        _atlas, w, h, nk_font_atlas_format.NK_FONT_ATLAS_RGBA32);
    print('[INIT] atlas: ${w.value}x${h.value}');
    calloc.free(w);
    calloc.free(h);
    final nt = calloc<nk_draw_null_texture>();
    _nk.nk_font_atlas_end(_atlas, _nk.nk_handle_id(0), nt);
    calloc.free(nt);

    if (font != nullptr) _uf.ref = font.ref.handle;
    final ok = _nk.nk_init_default(_ctx, _uf);
    if (ok == 0) throw Exception('nk_init_default falhou');
    print('[INIT] nk_init_default OK');
    _ctx.ref.style.text.color = _nk.nk_rgba(255, 255, 255, 255);
    _ctx.ref.style.window.fixed_background =
        _nk.nk_style_item_color(_nk.nk_rgba(32, 32, 32, 255));
  }

  void _onPaint() {
    try {
      _nk.nk_input_begin(_ctx);
      _nk.nk_input_end(_ctx);

      if (_nk.nk_begin(
              _ctx,
              'Mini'.toNativeUtf8().cast(),
              _nk.nk_rect1(20, 20, 260, 120),
              nk_panel_flags.NK_WINDOW_BORDER |
                  nk_panel_flags.NK_WINDOW_TITLE) !=
          0) {
        _nk.nk_layout_row_dynamic(_ctx, 28, 1);
        _nk.nk_label(_ctx, 'Teste Funcional!'.toNativeUtf8().cast(),
            nk_text_alignment.NK_TEXT_LEFT);
      }
      _nk.nk_end(_ctx);

      final ps = calloc<PAINTSTRUCT>();
      final hdcWin = BeginPaint(_app.hwnd, ps);

      // Backbuffer (elimina flicker)
      _ensureBackbuffer(hdcWin);
      if (_memDC == 0) {
        EndPaint(_app.hwnd, ps);
        calloc.free(ps);
        return;
      }

      // fundo
      final rc = calloc<RECT>();
      GetClientRect(_app.hwnd, rc);
      final bg = _ctx.ref.style.window.background;
      final brush = CreateSolidBrush((bg.b) | (bg.g << 8) | (bg.r << 16));
      FillRect(_memDC, rc, brush);
      DeleteObject(brush);
      calloc.free(rc);

      SetBkMode(_memDC, TRANSPARENT);

      // render dos comandos (corrigido o offset da string)
      for (var cmd = _nk.nk__begin(_ctx);
          cmd.address != 0;
          cmd = _nk.nk__next(_ctx, cmd)) {
        switch (cmd.ref.type) {
          case nk_command_type.NK_COMMAND_TEXT:
            {
              final t = cmd.cast<nk_command_text>();
              final textCmd = t.ref;

              final fg = textCmd.foreground;
              SetTextColor(_memDC, RGB(fg.r, fg.g, fg.b));

              if (textCmd.length > 0) {
                // O texto (UTF-8) segue a struct na memória.
                // O offset é calculado para encontrar o início do texto.
                // NOTA: Este offset pode variar com o alinhamento/plataforma.
                // O valor 48 é calculado para uma arquitetura de 64 bits.
                const int textOffset = 48;
                final stringPtr =
                    Pointer<Uint8>.fromAddress(t.address + textOffset);
                // Cria uma view Uint8List para os dados UTF-8 sem copiar.
                final utf8List = stringPtr.asTypedList(textCmd.length);
                // Decodifica para uma String Dart.
                final dartString = utf8.decode(utf8List);
                // Converte para UTF-16 para a API do Windows.
                final utf16Ptr = dartString.toNativeUtf16();
                TextOut(
                    _memDC, textCmd.x, textCmd.y, utf16Ptr, dartString.length);
                calloc.free(utf16Ptr);
              }
              break;
            }

          case nk_command_type.NK_COMMAND_RECT_FILLED:
            final rf = cmd.cast<nk_command_rect_filled>().ref;
            final hBrush = CreateSolidBrush(
                (rf.color.b) | (rf.color.g << 8) | (rf.color.r << 16));
            final r = calloc<RECT>()
              ..ref.left = rf.x
              ..ref.top = rf.y
              ..ref.right = rf.x + rf.w
              ..ref.bottom = rf.y + rf.h;
            FillRect(_memDC, r, hBrush);
            DeleteObject(hBrush);
            calloc.free(r);
            break;

          case nk_command_type.NK_COMMAND_RECT:
            final rc2 = cmd.cast<nk_command_rect>().ref;
            final pen = CreatePen(PS_SOLID, rc2.line_thickness,
                (rc2.color.b) | (rc2.color.g << 8) | (rc2.color.r << 16));
            final oldPen = SelectObject(_memDC, pen);
            final oldBrush = SelectObject(_memDC, GetStockObject(HOLLOW_BRUSH));
            Rectangle(_memDC, rc2.x, rc2.y, rc2.x + rc2.w, rc2.y + rc2.h);
            SelectObject(_memDC, oldPen);
            SelectObject(_memDC, oldBrush);
            DeleteObject(pen);
            break;

          // case nk_command_type.NK_COMMAND_SCISSOR:
          //   {
          //     final sc = cmd.cast<nk_command_scissor>().ref;
          //     SelectClipRgn(_memDC, 0); // zera
          //     IntersectClipRect(_memDC, sc.x, sc.y, sc.x + sc.w, sc.y + sc.h);
          //     break;
          //   }
        }
      }

      // blit para a janela de uma vez (suave)
      BitBlt(hdcWin, 0, 0, _bbW, _bbH, _memDC, 0, 0, SRCCOPY);

      EndPaint(_app.hwnd, ps);
      calloc.free(ps);
      _nk.nk_clear(_ctx);

      if (++_frame % 60 == 0) print('[mini] frame=$_frame');
    } catch (e, s) {
      print('[PAINT] exceção: $e\n$s');
    }
  }

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
      _freeBackbuffer();
      return;
    }
    if (_memDC != 0 && _memBmp != 0 && w == _bbW && h == _bbH) return;

    _freeBackbuffer();
    _memDC = CreateCompatibleDC(hdcWin);
    _memBmp = CreateCompatibleBitmap(hdcWin, w, h);
    _oldBmp = SelectObject(_memDC, _memBmp);
    _bbW = w;
    _bbH = h;
  }

// --- helper robusto para ler o texto do comando ---
  String readNkText(Pointer<nk_command_text> p) {
    final len = p.ref.length;
    if (len <= 0) return '';
    const guardBytes = 2; // porque em C é char string[2]
    final start = sizeOf<nk_command_text>() - guardBytes;
    final u8 = p.cast<Uint8>().elementAt(start);
    final bytes = u8.asTypedList(len);
    // evita exceção caso venha byte fora do padrão em algum frame
    return const Utf8Decoder(allowMalformed: true).convert(bytes);
  }

  void _onDestroy() {
    print('[CLEANUP] liberando recursos…');
    _freeBackbuffer();
    if (_ctx.address != 0) {
      _nk.nk_free(_ctx);
      calloc.free(_ctx);
    }
    if (_atlas.address != 0) {
      _nk.nk_font_atlas_clear(_atlas);
      calloc.free(_atlas);
    }
    if (_uf.address != 0) {
      calloc.free(_uf);
    }
  }
}
