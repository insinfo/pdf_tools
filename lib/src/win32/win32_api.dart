// ignore_for_file: camel_case_types, non_constant_identifier_names, constant_identifier_names

import 'dart:ffi';

import 'package:ffi/ffi.dart';

final user32 = DynamicLibrary.open('user32.dll');
final kernel32 = DynamicLibrary.open('kernel32.dll');
final gdi32 = DynamicLibrary.open('gdi32.dll');
final comdlg32 = DynamicLibrary.open('comdlg32.dll');
final shell32 = DynamicLibrary.open('shell32.dll');

final msvcrt = DynamicLibrary.process();

typedef _memcpyC = Pointer<Void> Function(
    Pointer<Void> dst, Pointer<Void> src, IntPtr size);
typedef _memcpyD = Pointer<Void> Function(
    Pointer<Void> dst, Pointer<Void> src, int size);

final memcpy =
    msvcrt.lookupFunction<_memcpyC, _memcpyD>('memcpy', isLeaf: true);

// ### Typedefs de Funções ###
typedef WndProc = IntPtr Function(
    IntPtr hwnd, Uint32 uMsg, IntPtr wParam, IntPtr lParam);

typedef WindowProcDart = int Function(
    int hwnd, int msg, int wParam, int lParam);

// ### Estruturas (Structs) ###
final class WNDCLASSEX extends Struct {
  @Uint32()
  external int cbSize;
  @Uint32()
  external int style;
  external Pointer<NativeFunction<WndProc>> lpfnWndProc;
  @Int32()
  external int cbClsExtra;
  @Int32()
  external int cbWndExtra;
  @IntPtr()
  external int hInstance;
  @IntPtr()
  external int hIcon;
  @IntPtr()
  external int hCursor;
  @IntPtr()
  external int hbrBackground;
  external Pointer<Utf16> lpszMenuName;
  external Pointer<Utf16> lpszClassName;
  @IntPtr()
  external int hIconSm;
}

final class RECT extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

final class POINT extends Struct {
  @Int32()
  external int x;
  @Int32()
  external int y;
}

final class MSG extends Struct {
  @IntPtr()
  external int hwnd;
  @Uint32()
  external int message;
  @IntPtr()
  external int wParam;
  @IntPtr()
  external int lParam;
  @Uint32()
  external int time;
  external POINT pt;
}

final class PAINTSTRUCT extends Struct {
  @IntPtr()
  external int hdc;
  @Int32()
  external int fErase;
  external RECT rcPaint;
  @Int32()
  external int fRestore;
  @Int32()
  external int fIncUpdate;
  @Array(32)
  external Array<Uint8> rgbReserved;
}

final class OPENFILENAMEW extends Struct {
  @Uint32()
  external int lStructSize;
  @IntPtr()
  external int hwndOwner;
  @IntPtr()
  external int hInstance;
  external Pointer<Utf16> lpstrFilter;
  external Pointer<Utf16> lpstrCustomFilter;
  @Uint32()
  external int nMaxCustFilter;
  @Uint32()
  external int nFilterIndex;
  external Pointer<Utf16> lpstrFile;
  @Uint32()
  external int nMaxFile;
  external Pointer<Utf16> lpstrFileTitle;
  @Uint32()
  external int nMaxFileTitle;
  external Pointer<Utf16> lpstrInitialDir;
  external Pointer<Utf16> lpstrTitle;
  @Uint32()
  external int Flags;
  @Uint16()
  external int nFileOffset;
  @Uint16()
  external int nFileExtension;
  external Pointer<Utf16> lpstrDefExt;
  @IntPtr()
  external int lCustData;
  external Pointer<NativeFunction> lpfnHook;
  external Pointer<Utf16> lpTemplateName;
  external Pointer<Void> pvReserved;
  @Uint32()
  external int dwReserved;
  @Uint32()
  external int FlagsEx;
}

// ### Funções da API ###

final GetLastError = kernel32
    .lookup<NativeFunction<Uint32 Function()>>('GetLastError')
    .asFunction<int Function()>();

final GetCurrentThreadId = kernel32
    .lookup<NativeFunction<Uint32 Function()>>('GetCurrentThreadId')
    .asFunction<int Function()>();

