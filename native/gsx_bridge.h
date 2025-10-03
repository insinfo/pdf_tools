#pragma once
#include <stdint.h>
#include <stddef.h>

#ifdef _WIN32
  #define GSX_API extern "C" __declspec(dllexport)
  #define GSX_CALL           /* cdecl */
#else
  #define GSX_API extern "C"
  #define GSX_CALL
#endif

// ===== Tipos =====
typedef void (GSX_CALL *gsx_progress_cb)(
  int page_done,      // >=1 se conhecido
  int total_pages,    // 0 se desconhecido
  const char* line,   // linha textual do Ghostscript (pode ser NULL)
  void* user          // ponteiro opaco do chamador
);

// Callback opcional chamado a cada arquivo (modo pasta→pasta)
typedef void (GSX_CALL *gsx_file_cb)(
  const char* in_path,
  const char* out_path,
  void* user
);

typedef struct gsx_job_s gsx_job_t; // handle opaco (assíncrono)

typedef enum gsx_color_mode_e {
  GSX_COLOR_COLOR   = 0,  // colorido (padrão)
  GSX_COLOR_GRAY    = 1,  // tons de cinza
  GSX_COLOR_BILEVEL = 2   // P&B forte (1-bpp ou alvo agressivo)
} gsx_color_mode_t;

// ===== Erros padronizados (negativos) =====
typedef enum gsx_err_e {
  GSX_OK                         = 0,

  // Validações do wrapper
  GSX_E_ARGS                     = -2001, // argumentos inválidos
  GSX_E_INPUT_NOT_FOUND          = -2002, // in_path não existe
  GSX_E_OUTDIR_CREATE            = -2003, // falha ao criar pasta de saída
  GSX_E_WRITE_OPEN               = -2004, // falha ao abrir out_path p/ escrita
  GSX_E_TEMP_CREATE              = -2005, // falha ao criar arquivo temporário
  GSX_E_TEMP_IO                  = -2006, // falha de I/O em temporário
  GSX_E_CANCELED                 = -2007, // cancelado via poll
  GSX_E_UNKNOWN                  = -2099  // fallback

  // Observação: erros nativos do Ghostscript (<0, p.ex. -100) podem ser retornados diretamente.
} gsx_err_t;

// ===== Logging global =====
typedef enum gsx_log_level_e {
  GSX_LOG_ERROR = 0,
  GSX_LOG_WARN  = 1,
  GSX_LOG_INFO  = 2,
  GSX_LOG_DEBUG = 3,
  GSX_LOG_TRACE = 4
} gsx_log_level_t;

typedef void (GSX_CALL *gsx_log_cb)(int level, const char* line, void* user);

// Define callback de log + nível (global ao processo)
GSX_API void gsx_set_log_callback(gsx_log_cb cb, void* user);
GSX_API void gsx_set_log_level(gsx_log_level_t level);

// Ring-buffer opcional para capturar logs + stdout/stderr do GS
GSX_API void   gsx_log_capture_start(size_t size_bytes); // 0 desativa
GSX_API void   gsx_log_capture_stop(void);
// Copia captura para 'dst' (NUL-terminated). Retorna bytes (sem NUL).
GSX_API size_t gsx_log_capture_snapshot(char* dst, size_t maxlen);

// Mensagem curta para um código de erro
GSX_API const char* gsx_strerror(int rc);

// Último erro detalhado (por thread) no formato JSON:
// {"rc":-2002,"where":"compress_file_sync","os_errno":2,"gs_rc":0,"argv":[...]}
GSX_API const char* gsx_last_error_json(void);

// ===== Contexto =====
GSX_API void* gsx_create_context(void);   // placeholder p/ futuro
GSX_API void  gsx_destroy_context(void* ctx);

// ===== Helpers de argumentos =====
// Monta argv de compressão para pdfwrite.
// Retorna o total real de itens construídos; escreve até max_argv em argv_out.
// As strings são geridas internamente; não precisam ser liberadas.
GSX_API int gsx_build_pdfwrite_args(
  /*out*/ const char** argv_out,
  int max_argv,
  const char* in_path,
  const char* out_path,
  int dpi,                // 72..1200 (ex.: 120/150)
  int jpeg_quality,       // 1..100 (para DCTEncode)
  const char* preset,     // "default","screen","ebook","printer","prepress" (NULL=ignorar)
  gsx_color_mode_t mode,  // color/gray/bilevel
  int first_page,         // 0=ignora (-> -dFirstPage)
  int last_page           // 0=ignora (-> -dLastPage)
);

// Mantida por compat; não faz nada (sem malloc interno).
GSX_API void gsx_free_argv(const char** argv, int argc);

// ===== Execuções SÍNCRONAS =====
// 1) Compressão por caminho de arquivo
GSX_API int gsx_compress_file_sync(
  const char* in_path,
  const char* out_path,
  int dpi,
  int jpeg_quality,
  const char* preset,        // pode ser NULL
  gsx_color_mode_t mode,
  int first_page,            // 0=ignora
  int last_page,             // 0=ignora
  gsx_progress_cb on_progress,
  void* user,
  volatile int* cancel_flag  // 0=segue; !=0 cancela
);

// 2) Compressão por bytes (usa temporários internamente)
GSX_API int gsx_compress_bytes_sync(
  const void* in_bytes, uint64_t in_len,
  /*out*/ void** out_bytes, /*out*/ uint64_t* out_len,   // malloc() → use gsx_free()
  int dpi, int jpeg_quality, const char* preset, gsx_color_mode_t mode,
  gsx_progress_cb on_progress, void* user, volatile int* cancel_flag
);

// 3) Execução genérica via argumentos manuais (argv/argc que você mesmo monta)
GSX_API int gsx_run_args_sync(
  int argc, const char** argv,
  gsx_progress_cb on_progress, void* user, volatile int* cancel_flag
);

// ===== Execução ASSÍNCRONA (thread interna) =====
GSX_API gsx_job_t* gsx_compress_file_async(
  const char* in_path, const char* out_path,
  int dpi, int jpeg_quality, const char* preset, gsx_color_mode_t mode,
  int first_page, int last_page,
  gsx_progress_cb on_progress, void* user, volatile int* cancel_flag
);

GSX_API int  gsx_job_status(gsx_job_t* job);   // 0=rodando; >0=rc; <0=erro
GSX_API int  gsx_job_join(gsx_job_t* job);     // bloqueia, retorna rc
GSX_API void gsx_job_cancel(gsx_job_t* job);   // escreve 1 em cancel_flag
GSX_API void gsx_job_free(gsx_job_t* job);

// ===== Lote: pasta → pasta =====
// Percorre recursivamente 'in_dir' procurando *.pdf e escreve em 'out_dir'
// mantendo a hierarquia. Retorna 0 se todos OK; primeiro rc<0 encontrado caso contrário.
GSX_API int gsx_compress_dir_sync(
  const char* in_dir,
  const char* out_dir,
  int dpi, int jpeg_quality, const char* preset, gsx_color_mode_t mode,
  gsx_progress_cb on_progress, void* user, volatile int* cancel_flag,
  gsx_file_cb on_file
);

// ===== Util =====
GSX_API void gsx_free(void* p);
