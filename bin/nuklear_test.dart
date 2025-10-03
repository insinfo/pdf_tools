//C:\MyDartProjects\pdf_tools\bin\nuklear_test.dart
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:convert'; // Added for UTF-8 decoding
import 'package:ffi/ffi.dart';

import 'package:pdf_tools/src/nuklear/nuklear_bindings.dart';
import 'package:pdf_tools/src/win32/win32_api.dart' as win;

// ---------------------------------------------------------
// Estado global Nuklear
// ---------------------------------------------------------
late final ffi.Pointer<nk_context> ctx;
late final ffi.Pointer<nk_font_atlas> atlas;
late final ffi.Pointer<nk_user_font> pUserFont;

// Win32 backbuffer
int gHwnd = 0; // HWND
int gMemDC = 0; // HDC
int gMemBmp = 0; // HBITMAP
int gOldBmp = 0; // HBITMAP original do gMemDC
int gBBw = 0, gBBh = 0;

void freeBackbuffer() {
  if (gMemDC != 0) {
    if (gOldBmp != 0) {
      // Restaura o bitmap original antes de deletar o DC
      win.SelectObject(gMemDC, gOldBmp);
    }
    if (gMemBmp != 0) {
      win.DeleteObject(gMemBmp);
    }
    win.DeleteDC(gMemDC);
  }
  gMemDC = 0;
  gMemBmp = 0;
  gOldBmp = 0;
  gBBw = gBBh = 0;
}

void ensureBackbuffer(int hdc) {
  final rc = calloc<win.RECT>();
  win.GetClientRect(gHwnd, rc);
  final w = rc.ref.right - rc.ref.left;
  final h = rc.ref.bottom - rc.ref.top;
  calloc.free(rc);

  if (w <= 0 || h <= 0) {
    freeBackbuffer();
    return;
  }
  if (w == gBBw && h == gBBh && gMemDC != 0 && gMemBmp != 0) return;

  freeBackbuffer();
  gMemDC = win.CreateCompatibleDC(hdc);
  gMemBmp = win.CreateCompatibleBitmap(hdc, w, h);
  gOldBmp = win.SelectObject(gMemDC, gMemBmp); // Salva o bitmap antigo
  gBBw = w;
  gBBh = h;
}

// ---------------------------------------------------------
// Nuklear init/shutdown
// ---------------------------------------------------------
late NuklearBindings nk;

void nkInitUI() {
  ctx = calloc<nk_context>();
  atlas = calloc<nk_font_atlas>();
  pUserFont = calloc<nk_user_font>();

  nk.nk_font_atlas_init_default(atlas);
  nk.nk_font_atlas_begin(atlas);

  final pFont = nk.nk_font_atlas_add_default(atlas, 13.0, ffi.nullptr);

  final pW = calloc<ffi.Int>();
  final pH = calloc<ffi.Int>();
  /*final image =*/ nk.nk_font_atlas_bake(
      atlas, pW, pH, nk_font_atlas_format.NK_FONT_ATLAS_RGBA32);

  // Aqui você normalmente criaria uma textura GDI/OpenGL com os dados de 'image'
  // Para este exemplo, ignoramos a textura, pois o GDI renderiza as fontes do sistema.

  calloc.free(pW);
  calloc.free(pH);

  final nulltex = calloc<nk_draw_null_texture>();
  // Para GDI, não precisamos de uma textura de fonte, então passamos um handle nulo.
  nk.nk_font_atlas_end(atlas, nk.nk_handle_id(0), nulltex);
  calloc.free(nulltex);

  if (pFont != ffi.nullptr) {
    pUserFont.ref = pFont.ref.handle;
    nk.nk_init_default(ctx, pUserFont);
  } else {
    // Fallback se a fonte não carregar
    nk.nk_init_default(ctx, ffi.nullptr);
  }

  // Estilo customizado
  ctx.ref.style.text.color = nk.nk_rgba(255, 255, 255, 255);
  ctx.ref.style.window.fixed_background =
      nk.nk_style_item_color(nk.nk_rgba(20, 20, 20, 255));
}

void nkShutdownUI() {
  nk.nk_font_atlas_clear(atlas);
  nk.nk_free(ctx);
  calloc.free(ctx);
  calloc.free(atlas);
  calloc.free(pUserFont);
}