final GetModuleHandle = kernel32
    .lookup<NativeFunction<IntPtr Function(Pointer<Utf16>)>>('GetModuleHandleW')
    .asFunction<int Function(Pointer<Utf16>)>();

final RegisterClassEx = user32
    .lookup<NativeFunction<Uint16 Function(Pointer<WNDCLASSEX>)>>(
        'RegisterClassExW')
    .asFunction<int Function(Pointer<WNDCLASSEX>)>();

final CreateWindowEx = user32
    .lookup<
        NativeFunction<
            IntPtr Function(
                Uint32,
                Pointer<Utf16>,
                Pointer<Utf16>,
                Uint32,
                Int32,
                Int32,
                Int32,
                Int32,
                IntPtr,
                IntPtr,
                IntPtr,
                Pointer<Void>)>>('CreateWindowExW')
    .asFunction<
        int Function(int, Pointer<Utf16>, Pointer<Utf16>, int, int, int, int,
            int, int, int, int, Pointer<Void>)>();

final ShowWindow = user32
    .lookup<NativeFunction<Int32 Function(IntPtr, Int32)>>('ShowWindow')
    .asFunction<int Function(int, int)>();

final UpdateWindow = user32
    .lookup<NativeFunction<Int32 Function(IntPtr)>>('UpdateWindow')
    .asFunction<int Function(int)>();

final GetMessage = user32
    .lookup<
        NativeFunction<
            Int32 Function(
                Pointer<MSG>, IntPtr, Uint32, Uint32)>>('GetMessageW')
    .asFunction<int Function(Pointer<MSG>, int, int, int)>();

final PeekMessage = user32
    .lookup<
        NativeFunction<
            Int32 Function(
                Pointer<MSG>, IntPtr, Uint32, Uint32, Uint32)>>('PeekMessageW')
    .asFunction<int Function(Pointer<MSG>, int, int, int, int)>();

final TranslateMessage = user32
    .lookup<NativeFunction<Int32 Function(Pointer<MSG>)>>('TranslateMessage')
    .asFunction<int Function(Pointer<MSG>)>();

final DispatchMessage = user32
    .lookup<NativeFunction<IntPtr Function(Pointer<MSG>)>>('DispatchMessageW')
    .asFunction<int Function(Pointer<MSG>)>();

final DefWindowProc = user32
    .lookup<NativeFunction<IntPtr Function(IntPtr, Uint32, IntPtr, IntPtr)>>(
        'DefWindowProcW')
    .asFunction<int Function(int, int, int, int)>();

final PostQuitMessage = user32
    .lookup<NativeFunction<Void Function(Int32)>>('PostQuitMessage')
    .asFunction<void Function(int)>();

final DestroyWindow = user32
    .lookup<NativeFunction<Int32 Function(IntPtr)>>('DestroyWindow')
    .asFunction<int Function(int)>();

final LoadCursor = user32
    .lookup<NativeFunction<IntPtr Function(IntPtr, IntPtr)>>('LoadCursorW')
    .asFunction<int Function(int, int)>();

@pragma('vm:prefer-inline')
int MAKEINTRESOURCE(int id) => id & 0xFFFF; // suficiente p/ IDs de recurso

final InvalidateRect = user32
    .lookup<NativeFunction<Int32 Function(IntPtr, Pointer<RECT>, Int32)>>(
        'InvalidateRect')
    .asFunction<int Function(int, Pointer<RECT>, int)>();

final BeginPaint = user32
    .lookup<NativeFunction<IntPtr Function(IntPtr, Pointer<PAINTSTRUCT>)>>(
        'BeginPaint')
    .asFunction<int Function(int, Pointer<PAINTSTRUCT>)>();

final EndPaint = user32
    .lookup<NativeFunction<Int32 Function(IntPtr, Pointer<PAINTSTRUCT>)>>(
        'EndPaint')
    .asFunction<int Function(int, Pointer<PAINTSTRUCT>)>();

final GetClientRect = user32
    .lookup<NativeFunction<Int32 Function(IntPtr, Pointer<RECT>)>>(
        'GetClientRect')
    .asFunction<int Function(int, Pointer<RECT>)>();

final FillRect = user32
    .lookup<NativeFunction<Int32 Function(IntPtr, Pointer<RECT>, IntPtr)>>(
        'FillRect')
    .asFunction<int Function(int, Pointer<RECT>, int)>();

