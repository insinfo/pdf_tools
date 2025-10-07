// gsx_bridge.cpp — Versão Completa com Correção de Qualidade JPEG e Debug Log

#include <atomic>
#include <string>
#include <vector>
#include <thread>
#include <mutex>
#include <cstdlib>
#include <cstdio> // Incluído para a função de log de debug (fprintf)
#include <cstring>
#include <filesystem>
#include <fstream>
#include <chrono>

#include <algorithm>   // std::min, std::max
#include <sstream>     // std::ostringstream
#include <iomanip>     // (opcional) std::setprecision
#include <locale>
#include <ctime>
#include <cerrno>





namespace fs = std::filesystem;

extern "C" {
  #include "iapi.h"
}
#include "gsx_bridge.h"

// ======================= Compat layer (Win / POSIX) =======================
#ifdef _WIN32
  #define NOMINMAX
  #include <windows.h>
  static void gsx_sleep_ms(unsigned ms){ Sleep(ms); }
  static std::string sys_temp_dir() {
    char buf[MAX_PATH]; DWORD n = GetTempPathA(MAX_PATH, buf);
    return (n ? std::string(buf) : std::string("."));
  }
  static std::string make_temp_file(const char* prefix, const char* ext) {
    char tmp[MAX_PATH]; GetTempPathA(MAX_PATH, tmp);
    char name[MAX_PATH]; GetTempFileNameA(tmp, prefix ? prefix : "GSX", 0, name);
    std::string p = name;
    if (ext && *ext) {
      std::string withExt = p + ext;
      MoveFileExA(p.c_str(), withExt.c_str(), MOVEFILE_REPLACE_EXISTING);
      return withExt;
    }
    return p;
  }
#else
  #include <unistd.h>
  #include <sys/stat.h>
  static void gsx_sleep_ms(unsigned ms){
    std::this_thread::sleep_for(std::chrono::milliseconds(ms));
  }
  static std::string sys_temp_dir() {
    const char* t = getenv("TMPDIR");
    return t ? t : "/tmp";
  }
  static std::string make_temp_file(const char* prefix, const char* ext) {
    std::string tpl = sys_temp_dir() + "/" + (prefix ? prefix : "GSX") + "XXXXXX";
    std::vector<char> buf(tpl.begin(), tpl.end()); buf.push_back('\0');
    int fd = mkstemp(buf.data());
    if (fd >= 0) close(fd);
    std::string p(buf.data());
    if (ext && *ext) { std::string q = p + ext; rename(p.c_str(), q.c_str()); return q; }
    return p;
  }
#endif

static std::string win_to_fwd_slashes(std::string s){
  for (auto& c : s) if (c == '\\') c = '/';
  return s;
}

// ======= CONFIGURAÇÃO DE LOG EM ARQUIVO =======
// Modo padrão: DESLIGADO (0). Para compilar diferente, use -DGSX_FILELOG_MODE=1/2.
// 0 = totalmente desligado e compilado fora (zero overhead)
// 1 = sempre ligado
// 2 = desligado por padrão; pode ligar em runtime com variável de ambiente GSX_FILELOG=1
#ifndef GSX_FILELOG_MODE
#define GSX_FILELOG_MODE 0
#endif

#if GSX_FILELOG_MODE == 0
  static inline bool _debug_enabled() noexcept { return false; }

#elif GSX_FILELOG_MODE == 1
  static inline bool _debug_enabled() noexcept { return true; }

#else // GSX_FILELOG_MODE == 2
  #include <atomic>
  static std::atomic<bool> g_debug_file_log{false};
  static inline bool _debug_enabled() noexcept {
    return g_debug_file_log.load(std::memory_order_relaxed);
  }
  struct _GsxDebugInit {
    _GsxDebugInit() {
      const char* v = std::getenv("GSX_FILELOG");
      if (v && (*v=='1' || *v=='T' || *v=='t' || *v=='Y' || *v=='y'))
        g_debug_file_log.store(true, std::memory_order_relaxed);
    }
  } _gsx_debug_init_once;
#endif

// Junta o vetor de args exatamente como é passado ao GSAPI (sem "gswin64c.exe")
static std::string _join_argv_plain(const std::vector<std::string>& A) {
  std::string s;
  for (const auto& a : A) {
    s.push_back('"');
    for (char c : a) s += (c == '\"') ? "\\\"" : std::string(1, c);
    s.push_back('"');
    s.push_back(' ');
  }
  return s;
}

