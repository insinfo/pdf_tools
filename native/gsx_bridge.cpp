// gsx_bridge.cpp — cross-platform (Windows + Linux)
// Requer Ghostscript (iapi.h) disponível no include path.

#include <atomic>
#include <string>
#include <vector>
#include <thread>
#include <mutex>
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <chrono>

namespace fs = std::filesystem;

extern "C" {
  #include "iapi.h"   // Ghostscript public API (gsapi_*)
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

// ======================= Logging global =======================
static std::mutex g_log_mtx;
static gsx_log_cb g_log_cb = nullptr;
static void* g_log_user = nullptr;
static std::atomic<int> g_log_level{GSX_LOG_INFO};

// ring-buffer opcional p/ captura
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

// ======================= Last error (thread-local JSON) =======================
static thread_local std::string t_last_err_json;

static void set_last_error_json(int rc, const char* where,
                                int os_errno, int gs_rc,
                                const std::vector<std::string>* argv) {
  t_last_err_json.clear();
  t_last_err_json += "{";
  t_last_err_json += "\"rc\":" + std::to_string(rc);
  if (where)     t_last_err_json += ",\"where\":\"" + std::string(where) + "\"";
  if (os_errno)  t_last_err_json += ",\"os_errno\":" + std::to_string(os_errno);
  if (gs_rc)     t_last_err_json += ",\"gs_rc\":" + std::to_string(gs_rc);
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

// ======================= Util/linhas → progresso =======================
static void split_lines_and_emit(const char* data, int len,
                                 gsx_progress_cb cb, void* user,
                                 int& page_done, int total_pages)
{
  static thread_local std::string carry;
  if (!cb || len <= 0) return;
  carry.append(data, data + len);
  size_t pos = 0;
  while (true) {
    size_t nl = carry.find('\n', pos);
    if (nl == std::string::npos) break;
    std::string line = carry.substr(pos, nl - pos);
    if (!line.empty() && line.back() == '\r') line.pop_back();
    if (line.rfind("Page ", 0) == 0) {
      int n = atoi(line.c_str() + 5);
      if (n > 0) page_done = n;
    }
    cb(page_done, total_pages, line.c_str(), user);
    pos = nl + 1;
  }
  carry.erase(0, pos);
}

// ======================= Execução GS =======================
struct GsxExecCtx {
  void* instance = nullptr;
  gsx_progress_cb cb = nullptr;
  void* user = nullptr;
  volatile int* cancel_flag = nullptr;
  int page_done = 0;
  int total_pages = 0;

  // *** IMPORTANTE: cdecl (sem __stdcall) ***
  static int stdin_fn(void* /*h*/, char* /*buf*/, int /*len*/) { return 0; }

  static int stdout_fn(void* h, const char* d, int len) {
    auto* self = reinterpret_cast<GsxExecCtx*>(h);
    if (!self) return len;
    if (len > 0) {
      std::string s(d, d + len);
      _log(GSX_LOG_INFO, s.c_str());
    }
    split_lines_and_emit(d, len, self->cb, self->user, self->page_done, self->total_pages);
    return len;
  }

  static int stderr_fn(void* h, const char* d, int len) {
    if (len > 0) { std::string s(d, d + len); _log(GSX_LOG_WARN, s.c_str()); }
    return stdout_fn(h, d, len);
  }

  static int poll_fn(void* h) {
    auto* self = reinterpret_cast<GsxExecCtx*>(h);
    if (!self || !self->cancel_flag) return 0;
    return (*self->cancel_flag != 0) ? 1 : 0; // 1 => abortar
  }
};

static int run_gs_with_argv(GsxExecCtx& ctx, int argc, const char** argv, const std::vector<std::string>* av_log) {
  int code = gsapi_new_instance(&ctx.instance, &ctx);
  if (code < 0) {
    set_last_error_json(code, "gsapi_new_instance", 0, code, av_log);
    return code;
  }

  gsapi_set_arg_encoding(ctx.instance, GS_ARG_ENCODING_UTF8);
  gsapi_set_stdio(ctx.instance, GsxExecCtx::stdin_fn, GsxExecCtx::stdout_fn, GsxExecCtx::stderr_fn);
  gsapi_set_poll(ctx.instance,  GsxExecCtx::poll_fn);

  code = gsapi_init_with_args(ctx.instance, argc, const_cast<char**>(argv));

  int code_exit = gsapi_exit(ctx.instance);
  gsapi_delete_instance(ctx.instance);
  ctx.instance = nullptr;

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

// ======================= Build args helpers =======================
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
  push(A, "-dSAFER");
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
  build_pdf_args_vec(A, in_path, out_path,
                     dpi > 0 ? dpi : 120,
                     (jpeg_quality<1?75:(jpeg_quality>100?100:jpeg_quality)),
                     preset, mode, first_page, last_page);

  static thread_local std::vector<std::string> keep;
  keep = A;

  int n = (int)keep.size();
  int w = (n > max_argv) ? max_argv : n;
  for (int i=0;i<w;i++) argv_out[i] = keep[i].c_str();

  set_last_error_json(GSX_OK, "build_pdfwrite_args", 0, 0, &keep);
  return n;
}

GSX_API void gsx_free_argv(const char** /*argv*/, int /*argc*/) {
  // nada: strings estão em thread_local 'keep'
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
    _log(GSX_LOG_ERROR, "input not found");
    return GSX_E_INPUT_NOT_FOUND;
  }
  fs::create_directories(fs::path(out_path).parent_path(), ec);
  if (ec) {
    set_last_error_json(GSX_E_OUTDIR_CREATE, "compress_file_sync", (int)errno, 0, nullptr);
    _log(GSX_LOG_ERROR, "cannot create output dir");
    return GSX_E_OUTDIR_CREATE;
  }

  std::vector<std::string> A;
  build_pdf_args_vec(A, in_path, out_path,
                     dpi > 0 ? dpi : 120,
                     (jpeg_quality<1?75:(jpeg_quality>100?100:jpeg_quality)),
                     preset, mode, first_page, last_page);
  std::vector<const char*> argv; vec_to_argv(A, argv);
  GsxExecCtx ctx; ctx.cb = on_progress; ctx.user = user; ctx.cancel_flag = cancel_flag;
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
  std::atomic<int> status{0};  // 0=rodando; >0 concluído; <0 erro
  std::atomic<int> rc{0};
  volatile int* cancel_flag = nullptr;
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
    (dpi>0?dpi:120), (jpeg_quality<1?75:(jpeg_quality>100?100:jpeg_quality)),
    presetS, mode, first_page, last_page, on_progress, user);
  job->th.detach();
  set_last_error_json(GSX_OK, "compress_file_async", 0, 0, nullptr);
  return job;
}

GSX_API int gsx_job_status(gsx_job_t* job) {
  if (!job) return -1;
  return job->status.load();
}

GSX_API int gsx_job_join(gsx_job_t* job) {
  if (!job) return -1;
  while (job->status.load() == 0) gsx_sleep_ms(50);
  return job->rc.load();
}

GSX_API void gsx_job_cancel(gsx_job_t* job) {
  if (job && job->cancel_flag) *job->cancel_flag = 1;
}

GSX_API void gsx_job_free(gsx_job_t* job) {
  if (job) delete job;
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