final CreateSolidBrush = gdi32
    .lookup<NativeFunction<IntPtr Function(Uint32)>>('CreateSolidBrush')
    .asFunction<int Function(int)>();

final DeleteObject = gdi32
    .lookup<NativeFunction<Int32 Function(IntPtr)>>('DeleteObject')
    .asFunction<int Function(int)>();

final GetOpenFileName = comdlg32
    .lookup<NativeFunction<Int32 Function(Pointer<OPENFILENAMEW>)>>(
        'GetOpenFileNameW')
    .asFunction<int Function(Pointer<OPENFILENAMEW>)>();

final ShellExecute = shell32
    .lookup<
        NativeFunction<
            IntPtr Function(IntPtr, Pointer<Utf16>, Pointer<Utf16>,
                Pointer<Utf16>, Pointer<Utf16>, Int32)>>('ShellExecuteW')
    .asFunction<
        int Function(int, Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>,
            Pointer<Utf16>, int)>();

//  FUNÇÕES GDI
final TextOut = gdi32
    .lookup<
        NativeFunction<
            Int32 Function(
                IntPtr, Int32, Int32, Pointer<Utf16>, Int32)>>('TextOutW')
    .asFunction<int Function(int, int, int, Pointer<Utf16>, int)>();

final SetTextColor = gdi32
    .lookup<NativeFunction<Uint32 Function(IntPtr, Uint32)>>('SetTextColor')
    .asFunction<int Function(int, int)>();

final SetBkMode = gdi32
    .lookup<NativeFunction<Int32 Function(IntPtr, Int32)>>('SetBkMode')
    .asFunction<int Function(int, int)>();

final IntersectClipRect = gdi32
    .lookup<NativeFunction<Int32 Function(IntPtr, Int32, Int32, Int32, Int32)>>(
        'IntersectClipRect')
    .asFunction<int Function(int, int, int, int, int)>();

//   STRLEN
final strlen = msvcrt
    .lookup<NativeFunction<Size Function(Pointer)>>('strlen')
    .asFunction<int Function(Pointer)>();

final SaveDC = gdi32
    .lookup<NativeFunction<Int32 Function(IntPtr)>>('SaveDC')
    .asFunction<int Function(int)>();

final RestoreDC = gdi32
    .lookup<NativeFunction<Int32 Function(IntPtr, Int32)>>('RestoreDC')
    .asFunction<int Function(int, int)>();

final CreatePen = gdi32
    .lookup<NativeFunction<IntPtr Function(Int32, Int32, Uint32)>>('CreatePen')
    .asFunction<int Function(int, int, int)>();

final SelectObject = gdi32
    .lookup<NativeFunction<IntPtr Function(IntPtr, IntPtr)>>('SelectObject')
    .asFunction<int Function(int, int)>();

final MoveToEx = gdi32
    .lookup<
        NativeFunction<
            Int32 Function(IntPtr, Int32, Int32, Pointer<POINT>)>>('MoveToEx')
    .asFunction<int Function(int, int, int, Pointer<POINT>)>();

final LineTo = gdi32
    .lookup<NativeFunction<Int32 Function(IntPtr, Int32, Int32)>>('LineTo')
    .asFunction<int Function(int, int, int)>();

final Ellipse = gdi32
    .lookup<NativeFunction<Int32 Function(IntPtr, Int32, Int32, Int32, Int32)>>(
        'Ellipse')
    .asFunction<int Function(int, int, int, int, int)>();

final Polygon = gdi32
    .lookup<NativeFunction<Int32 Function(IntPtr, Pointer<POINT>, Int32)>>(
        'Polygon')
    .asFunction<int Function(int, Pointer<POINT>, int)>();

final GetStockObject = gdi32
    .lookup<NativeFunction<IntPtr Function(Int32)>>('GetStockObject')
    .asFunction<int Function(int)>();
final Rectangle = gdi32
    .lookup<NativeFunction<Int32 Function(IntPtr, Int32, Int32, Int32, Int32)>>(
        'Rectangle')
    .asFunction<int Function(int, int, int, int, int)>();
final CreateRectRgn = gdi32
    .lookup<NativeFunction<IntPtr Function(Int32, Int32, Int32, Int32)>>(
        'CreateRectRgn')
    .asFunction<int Function(int, int, int, int)>();