static void _append_debug_file(const std::string& text) {
  if (!_debug_enabled()) return;
#ifdef _WIN32
  std::string dir = sys_temp_dir() + "\\gsx_debug";
  std::error_code ec; std::filesystem::create_directories(dir, ec);
  std::string fn = dir + "\\gsx_cmd.txt";
#else
  std::string dir = sys_temp_dir() + "/gsx_debug";
  std::error_code ec; std::filesystem::create_directories(dir, ec);
  std::string fn = dir + "/gsx_cmd.txt";
#endif
  std::ofstream f(fn, std::ios::app);
  if (!f) return;
  std::time_t t = std::time(nullptr);
  char buf[64]; std::strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", std::localtime(&t));
  f << "==== " << buf << " ====\r\n" << text << "\r\n\r\n";
}

static void _append_debug_file_prefix(const char* prefix, const char* data, int len) {
  if (!_debug_enabled()) return;
  if (!data || len <= 0) return;
#ifdef _WIN32
  std::string dir = sys_temp_dir() + "\\gsx_debug";
  std::error_code ec; std::filesystem::create_directories(dir, ec);
  std::string fn = dir + "\\gsx_cmd.txt";
#else
  std::string dir = sys_temp_dir() + "/gsx_debug";
  std::error_code ec; std::filesystem::create_directories(dir, ec);
  std::string fn = dir + "/gsx_cmd.txt";
#endif
  std::ofstream f(fn, std::ios::app | std::ios::binary);
  if (!f) return;
  std::time_t t = std::time(nullptr);
  char ts[32]; std::strftime(ts, sizeof(ts), "%H:%M:%S", std::localtime(&t));
  f << "[" << ts << "] " << (prefix ? prefix : "") << " ";
  f.write(data, len);
  if (len && data[len-1] != '\n') f << "\r\n";
}

// quebra em linhas e loga com prefixo
static void _append_debug_per_line(const char* prefix, const char* data, int len) {
  if (!_debug_enabled()) return;
  if (!data || len <= 0) return;
  const char* p = data;
  const char* end = data + len;
  while (p < end) {
    const char* nl = (const char*)memchr(p, '\n', (size_t)(end - p));
    if (!nl) {
      _append_debug_file_prefix(prefix, p, (int)(end - p));
      break;
    } else {
      int linelen = (int)(nl - p);
      if (linelen > 0 && p[linelen-1] == '\r') linelen--;
      _append_debug_file_prefix(prefix, p, linelen);
      p = nl + 1;
    }
  }
}

// ======================= Logging e Erros (Sem alterações) =======================
static std::mutex g_log_mtx;
static gsx_log_cb g_log_cb = nullptr;
static void* g_log_user = nullptr;
static std::atomic<int> g_log_level{GSX_LOG_INFO};
static std::string g_ring;
static size_t g_ring_cap = 0;

static void _log(int lvl, const char* msg) {
  if (!msg) return;
  if (lvl <= g_log_level.load()) {
    gsx_log_cb cb = nullptr; void* u = nullptr;
    { std::lock_guard<std::mutex> lk(g_log_mtx); cb = g_log_cb; u = g_log_user; }
    if (cb) cb(lvl, msg, u);
  }
  if (g_ring_cap > 0) {
    std::lock_guard<std::mutex> lk(g_log_mtx);
    size_t need = (g_ring.size() + strlen(msg) + 1 > g_ring_cap)
                  ? (g_ring.size() + strlen(msg) + 1 - g_ring_cap) : 0;
    if (need) {
      if (need >= g_ring.size()) g_ring.clear();
      else g_ring.erase(0, need);
    }
    g_ring.append(msg).push_back('\n');
  }
}