// ---------------------------------------------------------
// 1 frame
// ---------------------------------------------------------
void doFrame(int hdcWin) {
  // Input (simplificado)
  nk.nk_input_begin(ctx);
  // Aqui você normalmente processaria mensagens Win32 como WM_MOUSEMOVE, WM_KEYDOWN, etc.
  // e chamaria as funções nk.nk_input_motion, nk.nk_input_button, nk.nk_input_key.
  nk.nk_input_end(ctx);

  // UI
  final r = nk.nk_rect1(40, 40, 260, 160);
  if (nk.nk_begin(ctx, 'Janela'.toNativeUtf8().cast(), r,
          nk_panel_flags.NK_WINDOW_BORDER | nk_panel_flags.NK_WINDOW_TITLE) !=
      0) {
    nk.nk_layout_row_dynamic(ctx, 28, 1);
    nk.nk_label(ctx, 'Funcional (Nuklear + GDI)'.toNativeUtf8().cast(),
        nk_text_alignment.NK_TEXT_LEFT);
  }
  nk.nk_end(ctx);

  // Render
  ensureBackbuffer(hdcWin);
  if (gMemDC == 0) return;

  // Limpa o backbuffer com a cor de fundo da janela Nuklear
  final bgColor = ctx.ref.style.window.background;
  final hb = win.CreateSolidBrush(win.RGB(bgColor.r, bgColor.g, bgColor.b));
  final rcFill = calloc<win.RECT>()
    ..ref.left = 0
    ..ref.top = 0
    ..ref.right = gBBw
    ..ref.bottom = gBBh;
  win.FillRect(gMemDC, rcFill, hb);
  win.DeleteObject(hb);
  calloc.free(rcFill);

  win.SetBkMode(gMemDC, win.TRANSPARENT);

  // Itera e desenha os comandos do Nuklear
  for (var cmd = nk.nk__begin(ctx);
      cmd.address != 0;
      cmd = nk.nk__next(ctx, cmd)) {
    if (cmd.ref.type == nk_command_type.NK_COMMAND_TEXT) {
      final t = cmd.cast<nk_command_text>();
      final textCmd = t.ref;

      final fg = textCmd.foreground;
      win.SetTextColor(gMemDC, win.RGB(fg.r, fg.g, fg.b));

      if (textCmd.length > 0) {
        // O texto (UTF-8) segue a struct na memória.
        // O offset é calculado para encontrar o início do texto.
        // NOTA: Este offset pode variar com o alinhamento/plataforma.
        // O valor 48 é calculado para uma arquitetura de 64 bits.
        const int textOffset = 48;
        final stringPtr =
            ffi.Pointer<ffi.Uint8>.fromAddress(t.address + textOffset);

        // Cria uma view Uint8List para os dados UTF-8 sem copiar.
        final utf8List = stringPtr.asTypedList(textCmd.length);

        // Decodifica para uma String Dart.
        final dartString = utf8.decode(utf8List);

        // Converte para UTF-16 para a API do Windows.
        final utf16Ptr = dartString.toNativeUtf16();

        win.TextOut(gMemDC, textCmd.x, textCmd.y, utf16Ptr, dartString.length);

        calloc.free(utf16Ptr);
      }
    }
    // Aqui você adicionaria handlers para outros tipos de comando (NK_COMMAND_RECT, etc.)
  }

  // Blit do backbuffer para a janela real
  win.BitBlt(hdcWin, 0, 0, gBBw, gBBh, gMemDC, 0, 0, win.SRCCOPY);
  nk.nk_clear(ctx);
}

// ---------------------------------------------------------
// Window Proc
// ---------------------------------------------------------
int wndProc(int hwnd, int msg, int wParam, int lParam) {
  switch (msg) {
    case win.WM_ERASEBKGND:
      return 1; // Evita que o Windows limpe o fundo (previne flicker)
    case win.WM_SIZE:
      freeBackbuffer(); // Invalida o backbuffer no redimensionamento
      win.InvalidateRect(hwnd, ffi.nullptr, 0);
      return 0;
    case win.WM_PAINT:
      final ps = calloc<win.PAINTSTRUCT>();
      final hdc = win.BeginPaint(hwnd, ps);
      doFrame(hdc);
      win.EndPaint(hwnd, ps);
      calloc.free(ps);
      return 0;
    case win.WM_DESTROY:
      win.PostQuitMessage(0);
      return 0;
  }
  return win.DefWindowProc(hwnd, msg, wParam, lParam);
}

// ---------------------------------------------------------
// main
// ---------------------------------------------------------
void main() {
  // Carrega DLL do nuklear
  final dl = ffi.DynamicLibrary.open('nuklear.dll');
  nk = NuklearBindings(dl);

  // Classe de janela
  final className = 'NuklearDartTest'.toNativeUtf16();
  final wc = calloc<win.WNDCLASSEX>()
    ..ref.cbSize = ffi.sizeOf<win.WNDCLASSEX>()
    ..ref.style = win.CS_HREDRAW | win.CS_VREDRAW
    ..ref.lpfnWndProc = ffi.Pointer.fromFunction<win.WndProc>(wndProc, 0)
    ..ref.hInstance = win.GetModuleHandle(ffi.nullptr)
    // ..ref.hCursor = win.LoadCursor(0, ffi.Pointer.fromAddress(win.IDC_ARROW))
    ..ref.hCursor = win.LoadCursor(0, win.MAKEINTRESOURCE(win.IDC_ARROW))
    ..ref.lpszClassName = className;
  win.RegisterClassEx(wc);

  // Cria janela
  gHwnd = win.CreateWindowEx(
    0,
    className,
    'Nuklear Dart Test'.toNativeUtf16(),
    win.WS_OVERLAPPEDWINDOW | win.WS_VISIBLE,
    win.CW_USEDEFAULT,
    win.CW_USEDEFAULT,
    640,
    360,
    0,
    0,
    wc.ref.hInstance,
    ffi.nullptr,
  );

  calloc.free(className);
  calloc.free(wc);

  if (gHwnd == 0) {
    stderr.writeln("Falha ao criar a janela.");
    return;
  }

  nkInitUI();

  // Loop de mensagens
  final msg = calloc<win.MSG>();
  var running = true;
  while (running) {
    // Processa todas as mensagens pendentes sem bloquear
    while (win.PeekMessage(msg, 0, 0, 0, win.PM_REMOVE) != 0) {
      if (msg.ref.message == win.WM_QUIT) {
        running = false;
        break;
      }
      win.TranslateMessage(msg);
      win.DispatchMessage(msg);
    }
    if (!running) break;

    // Redesenha a janela (se não houver outras mensagens)
    win.InvalidateRect(gHwnd, ffi.nullptr, 0);
    win.UpdateWindow(gHwnd);

    // Pequena pausa para não consumir 100% da CPU
    sleep(const Duration(milliseconds: 16));
  }

  calloc.free(msg);

  freeBackbuffer();
  nkShutdownUI();
}
