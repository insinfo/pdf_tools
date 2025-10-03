// wndproc_shim.cpp
#define UNICODE
#define NOMINMAX
#include <windows.h>

// compilar com 
// cl /LD /O2 /EHsc /std:c++17 /MD wndproc_shim.cpp user32.lib gdi32.lib /link /OUT:wndproc_shim.dll

struct FwdMsg {
  UINT   uMsg;
  WPARAM wParam;
  LPARAM lParam;
};

struct ForwardInfo {
  DWORD thread_id;   // thread que vai receber as mensagens
  UINT  fwd_msg;     // código da msg para PostThreadMessage (WM_APP + X)
};

static const UINT kDefaultFwdMsg = WM_APP + 0x3A27;

static void dbg(const wchar_t* msg) {
  OutputDebugStringW(msg);  // veja no DebugView/DbgView
  OutputDebugStringW(L"\r\n");
}

static LRESULT CALLBACK WndProcShim(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
  if (uMsg == WM_NCCREATE) {
    auto cs = reinterpret_cast<CREATESTRUCTW*>(lParam);
    auto info = reinterpret_cast<ForwardInfo*>(cs->lpCreateParams);
    if (info) {
      SetWindowLongPtrW(hWnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(info));
      // A partir daqui, WM_CREATE já será encaminhado
    }
  }

  ForwardInfo* info = reinterpret_cast<ForwardInfo*>(GetWindowLongPtrW(hWnd, GWLP_USERDATA));

  if (info && info->thread_id) {
    FwdMsg* pkt = new FwdMsg{ uMsg, wParam, lParam };
    PostThreadMessageW(info->thread_id,
                       info->fwd_msg ? info->fwd_msg : kDefaultFwdMsg,
                       reinterpret_cast<WPARAM>(hWnd),
                       reinterpret_cast<LPARAM>(pkt));
  }

  switch (uMsg) {
    case WM_ERASEBKGND: return 1;
    case WM_PAINT: {
      PAINTSTRUCT ps; HDC hdc = BeginPaint(hWnd, &ps); EndPaint(hWnd, &ps);
      return 0;
    }
    case WM_NCDESTROY: {
      // Limpa ForwardInfo
      auto p = reinterpret_cast<ForwardInfo*>(GetWindowLongPtrW(hWnd, GWLP_USERDATA));
      if (p) { delete p; SetWindowLongPtrW(hWnd, GWLP_USERDATA, 0); }
      break;
    }
  }
  return DefWindowProcW(hWnd, uMsg, wParam, lParam);
}

extern "C" __declspec(dllexport)
ATOM Shim_RegisterClass(const wchar_t* class_name) {
  WNDCLASSEXW wc{};
  wc.cbSize        = sizeof(wc);
  wc.style         = CS_HREDRAW | CS_VREDRAW;
  wc.lpfnWndProc   = WndProcShim;
  wc.cbClsExtra    = 0;
  wc.cbWndExtra    = sizeof(LONG_PTR);
  wc.hInstance     = GetModuleHandleW(nullptr);
  wc.hCursor       = LoadCursorW(nullptr, IDC_ARROW);
  wc.hbrBackground = (HBRUSH)GetStockObject(NULL_BRUSH); // <- evita apagar de branco
  wc.lpszClassName = class_name;
  ATOM a = RegisterClassExW(&wc);
  // if (!a) dbg(L"[SHIM] RegisterClassExW FAILED");
  // else    dbg(L"[SHIM] RegisterClassExW OK");
  return a;
}

extern "C" __declspec(dllexport)
HWND Shim_CreateWindow(const wchar_t* class_name, const wchar_t* title, int width, int height) {
  HINSTANCE hInst = GetModuleHandleW(nullptr);
  HWND hWnd = CreateWindowExW(
      0, class_name, title,
      WS_OVERLAPPEDWINDOW | WS_VISIBLE,
      CW_USEDEFAULT, CW_USEDEFAULT, width, height,
      nullptr, nullptr, hInst, nullptr);
  // if (!hWnd) dbg(L"[SHIM] CreateWindowExW FAILED");
  // else       dbg(L"[SHIM] CreateWindowExW OK");
  return hWnd;
}

extern "C" __declspec(dllexport)
HWND Shim_CreateWindowFwd(const wchar_t* class_name,
                          const wchar_t* title,
                          int width, int height,
                          DWORD thread_id, UINT forward_msg /*0 = default*/) {
  HINSTANCE hInst = GetModuleHandleW(nullptr);
  auto info = new ForwardInfo{ thread_id, forward_msg };
  // Passa 'info' no lpParam
  HWND hWnd = CreateWindowExW(
      0, class_name, title,
      WS_OVERLAPPEDWINDOW | WS_VISIBLE,
      CW_USEDEFAULT, CW_USEDEFAULT, width, height,
      nullptr, nullptr, hInst, info);
  if (!hWnd) { delete info; }
  return hWnd;
}

extern "C" __declspec(dllexport)
void Shim_SetForwarding(HWND hwnd, DWORD thread_id, UINT forward_msg /*0 = default*/) {
  ForwardInfo* info = new ForwardInfo{ thread_id, forward_msg };
  SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(info));
  // dbg(L"[SHIM] SetForwarding OK");
}

extern "C" __declspec(dllexport)
void Shim_ClearForwarding(HWND hwnd) {
  auto p = reinterpret_cast<ForwardInfo*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  if (p) { delete p; SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0); }
  // dbg(L"[SHIM] ClearForwarding");
}

extern "C" __declspec(dllexport) void Shim_FreePacket(void* pkt) { delete reinterpret_cast<FwdMsg*>(pkt); }
extern "C" __declspec(dllexport) UINT Shim_DefaultForwardMsg() { return kDefaultFwdMsg; }
BOOL APIENTRY DllMain(HMODULE, DWORD, LPVOID) { return TRUE; }