void gsx_set_log_callback(gsx_log_cb cb, void* user){
  std::lock_guard<std::mutex> lk(g_log_mtx);
  g_log_cb = cb; g_log_user = user;
}
void gsx_set_log_level(gsx_log_level_t level){ g_log_level = level; }
void gsx_log_capture_start(size_t cap){
  std::lock_guard<std::mutex> lk(g_log_mtx);
  g_ring_cap = cap; g_ring.clear(); if (cap) g_ring.reserve(std::min<size_t>(cap, 1<<20));
}
void gsx_log_capture_stop(void){
  std::lock_guard<std::mutex> lk(g_log_mtx);
  g_ring_cap = 0; g_ring.clear();
}
size_t gsx_log_capture_snapshot(char* dst, size_t maxlen){
  std::lock_guard<std::mutex> lk(g_log_mtx);
  if (!dst || maxlen == 0) return 0;
  size_t n = std::min(maxlen-1, g_ring.size());
  memcpy(dst, g_ring.data(), n); dst[n] = 0; return n;
}
static thread_local std::string t_last_err_json;
static void set_last_error_json(int rc, const char* where, int os_errno, int gs_rc, const std::vector<std::string>* argv) {
  t_last_err_json.clear();
  t_last_err_json += "{";
  t_last_err_json += "\"rc\":" + std::to_string(rc);
  if (where)      t_last_err_json += ",\"where\":\"" + std::string(where) + "\"";
  if (os_errno)   t_last_err_json += ",\"os_errno\":" + std::to_string(os_errno);
  if (gs_rc)      t_last_err_json += ",\"gs_rc\":" + std::to_string(gs_rc);
  if (argv){
    t_last_err_json += ",\"argv\":[";
    for (size_t i=0;i<argv->size();++i){
      if (i) t_last_err_json += ",";
      std::string s = argv->at(i);
      for (char& c : s) if (c == '\"') c = '\'';
      t_last_err_json += "\"" + s + "\"";
    }
    t_last_err_json += "]";
  }
  t_last_err_json += "}";
  _log(GSX_LOG_DEBUG, t_last_err_json.c_str());
}
const char* gsx_last_error_json(void){ return t_last_err_json.c_str(); }
const char* gsx_strerror(int rc){
  switch (rc){
    case GSX_OK: return "ok";
    case GSX_E_ARGS: return "argumentos inválidos";
    case GSX_E_INPUT_NOT_FOUND: return "arquivo de entrada não encontrado";
    case GSX_E_OUTDIR_CREATE: return "falha ao criar diretório de saída";
    case GSX_E_WRITE_OPEN: return "falha ao abrir arquivo de saída";
    case GSX_E_TEMP_CREATE: return "falha ao criar arquivo temporário";
    case GSX_E_TEMP_IO: return "falha de I/O em temporário";
    case GSX_E_CANCELED: return "processo cancelado";
    case GSX_E_UNKNOWN: return "erro desconhecido";
    case -100: return "Ghostscript fatal (-100)";
    default: return "erro";
  }
}
struct GsxExecCtx {
  void* instance = nullptr;
  gsx_progress_cb cb = nullptr;
  void* user = nullptr;
  volatile int* cancel_flag = nullptr;
  int page_done = 0;
  int total_pages = 0;

  static int stdin_fn(void* h, char* buf, int len) { return 0; }
  static int stdout_fn(void* h, const char* d, int len);
  static int stderr_fn(void* h, const char* d, int len) { return stdout_fn(h, d, len); }
  static int poll_fn(void* h) {
    auto* self = reinterpret_cast<GsxExecCtx*>(h);
    if (!self || !self->cancel_flag) return 0;
    return (*self->cancel_flag != 0) ? 1 : 0;
  }
};
static void split_lines_and_emit(const char* data, int len, GsxExecCtx* ctx)
{
    static thread_local std::string carry;
    if (!ctx || !ctx->cb || len <= 0) return;
    carry.append(data, data + len);
    size_t pos = 0;
    while (true) {
        size_t nl = carry.find('\n', pos);
        if (nl == std::string::npos) break;
        static thread_local std::string line;
        line = carry.substr(pos, nl - pos);
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (ctx->total_pages == 0) {
            const char* pages_keyword = "Processing pages 1 through ";
            size_t keyword_pos = line.find(pages_keyword);
            if (keyword_pos != std::string::npos) {
                ctx->total_pages = atoi(line.c_str() + keyword_pos + strlen(pages_keyword));
            }
        }
        if (line.rfind("Page ", 0) == 0) {
            int n = atoi(line.c_str() + 5);
            if (n > 0) ctx->page_done = n;
        }
        ctx->cb(ctx->page_done, ctx->total_pages, line.c_str(), ctx->user);
        pos = nl + 1;
    }
    carry.erase(0, pos);
}

int GsxExecCtx::stdout_fn(void* h, const char* d, int len) {
  auto* self = reinterpret_cast<GsxExecCtx*>(h);
  if (_debug_enabled()) {
    _append_debug_file_prefix("STDOUT-CHUNK:", d, len);
    _append_debug_per_line("STDOUT:", d, len);
  }
  if (self) split_lines_and_emit(d, len, self);
  return len;
}