final SelectClipRgn = gdi32
    .lookup<NativeFunction<Int32 Function(IntPtr, IntPtr)>>('SelectClipRgn')
    .asFunction<int Function(int, int)>();

final GetDC = user32
    .lookup<NativeFunction<IntPtr Function(IntPtr)>>('GetDC')
    .asFunction<int Function(int)>();

final ReleaseDC = user32
    .lookup<NativeFunction<Int32 Function(IntPtr, IntPtr)>>('ReleaseDC')
    .asFunction<int Function(int, int)>();

final ValidateRect = user32
    .lookup<NativeFunction<Int32 Function(IntPtr, Pointer<RECT>)>>(
        'ValidateRect')
    .asFunction<int Function(int, Pointer<RECT>)>();

// HDC CreateCompatibleDC(HDC);
typedef _CreateCompatibleDCC = IntPtr Function(IntPtr);
typedef CreateCompatibleDCF = int Function(int);
final CreateCompatibleDCF CreateCompatibleDC =
    gdi32.lookupFunction<_CreateCompatibleDCC, CreateCompatibleDCF>(
        'CreateCompatibleDC');

// HBITMAP CreateCompatibleBitmap(HDC,int,int);
typedef _CreateCompatibleBitmapC = IntPtr Function(IntPtr, Int32, Int32);
typedef CreateCompatibleBitmapF = int Function(int, int, int);
final CreateCompatibleBitmapF CreateCompatibleBitmap =
    gdi32.lookupFunction<_CreateCompatibleBitmapC, CreateCompatibleBitmapF>(
        'CreateCompatibleBitmap');

// BOOL DeleteDC(HDC);
typedef _DeleteDCC = Int32 Function(IntPtr);
typedef DeleteDCF = int Function(int);
final DeleteDCF DeleteDC =
    gdi32.lookupFunction<_DeleteDCC, DeleteDCF>('DeleteDC');

// BOOL BitBlt(HDC,int,int,int,int,HDC,int,int,DWORD);
typedef _BitBltC = Int32 Function(
    IntPtr, Int32, Int32, Int32, Int32, IntPtr, Int32, Int32, Uint32);
typedef BitBltF = int Function(int, int, int, int, int, int, int, int, int);

final BitBltF BitBlt = gdi32.lookupFunction<_BitBltC, BitBltF>('BitBlt');

// BOOL TextOutW(HDC,int,int,LPCWSTR,int);
typedef _TextOutWC = Int32 Function(
    IntPtr, Int32, Int32, Pointer<Uint16>, Int32);
typedef TextOutWF = int Function(int, int, int, Pointer<Uint16>, int);
final TextOutWF TextOutW =
    gdi32.lookupFunction<_TextOutWC, TextOutWF>('TextOutW');

// int MultiByteToWideChar(UINT CodePage, DWORD dwFlags,
//     LPCCH lpMultiByteStr, int cbMultiByte,
//     LPWSTR lpWideCharStr, int cchWideChar);
final MultiByteToWideChar = kernel32.lookupFunction<
    Int32 Function(
        Uint32, Uint32, Pointer<Uint8>, Int32, Pointer<Uint16>, Int32),
    int Function(int, int, Pointer<Uint8>, int, Pointer<Uint16>,
        int)>('MultiByteToWideChar');

typedef _postMessageDefC = Int32 Function(
    IntPtr hWnd, Uint32 Msg, IntPtr wParam, IntPtr lParam);
typedef _postMessageDefDart = int Function(
    int hWnd, int msg, int wParam, int lParam);

final PostMessage =
    user32.lookupFunction<_postMessageDefC, _postMessageDefDart>('PostMessageW',
        isLeaf: true);

typedef _CreatePipeC = Int32 Function(
    Pointer<IntPtr>, Pointer<IntPtr>, IntPtr, Uint32);
typedef _CreatePipeD = int Function(Pointer<IntPtr>, Pointer<IntPtr>, int, int);
final CreatePipe =
    kernel32.lookupFunction<_CreatePipeC, _CreatePipeD>('CreatePipe');

typedef _ReadFileC = Int32 Function(
    IntPtr, Pointer<Void>, Uint32, Pointer<Uint32>, IntPtr);
