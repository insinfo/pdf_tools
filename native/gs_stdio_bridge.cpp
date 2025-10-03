// gs_stdio_bridge.cpp  -> compilar como DLL


// compilar com 
// C:\Program Files\gs\ghostpdl-10.06.0\psi\iapi.h
// C:\Program Files\gs\gs10.06.0\bin\gsdll64.lib
// cl /LD /O2 /EHsc /std:c++17 /MD /I"C:\Program Files\gs\ghostpdl-10.06.0\psi" gs_stdio_bridge.cpp /link /OUT:gs_stdio_bridge.dll /MACHINE:X64 /LIBPATH:"C:\Program Files\gs\gs10.06.0\bin" gsdll64.lib
//

#define UNICODE
#include <windows.h>
#include <unordered_map>
#include "iapi.h"

// user_data -> HANDLE de escrita
static std::unordered_map<void*, HANDLE> g_map;
static SRWLOCK g_lock = SRWLOCK_INIT;

static HANDLE _get_handle(void* user) {
  AcquireSRWLockShared(&g_lock);
  auto it = g_map.find(user);
  HANDLE h = (it == g_map.end()) ? NULL : it->second;
  ReleaseSRWLockShared(&g_lock);
  return h;
}

static int __stdcall gs_stdin_cb(void* /*user*/, char* /*buf*/, int /*len*/) {
  return 0;
}

static int __stdcall gs_stdout_cb(void* user, const char* data, int len) {
  if (len <= 0) return len;
  HANDLE h = _get_handle(user);
  if (!h) return len;
  DWORD written = 0;
  WriteFile(h, data, (DWORD)len, &written, NULL);
  return len;
}

static int __stdcall gs_stderr_cb(void* user, const char* data, int len) {
  return gs_stdout_cb(user, data, len);
}

// Novo: recebe instância + user_data + handle de escrita
extern "C" __declspec(dllexport)
int GS_AttachStdIO(void* gs_instance, void* user_data, HANDLE hPipeWrite) {
  if (!gs_instance || !user_data || !hPipeWrite) return -1;
  AcquireSRWLockExclusive(&g_lock);
  g_map[user_data] = hPipeWrite;
  ReleaseSRWLockExclusive(&g_lock);
  return gsapi_set_stdio(gs_instance, gs_stdin_cb, gs_stdout_cb, gs_stderr_cb);
}

extern "C" __declspec(dllexport)
void GS_DetachStdIO(void* user_data) {
  AcquireSRWLockExclusive(&g_lock);
  g_map.erase(user_data);
  ReleaseSRWLockExclusive(&g_lock);
}