static int run_gs_with_argv(GsxExecCtx& ctx, int argc, const char** argv,
                            const std::vector<std::string>* av_log) {
  if (_debug_enabled()) {
    std::ostringstream oss;
    oss << "GSAPI CALL BEGIN\r\n";
    oss << "argc=" << argc << "\r\n";
    for (int i = 0; i < argc; ++i) {
      oss << "argv[" << i << "] = \"" << (argv[i] ? argv[i] : "") << "\"\r\n";
    }
    _append_debug_file(oss.str());
  }

  int code = gsapi_new_instance(&ctx.instance, &ctx);
  if (code < 0) {
    set_last_error_json(code, "gsapi_new_instance", 0, code, av_log);
    if (_debug_enabled())
      _append_debug_file(std::string("gsapi_new_instance -> ") + std::to_string(code));
    return code;
  }

  gsapi_set_arg_encoding(ctx.instance, GS_ARG_ENCODING_UTF8);
  gsapi_set_stdio(ctx.instance, GsxExecCtx::stdin_fn, GsxExecCtx::stdout_fn, GsxExecCtx::stderr_fn);
  gsapi_set_poll(ctx.instance, GsxExecCtx::poll_fn);

  code = gsapi_init_with_args(ctx.instance, argc, const_cast<char**>(argv));
  int code_exit = gsapi_exit(ctx.instance);
  gsapi_delete_instance(ctx.instance);
  ctx.instance = nullptr;

  if (_debug_enabled()) {
    std::ostringstream oss;
    oss << "GSAPI CALL END\r\n"
        << "gsapi_init_with_args -> " << code << "\r\n"
        << "gsapi_exit -> " << code_exit << "\r\n"
        << "last_error_json: " << (gsx_last_error_json() ? gsx_last_error_json() : "(null)");
    _append_debug_file(oss.str());
  }

  if (ctx.cancel_flag && *ctx.cancel_flag) {
    set_last_error_json(GSX_E_CANCELED, "gsapi", 0, code, av_log);
    return GSX_E_CANCELED;
  }
  if (code < 0) {
    set_last_error_json(code, "gsapi_init_with_args", 0, code, av_log);
    return code;
  }
  if (code_exit < 0) {
    set_last_error_json(code_exit, "gsapi_exit", 0, code_exit, av_log);
    return code_exit;
  }

  set_last_error_json(GSX_OK, "gsapi", 0, 0, av_log);
  return code;
}


static void push(std::vector<std::string>& v, const std::string& s){ v.emplace_back(s); }