typedef _ReadFileD = int Function(
    int, Pointer<Void>, int, Pointer<Uint32>, int);
final ReadFile = kernel32.lookupFunction<_ReadFileC, _ReadFileD>('ReadFile');

typedef _CloseHandleC = Int32 Function(IntPtr);
typedef _CloseHandleD = int Function(int);
final CloseHandle =
    kernel32.lookupFunction<_CloseHandleC, _CloseHandleD>('CloseHandle');


typedef _PeekNamedPipeC = Int32 Function(
    IntPtr hNamedPipe,
    Pointer<Void> lpBuffer,
    Uint32 nBufferSize,
    Pointer<Uint32> lpBytesRead,
    Pointer<Uint32> lpTotalBytesAvail,
    Pointer<Uint32> lpBytesLeftThisMessage);

// Assinatura da função em Dart
typedef _PeekNamedPipeD = int Function(
    int hNamedPipe,
    Pointer<Void> lpBuffer,
    int nBufferSize,
    Pointer<Uint32> lpBytesRead,
    Pointer<Uint32> lpTotalBytesAvail,
    Pointer<Uint32> lpBytesLeftThisMessage);

// Carrega a função 'PeekNamedPipe' da kernel32.dll
final PeekNamedPipe =
    kernel32.lookupFunction<_PeekNamedPipeC, _PeekNamedPipeD>('PeekNamedPipe');

const int WM_NULL = 0x0000;

// Constantes usadas
const CP_UTF8 = 65001;

// Constantes para GetStockObject
const HOLLOW_BRUSH = 5;

const PS_SOLID = 0;

const PM_REMOVE = 0x0001;

const IDC_ARROW = 32512;
const COLOR_WINDOW = 5;

const WS_OVERLAPPEDWINDOW = 0x00CF0000;
const WS_VISIBLE = 0x10000000;
const SW_SHOW = 5;
const WM_CREATE = 0x0001;
const WM_DESTROY = 0x0002;
const WM_PAINT = 0x000F;
const WM_KEYDOWN = 0x0100;
const WM_KEYUP = 0x0101;
const WM_CHAR = 0x0102;
const WM_LBUTTONDOWN = 0x0201;
const WM_LBUTTONUP = 0x0202;
const WM_MBUTTONDOWN = 0x0207;
const WM_MBUTTONUP = 0x0208;
const WM_RBUTTONDOWN = 0x0204;
const WM_RBUTTONUP = 0x0205;
const WM_MOUSEMOVE = 0x0200;
const WM_MOUSEWHEEL = 0x020A;
const WM_SIZE = 0x0005;
const WM_QUIT = 0x0012;
const WM_CLOSE = 0x0010;
const WM_ERASEBKGND = 0x0014;

// ### Funções Utilitárias ###
int LOWORD(int l) => l & 0xFFFF;
int HIWORD(int l) => (l >> 16) & 0xFFFF;
int GET_WHEEL_DELTA_WPARAM(int wParam) => HIWORD(wParam);

// ### Constantes de Virtual-Key Codes ###
const VK_SHIFT = 0x10;
const VK_CONTROL = 0x11;
const VK_BACK = 0x08; // Backspace
const VK_RETURN = 0x0D; // Enter
const VK_DELETE = 0x2E;
const VK_LEFT = 0x25;
const VK_RIGHT = 0x27;

// ### Constantes para Diálogo de Arquivo ###
const MAX_PATH = 260;
const OFN_PATHMUSTEXIST = 0x00000800;
const OFN_FILEMUSTEXIST = 0x00001000;
const OFN_NOCHANGEDIR = 0x00000008;

// ---- GDI / USER constantes extras ----
const int NULL_BRUSH = 5; // GetStockObject(NULL_BRUSH)
const int TRANSPARENT = 1; // SetBkMode background transparent
const int SRCCOPY = 0x00CC0020; // BitBlt raster op

const int CS_HREDRAW = 0x0002;
const int CS_VREDRAW = 0x0001;

const int WM_NCCREATE = 0x0081; // 129

const int CW_USEDEFAULT = 0x80000000; // int 32-bit com bit alto
// Win32 RGB macro implementation
int RGB(int r, int g, int b) => r | (g << 8) | (b << 16);