// verssão sem qfactor
static void build_pdf_args_vec(std::vector<std::string>& A,
  const char* in_path,
  const char* out_path,
  int dpi,
  int jpeg_q,
  const char* preset,
  gsx_color_mode_t mode,
  int first_page,
  int last_page)
{

  push(A, "gs");
  
  push(A, "-dBATCH");
  push(A, "-dNOPAUSE");
  push(A, "-sDEVICE=pdfwrite");

  if (preset && *preset) {
    push(A, std::string("-dPDFSETTINGS=/") + preset);
  }

  push(A, "-dDetectDuplicateImages=true");
  push(A, "-dDownsampleColorImages=true");
  push(A, "-dDownsampleGrayImages=true");
  push(A, "-dDownsampleMonoImages=true");
  push(A, "-dColorImageDownsampleType=/Average");
  push(A, "-dGrayImageDownsampleType=/Average");
  push(A, "-dMonoImageDownsampleType=/Subsample");

  push(A, std::string("-dColorImageResolution=") + std::to_string(dpi));
  push(A, std::string("-dGrayImageResolution=")  + std::to_string(dpi));
  push(A, std::string("-dMonoImageResolution=")  + std::to_string(dpi*2));

  push(A, "-dAutoFilterColorImages=false");
  push(A, "-dAutoFilterGrayImages=false");
  push(A, "-dColorImageFilter=/DCTEncode");
  push(A, "-dGrayImageFilter=/DCTEncode");
  
  if (jpeg_q < 1) jpeg_q = 1;
  if (jpeg_q > 100) jpeg_q = 100;
  
  // if (logfile) { 
  //   fprintf(logfile, "  - jpeg_q (final usado): %d\n", jpeg_q);
  //   fclose(logfile);
  // }

//& "C:\MyDartProjects\pdf_tools\gswin64c.exe" -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOutputFile="C:\MyDartProjects\pdf_tools\pdfs\input\14_34074_Vol 5_p1-10_qf001_dpi120.pdf" -dFirstPage=1 -dLastPage=10 -dDetectDuplicateImages=true -dDownsampleColorImages=true -dDownsampleGrayImages=true -dDownsampleMonoImages=true -dColorImageDownsampleType=/Subsample -dGrayImageDownsampleType=/Subsample -dMonoImageDownsampleType=/Subsample -dColorImageResolution=120 -dGrayImageResolution=120 -dMonoImageResolution=240 -dEncodeColorImages=true -dEncodeGrayImages=true -dEncodeMonoImages=true -dPassThroughJPEGImages=false -dAutoFilterColorImages=false -dAutoFilterGrayImages=false -dColorImageFilter=/DCTEncode -dGrayImageFilter=/DCTEncode -dMonoImageFilter=/CCITTFaxEncode -c '<< /ColorImageDict << /QFactor 0.01 >> /ColorACSImageDict << /QFactor 0.01 >> /GrayImageDict << /QFactor 0.01 >> /GrayACSImageDict << /QFactor 0.01 >> >> setdistillerparams' -f "C:\MyDartProjects\pdf_tools\pdfs\input\14_34074_Vol 5.pdf"

// Forçar recompressão e impedir pass-through:
  push(A, "-dEncodeColorImages=true");
  push(A, "-dEncodeGrayImages=true");
  push(A, "-dEncodeMonoImages=true");
  push(A, "-dPassThroughJPEGImages=false");
  push(A, std::string("-dJPEGQ=") + std::to_string(jpeg_q));

  switch (mode) {
    case GSX_COLOR_GRAY:
      push(A, "-sProcessColorModel=DeviceGray");
      push(A, "-sColorConversionStrategy=Gray");
      push(A, "-dOverrideICC=true");
      break;
    case GSX_COLOR_BILEVEL:
      push(A, "-sProcessColorModel=DeviceGray");
      push(A, "-sColorConversionStrategy=Gray");
      push(A, "-dOverrideICC=true");
      break;
    default: break;
  }
  if (first_page > 0) push(A, std::string("-dFirstPage=") + std::to_string(first_page));
  if (last_page  > 0) push(A, std::string("-dLastPage=")  + std::to_string(last_page));

  push(A, "-o"); push(A, out_path);
  push(A, in_path);
}



// ======================= Build args helpers =======================
static void build_pdf_args_vec_qfactor(
  std::vector<std::string>& A,
  const char* in_path,
  const char* out_path,
  int dpi,
  int jpeg_q,                 // 1..100
  const char* /*preset*/,
  gsx_color_mode_t mode,
  int first_page,
  int last_page)
{
#ifdef _WIN32
  // argv[0] pode ser qualquer string; usar o nome do exe ajuda nos logs
  A.emplace_back("gswin64c");
#else
  A.emplace_back("gs");
#endif

  // 1) Cabeçalho base
  A.emplace_back("-dBATCH");
  A.emplace_back("-dNOPAUSE");
  A.emplace_back("-sDEVICE=pdfwrite");

  // 2) *** Saída IMEDIATAMENTE após -sDEVICE ***
  //    Formato ÚNICO token: -sOutputFile=C:\...\file.pdf  (sem aspas simples)
  A.emplace_back(std::string("-sOutputFile=") + out_path);

  // 3) Intervalo de páginas (antes do restante)
  if (first_page > 0) A.emplace_back(std::string("-dFirstPage=") + std::to_string(first_page));
  if (last_page  > 0) A.emplace_back(std::string("-dLastPage=")  + std::to_string(last_page));

  // 4) Demais parâmetros (na mesma ordem do comando que funcionou)
  A.emplace_back("-dDetectDuplicateImages=true");
  A.emplace_back("-dDownsampleColorImages=true");
  A.emplace_back("-dDownsampleGrayImages=true");
  A.emplace_back("-dDownsampleMonoImages=true");
  A.emplace_back("-dColorImageDownsampleType=/Subsample");
  A.emplace_back("-dGrayImageDownsampleType=/Subsample");
  A.emplace_back("-dMonoImageDownsampleType=/Subsample");

  A.emplace_back(std::string("-dColorImageResolution=") + std::to_string(dpi));
  A.emplace_back(std::string("-dGrayImageResolution=")  + std::to_string(dpi));
  A.emplace_back(std::string("-dMonoImageResolution=")  + std::to_string(dpi * 2));

  A.emplace_back("-dEncodeColorImages=true");
  A.emplace_back("-dEncodeGrayImages=true");
  A.emplace_back("-dEncodeMonoImages=true");
  A.emplace_back("-dPassThroughJPEGImages=false");

  A.emplace_back("-dAutoFilterColorImages=false");
  A.emplace_back("-dAutoFilterGrayImages=false");
  A.emplace_back("-dColorImageFilter=/DCTEncode");
  A.emplace_back("-dGrayImageFilter=/DCTEncode");
  A.emplace_back("-dMonoImageFilter=/CCITTFaxEncode");

  if(jpeg_q < 100){
    // 5) QFactor (gera o mesmo '-c' do seu comando)
    jpeg_q = std::clamp(jpeg_q, 1, 100);
    double qf = (jpeg_q >= 50)
                  ? 1.0 - ((jpeg_q - 50) * (0.5 / 40.0))
                  : 1.0 + ((50 - jpeg_q) * 0.08);
    qf = std::clamp(qf, 0.3, 4.0);

    std::ostringstream ps;
    ps.imbue(std::locale::classic());
    ps.setf(std::ios::fixed);
    ps << "<< "
      << "/ColorImageDict << /QFactor "    << std::setprecision(3) << qf << " >> "
      << "/ColorACSImageDict << /QFactor " << std::setprecision(3) << qf << " >> "
      << "/GrayImageDict << /QFactor "     << std::setprecision(3) << qf << " >> "
      << "/GrayACSImageDict << /QFactor "  << std::setprecision(3) << qf << " >> "
      << ">> setdistillerparams";

    A.emplace_back("-c");
    A.emplace_back(ps.str());
 }

  // 6) Conversão de cor (se pedida)
  switch (mode) {
    case GSX_COLOR_GRAY:
    case GSX_COLOR_BILEVEL:
      A.emplace_back("-sProcessColorModel=DeviceGray");
      A.emplace_back("-sColorConversionStrategy=Gray");
      A.emplace_back("-dOverrideICC=true");
      break;
    default: break;
  }

  // 7) Tolerar PDFs problemáticos (igual ao seu)
  A.emplace_back("-dPDFSTOPONERROR=false");

  // 8) Encerrar opções e passar o input (ordem idêntica)
  A.emplace_back("-f");
  A.emplace_back(in_path);
}




static void vec_to_argv(const std::vector<std::string>& A, std::vector<const char*>& out) {
  out.clear(); out.reserve(A.size());
  for (auto& s : A) out.push_back(s.c_str());
}

// ======================= API Pública =======================
GSX_API void* gsx_create_context(void){ return (void*)1; }
GSX_API void  gsx_destroy_context(void* /*ctx*/){}

GSX_API int gsx_build_pdfwrite_args(
  const char** argv_out, int max_argv,
  const char* in_path,
  const char* out_path,
  int dpi, int jpeg_quality, const char* preset,
  gsx_color_mode_t mode, int first_page, int last_page)
{
  if (!argv_out || max_argv <= 0 || !in_path || !out_path) {
    set_last_error_json(GSX_E_ARGS, "build_pdfwrite_args", 0, 0, nullptr);
    return GSX_E_ARGS;
  }
  std::vector<std::string> A;
  build_pdf_args_vec(A, in_path, out_path, dpi, jpeg_quality, preset, mode, first_page, last_page);

  static thread_local std::vector<std::string> keep;
  keep = A;

  int n = (int)keep.size();
  int w = (n > max_argv) ? max_argv : n;
  for (int i=0;i<w;i++) argv_out[i] = keep[i].c_str();

  set_last_error_json(GSX_OK, "build_pdfwrite_args", 0, 0, &keep);
  return n;
}

GSX_API void gsx_free_argv(const char** /*argv*/, int /*argc*/) {
}

GSX_API int gsx_run_args_sync(
  int argc, const char** argv,
  gsx_progress_cb on_progress, void* user, volatile int* cancel_flag)
{
  if (argc <= 0 || !argv) {
    set_last_error_json(GSX_E_ARGS, "run_args_sync", 0, 0, nullptr);
    return GSX_E_ARGS;
  }
  std::vector<std::string> A; A.reserve(argc);
  for (int i=0;i<argc;i++) A.emplace_back(argv[i] ? argv[i] : "");

  GsxExecCtx ctx; ctx.cb = on_progress; ctx.user = user; ctx.cancel_flag = cancel_flag;
  int rc = run_gs_with_argv(ctx, argc, argv, &A);
  return rc;
}

GSX_API int gsx_compress_file_sync(
  const char* in_path, const char* out_path,
  int dpi, int jpeg_quality, const char* preset, gsx_color_mode_t mode,
  int first_page, int last_page,
  gsx_progress_cb on_progress, void* user, volatile int* cancel_flag)
{
  if (!in_path || !out_path) {
    set_last_error_json(GSX_E_ARGS, "compress_file_sync", 0, 0, nullptr);
    return GSX_E_ARGS;
  }
  std::error_code ec;
  if (!fs::exists(in_path, ec)) {
    set_last_error_json(GSX_E_INPUT_NOT_FOUND, "compress_file_sync", (int)errno, 0, nullptr);
    return GSX_E_INPUT_NOT_FOUND;
  }
  fs::create_directories(fs::path(out_path).parent_path(), ec);
  if (ec) {
    set_last_error_json(GSX_E_OUTDIR_CREATE, "compress_file_sync", (int)errno, 0, nullptr);
    return GSX_E_OUTDIR_CREATE;
  }

  std::vector<std::string> A;
  build_pdf_args_vec(A, in_path, out_path, dpi, jpeg_quality, preset, mode, first_page, last_page);

  std::vector<const char*> argv; vec_to_argv(A, argv);
  GsxExecCtx ctx; ctx.cb = on_progress; ctx.user = user; ctx.cancel_flag = cancel_flag;

  if (_debug_enabled()) _append_debug_file(_join_argv_plain(A));

  int rc = run_gs_with_argv(ctx, (int)argv.size(), argv.data(), &A);
  return rc;
}

GSX_API int gsx_compress_bytes_sync(
  const void* in_bytes, uint64_t in_len,
  void** out_bytes, uint64_t* out_len,
  int dpi, int jpeg_quality, const char* preset, gsx_color_mode_t mode,
  gsx_progress_cb on_progress, void* user, volatile int* cancel_flag)
{
  if (!in_bytes || in_len==0 || !out_bytes || !out_len) {
    set_last_error_json(GSX_E_ARGS, "compress_bytes_sync", 0, 0, nullptr);
    return GSX_E_ARGS;
  }
  std::string tin  = make_temp_file("GSXI", ".pdf");
  std::string tout = make_temp_file("GSXO", ".pdf");

  {
    std::ofstream f(tin, std::ios::binary);
    if (!f) { set_last_error_json(GSX_E_TEMP_CREATE, "compress_bytes_sync.write-open", (int)errno, 0, nullptr); return GSX_E_TEMP_CREATE; }
    f.write((const char*)in_bytes, (std::streamsize)in_len);
    if (!f) { set_last_error_json(GSX_E_TEMP_IO, "compress_bytes_sync.write", (int)errno, 0, nullptr); return GSX_E_TEMP_IO; }
  }

  int rc = gsx_compress_file_sync(tin.c_str(), tout.c_str(),
                                  dpi, jpeg_quality, preset, mode,
                                  0, 0, on_progress, user, cancel_flag);
  if (rc < 0) { std::error_code ec; fs::remove(tin, ec); fs::remove(tout, ec); return rc; }

  std::ifstream g(tout, std::ios::binary|std::ios::ate);
  if (!g) { std::error_code ec; set_last_error_json(GSX_E_TEMP_IO, "compress_bytes_sync.read-open", (int)errno, 0, nullptr);
            fs::remove(tin, ec); fs::remove(tout, ec); return GSX_E_TEMP_IO; }
  auto sz = (uint64_t)g.tellg();
  g.seekg(0);
  void* buf = std::malloc((size_t)sz);
  if (!buf) { std::error_code ec; fs::remove(tin, ec); fs::remove(tout, ec);
              set_last_error_json(GSX_E_TEMP_IO, "compress_bytes_sync.alloc", 0, 0, nullptr); return GSX_E_TEMP_IO; }
  g.read((char*)buf, (std::streamsize)sz);
  g.close();

  *out_bytes = buf; *out_len = sz;
  std::error_code ec; fs::remove(tin, ec); fs::remove(tout, ec);
  set_last_error_json(GSX_OK, "compress_bytes_sync", 0, 0, nullptr);
  return 0;
}

GSX_API void gsx_free(void* p){ if (p) std::free(p); }

// ======================= Assíncrono =======================
struct gsx_job_s {
  std::thread th;
  std::atomic<int> status{0};
  std::atomic<int> rc{0};
  volatile int* cancel_flag = nullptr;
  std::mutex mtx;
  bool joined = false;
};

static void job_thread(gsx_job_t* job,
  std::string in_path, std::string out_path,
  int dpi, int jpeg_q, std::string preset, gsx_color_mode_t mode,
  int first_page, int last_page, gsx_progress_cb cb, void* user)
{
  if (!job) return;
  int r = gsx_compress_file_sync(in_path.c_str(), out_path.c_str(), dpi, jpeg_q,
                                 preset.empty()?nullptr:preset.c_str(), mode,
                                 first_page, last_page, cb, user, job->cancel_flag);
  job->rc = r;
  job->status = (r >= 0) ? (r == 0 ? 1 : r) : r;
}

GSX_API gsx_job_t* gsx_compress_file_async(
  const char* in_path, const char* out_path,
  int dpi, int jpeg_quality, const char* preset, gsx_color_mode_t mode,
  int first_page, int last_page,
  gsx_progress_cb on_progress, void* user, volatile int* cancel_flag)
{
  if (!in_path || !out_path) { set_last_error_json(GSX_E_ARGS, "compress_file_async", 0, 0, nullptr); return nullptr; }
  auto* job = new gsx_job_t();
  job->cancel_flag = cancel_flag;
  std::string presetS = preset ? preset : "";
  
  job->th = std::thread(job_thread, job,
    std::string(in_path), std::string(out_path),
    dpi, jpeg_quality,
    presetS, mode, first_page, last_page, on_progress, user);
    
  set_last_error_json(GSX_OK, "compress_file_async", 0, 0, nullptr);
  return job;
}

GSX_API int gsx_job_status(gsx_job_t* job) {
  if (!job) return -1;
  return job->status.load();
}

GSX_API int gsx_job_join(gsx_job_t* job) {
  if (!job) return -1;
  std::lock_guard<std::mutex> lk(job->mtx);
  if (!job->joined && job->th.joinable()) {
      job->th.join();
      job->joined = true;
  }
  return job->rc.load();
}

GSX_API void gsx_job_cancel(gsx_job_t* job) {
  if (job && job->cancel_flag) *job->cancel_flag = 1;
}

GSX_API void gsx_job_free(gsx_job_t* job) {
  if (job) {
    gsx_job_join(job);
    delete job;
  }
}

// ======================= Dir → Dir =======================
static bool ends_with_pdf(const fs::path& p) {
  auto e = p.extension().string();
  for (auto& c : e) c = (char)tolower((unsigned char)c);
  return e == ".pdf";
}

GSX_API int gsx_compress_dir_sync(
  const char* in_dir, const char* out_dir,
  int dpi, int jpeg_quality, const char* preset, gsx_color_mode_t mode,
  gsx_progress_cb on_progress, void* user, volatile int* cancel_flag,
  gsx_file_cb on_file)
{
  if (!in_dir || !out_dir) { set_last_error_json(GSX_E_ARGS, "compress_dir_sync", 0, 0, nullptr); return GSX_E_ARGS; }
  std::error_code ec;
  fs::path inRoot(in_dir), outRoot(out_dir);
  if (!fs::exists(inRoot)) { set_last_error_json(GSX_E_INPUT_NOT_FOUND, "compress_dir_sync", (int)errno, 0, nullptr); return GSX_E_INPUT_NOT_FOUND; }
  fs::create_directories(outRoot, ec);

  int last_rc = 0;
  for (auto it = fs::recursive_directory_iterator(inRoot, ec);
       it != fs::recursive_directory_iterator(); ++it)
  {
    if (cancel_flag && *cancel_flag) { set_last_error_json(GSX_E_CANCELED, "compress_dir_sync", 0, 0, nullptr); return GSX_E_CANCELED; }
    if (ec) break;
    if (!it->is_regular_file()) continue;
    const auto& ip = it->path();
    if (!ends_with_pdf(ip)) continue;

    fs::path rel = fs::relative(ip, inRoot, ec);
    fs::path op  = outRoot / rel;
    fs::create_directories(op.parent_path(), ec);

    if (on_file) on_file(ip.string().c_str(), op.string().c_str(), user);

    int rc = gsx_compress_file_sync(ip.string().c_str(), op.string().c_str(),
                                    dpi, jpeg_quality, preset, mode,
                                    0, 0, on_progress, user, cancel_flag);
    if (rc < 0) { last_rc = rc; break; }
  }
  set_last_error_json(last_rc, "compress_dir_sync", 0, 0, nullptr);
  return last_rc;
}