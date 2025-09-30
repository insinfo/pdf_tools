// C:\MyDartProjects\pdf_tools\lib\src/mupdf_bindings.dart
// ignore_for_file: non_constant_identifier_names, camel_case_types

import 'dart:ffi';
import 'package:ffi/ffi.dart';

// =============================================================================
// --- ESTRUTURAS NATIVAS (C STRUCTS) ---
// =============================================================================

// ADIÇÃO: Estrutura para opções de reescrita de imagem (downsampling).
final class pdf_image_rewriter_options extends Struct {
  @Int32()
  external int color_lossless_image_subsample_method;
  @Int32()
  external int color_lossy_image_subsample_method;
  @Int32()
  external int color_lossless_image_subsample_threshold;
  @Int32()
  external int color_lossless_image_subsample_to;
  @Int32()
  external int color_lossy_image_subsample_threshold;
  @Int32()
  external int color_lossy_image_subsample_to;
  @Int32()
  external int color_lossless_image_recompress_method;
  @Int32()
  external int color_lossy_image_recompress_method;
  external Pointer<Utf8> color_lossy_image_recompress_quality;
  external Pointer<Utf8> color_lossless_image_recompress_quality;
  // (Campos para 'gray' e 'bitonal' omitidos para simplicidade, mas poderiam ser adicionados)
}

// ADIÇÃO: Estrutura principal para opções de limpeza.
final class pdf_clean_options extends Struct {
  external pdf_write_options write;
  external pdf_image_rewriter_options image;
  @Int32()
  external int subset_fonts;
  @Int32()
  external int structure;
}

/// Representa a estrutura fz_matrix da C API.
final class fz_matrix extends Struct {
  @Float()
  external double a;
  @Float()
  external double b;
  @Float()
  external double c;
  @Float()
  external double d;
  @Float()
  external double e;
  @Float()
  external double f;
}

/// Representa a estrutura fz_rect da C API (com floats).
final class fz_rect extends Struct {
  @Float()
  external double x0;
  @Float()
  external double y0;
  @Float()
  external double x1;
  @Float()
  external double y1;
}

/// Representa um quadrilátero, útil para destacar texto.
final class fz_quad extends Struct {
  @Float()
  external double ul_x;
  @Float()
  external double ul_y;
  @Float()
  external double ur_x;
  @Float()
  external double ur_y;
  @Float()
  external double ll_x;
  @Float()
  external double ll_y;
  @Float()
  external double lr_x;
  @Float()
  external double lr_y;
}

/// Opções para extração de texto estruturado.
final class fz_stext_options extends Struct {
  @Int32()
  external int flags;
}

/// Opções para salvar/escrever um documento PDF.
final class pdf_write_options extends Struct {
  @Int32()
  external int do_incremental;
  @Int32()
  external int do_pretty;
  @Int32()
  external int do_ascii;
  @Int32()
  external int do_compress;
  @Int32()
  external int do_compress_images;
  @Int32()
  external int do_compress_fonts;
  @Int32()
  external int do_decompress;
  @Int32()
  external int do_garbage;
  @Int32()
  external int do_linear;
  @Int32()
  external int do_clean;
  @Int32()
  external int do_sanitize;
  @Int32()
  external int do_appearance;
  @Int32()
  external int do_encrypt;
  @Int32()
  external int permissions;

  @Array(128)
  external Array<Uint8> opwd_utf8;
  @Array(128)
  external Array<Uint8> upwd_utf8;
}

// --- Estruturas para Assinatura Digital (Callbacks) ---

/// Assinatura da função de callback para criar um digest PKCS#7.
typedef pdf_pkcs7_create_digest_fn_native = Int32 Function(
    fz_context, Pointer<Void>, fz_stream, Pointer<Uint8>, IntPtr);

/// Assinatura da função de callback para obter o tamanho máximo do digest.
typedef pdf_pkcs7_max_digest_size_fn_native = IntPtr Function(
    fz_context, Pointer<Void>);

/// Estrutura de callbacks para o assinador (a ser implementada em Dart).
final class pdf_pkcs7_signer extends Struct {
  /// Ponteiro para a função que cria o digest.
  external Pointer<NativeFunction<pdf_pkcs7_create_digest_fn_native>>
      create_digest;

  /// Ponteiro para a função que retorna o tamanho máximo do digest.
  external Pointer<NativeFunction<pdf_pkcs7_max_digest_size_fn_native>>
      max_digest_size;
  // Outras funções de callback como 'keep', 'drop', 'get_signing_name' podem ser adicionadas se necessário.
}

/// Assinatura da função de callback para verificar o certificado.
typedef pdf_pkcs7_check_certificate_fn_native = Int32 Function(
    fz_context, Pointer<Void>, Pointer<Uint8>, IntPtr);

/// Assinatura da função de callback para verificar o digest da assinatura.
typedef pdf_pkcs7_check_digest_fn_native = Int32 Function(
    fz_context, Pointer<Void>, fz_stream, Pointer<Uint8>, IntPtr);

/// Estrutura de callbacks para o verificador (a ser implementada em Dart).
final class pdf_pkcs7_verifier extends Struct {
  /// Ponteiro para a função que verifica o certificado.
  external Pointer<NativeFunction<pdf_pkcs7_check_certificate_fn_native>>
      check_certificate;

  /// Ponteiro para a função que verifica o digest.
  external Pointer<NativeFunction<pdf_pkcs7_check_digest_fn_native>>
      check_digest;
  // Outras callbacks como 'drop', 'get_signatory' podem ser adicionadas.
}

// =============================================================================
// --- PONTEIROS OPACOS ---
// =============================================================================

typedef fz_context = Pointer<Void>;
typedef fz_document = Pointer<Void>;
typedef fz_page = Pointer<Void>;
typedef fz_pixmap = Pointer<Void>;
typedef fz_device = Pointer<Void>;
typedef fz_buffer = Pointer<Void>;
typedef fz_colorspace = Pointer<Void>;
typedef fz_stext_page = Pointer<Void>;
typedef fz_stext_options_ptr = Pointer<fz_stext_options>;
typedef fz_outline = Pointer<Void>;
typedef fz_link = Pointer<Void>;
typedef fz_annot = Pointer<Void>;
typedef pdf_obj = Pointer<Void>;
typedef fz_stream = Pointer<Void>;
typedef fz_image = Pointer<Void>;

// =============================================================================
// --- ASSINATURAS DE FUNÇÕES (NATIVAS E DART) ---
// =============================================================================

// Context
typedef _fz_new_context_imp_native = fz_context Function(
    Pointer<Void>, Pointer<Void>, IntPtr, Pointer<Utf8>);
typedef _fz_new_context_imp_dart = fz_context Function(
    Pointer<Void>, Pointer<Void>, int, Pointer<Utf8>);
typedef _fz_drop_context_native = Void Function(fz_context);
typedef fz_drop_context_dart = void Function(fz_context);

// Document
typedef _fz_register_document_handlers_native = Void Function(fz_context);
typedef fz_register_document_handlers_dart = void Function(fz_context);
typedef _fz_open_document_native = fz_document Function(
    fz_context, Pointer<Utf8>);
typedef fz_open_document_dart = fz_document Function(fz_context, Pointer<Utf8>);
typedef _fz_needs_password_native = Int32 Function(fz_context, fz_document);
typedef fz_needs_password_dart = int Function(fz_context, fz_document);
typedef _fz_authenticate_password_native = Int32 Function(
    fz_context, fz_document, Pointer<Utf8>);
typedef fz_authenticate_password_dart = int Function(
    fz_context, fz_document, Pointer<Utf8>);
typedef _fz_count_pages_native = Int32 Function(fz_context, fz_document);
typedef fz_count_pages_dart = int Function(fz_context, fz_document);
typedef _fz_lookup_metadata_native = Int32 Function(
    fz_context, fz_document, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef fz_lookup_metadata_dart = int Function(
    fz_context, fz_document, Pointer<Utf8>, Pointer<Utf8>, int);
typedef _pdf_save_document_native = Void Function(
    fz_context, fz_document, Pointer<Utf8>, Pointer<pdf_write_options>);
typedef pdf_save_document_dart = void Function(
    fz_context, fz_document, Pointer<Utf8>, Pointer<pdf_write_options>);
typedef _fz_drop_document_native = Void Function(fz_context, fz_document);
typedef fz_drop_document_dart = void Function(fz_context, fz_document);

// Page
typedef _fz_load_page_native = fz_page Function(fz_context, fz_document, Int32);
typedef fz_load_page_dart = fz_page Function(fz_context, fz_document, int);
typedef _fz_bound_page_native = fz_rect Function(fz_context, fz_page);
typedef fz_bound_page_dart = fz_rect Function(fz_context, fz_page);
typedef _fz_run_page_native = Void Function(
    fz_context, fz_page, fz_device, fz_matrix, Pointer<Void>);
typedef fz_run_page_dart = void Function(
    fz_context, fz_page, fz_device, fz_matrix, Pointer<Void>);
typedef _fz_drop_page_native = Void Function(fz_context, fz_page);
typedef fz_drop_page_dart = void Function(fz_context, fz_page);

// Rendering
typedef _fz_new_pixmap_native = fz_pixmap Function(
    fz_context, fz_colorspace, Int32, Int32, Pointer<Void>, Int32);
typedef fz_new_pixmap_dart = fz_pixmap Function(
    fz_context, fz_colorspace, int, int, Pointer<Void>, int);
typedef _fz_clear_pixmap_with_value_native = Void Function(
    fz_context, fz_pixmap, Int32);
typedef fz_clear_pixmap_with_value_dart = void Function(
    fz_context, fz_pixmap, int);
typedef _fz_pixmap_samples_native = Pointer<Uint8> Function(
    fz_context, fz_pixmap);
typedef fz_pixmap_samples_dart = Pointer<Uint8> Function(fz_context, fz_pixmap);
typedef _fz_pixmap_width_native = Int32 Function(fz_context, fz_pixmap);
typedef fz_pixmap_width_dart = int Function(fz_context, fz_pixmap);
typedef _fz_pixmap_height_native = Int32 Function(fz_context, fz_pixmap);
typedef fz_pixmap_height_dart = int Function(fz_context, fz_pixmap);
typedef _fz_pixmap_stride_native = Int32 Function(fz_context, fz_pixmap);
typedef fz_pixmap_stride_dart = int Function(fz_context, fz_pixmap);
typedef _fz_drop_pixmap_native = Void Function(fz_context, fz_pixmap);
typedef fz_drop_pixmap_dart = void Function(fz_context, fz_pixmap);
typedef _fz_device_rgb_native = fz_colorspace Function(fz_context);
typedef fz_device_rgb_dart = fz_colorspace Function(fz_context);

// Device
typedef _fz_new_draw_device_native = fz_device Function(
    fz_context, fz_matrix, fz_pixmap);
typedef fz_new_draw_device_dart = fz_device Function(
    fz_context, fz_matrix, fz_pixmap);
typedef _fz_close_device_native = Void Function(fz_context, fz_device);
typedef fz_close_device_dart = void Function(fz_context, fz_device);
typedef _fz_drop_device_native = Void Function(fz_context, fz_device);
typedef fz_drop_device_dart = void Function(fz_context, fz_device);

// Text Extraction & Search
typedef _fz_new_stext_page_from_page_native = fz_stext_page Function(
    fz_context, fz_page, fz_stext_options_ptr);
typedef fz_new_stext_page_from_page_dart = fz_stext_page Function(
    fz_context, fz_page, fz_stext_options_ptr);
typedef _fz_new_buffer_from_stext_page_native = fz_buffer Function(
    fz_context, fz_stext_page);
typedef fz_new_buffer_from_stext_page_dart = fz_buffer Function(
    fz_context, fz_stext_page);
typedef _fz_drop_stext_page_native = Void Function(fz_context, fz_stext_page);
typedef fz_drop_stext_page_dart = void Function(fz_context, fz_stext_page);
typedef _fz_search_page_native = Int32 Function(fz_context, fz_page,
    Pointer<Utf8>, Pointer<Int32>, Pointer<fz_quad>, Int32);
typedef fz_search_page_dart = int Function(
    fz_context, fz_page, Pointer<Utf8>, Pointer<Int32>, Pointer<fz_quad>, int);
typedef _fz_buffer_storage_native = IntPtr Function(
    fz_context, fz_buffer, Pointer<Pointer<Uint8>>);
typedef fz_buffer_storage_dart = int Function(
    fz_context, fz_buffer, Pointer<Pointer<Uint8>>);
typedef _fz_drop_buffer_native = Void Function(fz_context, fz_buffer);
typedef fz_drop_buffer_dart = void Function(fz_context, fz_buffer);

// Outline & Links
typedef _fz_load_outline_native = fz_outline Function(fz_context, fz_document);
typedef fz_load_outline_dart = fz_outline Function(fz_context, fz_document);
typedef _fz_drop_outline_native = Void Function(fz_context, fz_outline);
typedef fz_drop_outline_dart = void Function(fz_context, fz_outline);
typedef _fz_load_links_native = fz_link Function(fz_context, fz_page);
typedef fz_load_links_dart = fz_link Function(fz_context, fz_page);
typedef _fz_drop_link_native = Void Function(fz_context, fz_link);
typedef fz_drop_link_dart = void Function(fz_context, fz_link);

// Annotations & Forms
typedef _pdf_create_annot_native = fz_annot Function(
    fz_context, fz_page, Int32);
typedef pdf_create_annot_dart = fz_annot Function(fz_context, fz_page, int);
typedef _pdf_first_widget_native = fz_annot Function(fz_context, fz_page);
typedef pdf_first_widget_dart = fz_annot Function(fz_context, fz_page);
typedef _pdf_next_widget_native = fz_annot Function(fz_context, fz_annot);
typedef pdf_next_widget_dart = fz_annot Function(fz_context, fz_annot);
typedef _pdf_set_field_value_native = Int32 Function(
    fz_context, fz_document, pdf_obj, Pointer<Utf8>, Int32);
typedef pdf_set_field_value_dart = int Function(
    fz_context, fz_document, pdf_obj, Pointer<Utf8>, int);

// Digital Signatures
typedef _pdf_create_signature_widget_native = fz_annot Function(
    fz_context, fz_page, Pointer<Utf8>);
typedef pdf_create_signature_widget_dart = fz_annot Function(
    fz_context, fz_page, Pointer<Utf8>);
typedef _pdf_sign_signature_native = Void Function(
    fz_context,
    fz_annot,
    Pointer<pdf_pkcs7_signer>,
    Int64,
    Int32,
    fz_image,
    Pointer<Utf8>,
    Pointer<Utf8>);
typedef pdf_sign_signature_dart = void Function(
    fz_context,
    fz_annot,
    Pointer<pdf_pkcs7_signer>,
    int,
    int,
    fz_image,
    Pointer<Utf8>,
    Pointer<Utf8>);
typedef _pdf_check_widget_certificate_native = Int32 Function(
    fz_context, Pointer<pdf_pkcs7_verifier>, fz_annot);
typedef pdf_check_widget_certificate_dart = int Function(
    fz_context, Pointer<pdf_pkcs7_verifier>, fz_annot);
typedef _pdf_check_widget_digest_native = Int32 Function(
    fz_context, Pointer<pdf_pkcs7_verifier>, fz_annot);
typedef pdf_check_widget_digest_dart = int Function(
    fz_context, Pointer<pdf_pkcs7_verifier>, fz_annot);
typedef _pdf_clear_signature_native = Void Function(fz_context, fz_annot);
typedef pdf_clear_signature_dart = void Function(fz_context, fz_annot);

typedef _pdf_clean_file_native = Void Function(
    fz_context,
    Pointer<Utf8>,
    Pointer<Utf8>,
    Pointer<Utf8>,
    Pointer<pdf_clean_options>,
    Int32,
    Pointer<Pointer<Utf8>>);
typedef pdf_clean_file_dart = void Function(
    fz_context,
    Pointer<Utf8>,
    Pointer<Utf8>,
    Pointer<Utf8>,
    Pointer<pdf_clean_options>,
    int,
    Pointer<Pointer<Utf8>>);

/// Classe principal que encapsula as chamadas FFI para a biblioteca MuPDF.
class MuPDFBindings {
  /// A biblioteca dinâmica carregada.
  DynamicLibrary lib;

  Pointer<T> lookup<T extends NativeType>(String symbolName) {
    return lib.lookup<T>(symbolName);
  }

  static const mupdfVersion = '1.27.0';

  /// A matriz de identidade [1 0 0 1 0 0].
  ///  Carrega a matriz de identidade global
  late final fz_matrix fz_identity = lib.lookup<fz_matrix>('fz_identity').ref;

  late final pdf_clean_file_dart pdf_clean_file = lib
      .lookup<NativeFunction<_pdf_clean_file_native>>('pdf_clean_file')
      .asFunction();

  MuPDFBindings(this.lib) {
    // --- Vincula todas as funções ---
    _fz_new_context_imp = lib
        .lookup<NativeFunction<_fz_new_context_imp_native>>(
            'fz_new_context_imp')
        .asFunction();
    fz_drop_context = lib
        .lookup<NativeFunction<_fz_drop_context_native>>('fz_drop_context')
        .asFunction();
    fz_register_document_handlers = lib
        .lookup<NativeFunction<_fz_register_document_handlers_native>>(
            'fz_register_document_handlers')
        .asFunction();
    fz_open_document = lib
        .lookup<NativeFunction<_fz_open_document_native>>('fz_open_document')
        .asFunction();
    fz_needs_password = lib
        .lookup<NativeFunction<_fz_needs_password_native>>('fz_needs_password')
        .asFunction();
    fz_authenticate_password = lib
        .lookup<NativeFunction<_fz_authenticate_password_native>>(
            'fz_authenticate_password')
        .asFunction();
    fz_count_pages = lib
        .lookup<NativeFunction<_fz_count_pages_native>>('fz_count_pages')
        .asFunction();
    fz_lookup_metadata = lib
        .lookup<NativeFunction<_fz_lookup_metadata_native>>(
            'fz_lookup_metadata')
        .asFunction();
    pdf_save_document = lib
        .lookup<NativeFunction<_pdf_save_document_native>>('pdf_save_document')
        .asFunction();
    fz_drop_document = lib
        .lookup<NativeFunction<_fz_drop_document_native>>('fz_drop_document')
        .asFunction();
    fz_load_page = lib
        .lookup<NativeFunction<_fz_load_page_native>>('fz_load_page')
        .asFunction();
    fz_bound_page = lib
        .lookup<NativeFunction<_fz_bound_page_native>>('fz_bound_page')
        .asFunction();
    fz_run_page = lib
        .lookup<NativeFunction<_fz_run_page_native>>('fz_run_page')
        .asFunction();
    fz_drop_page = lib
        .lookup<NativeFunction<_fz_drop_page_native>>('fz_drop_page')
        .asFunction();
    fz_new_pixmap = lib
        .lookup<NativeFunction<_fz_new_pixmap_native>>('fz_new_pixmap')
        .asFunction();
    fz_clear_pixmap_with_value = lib
        .lookup<NativeFunction<_fz_clear_pixmap_with_value_native>>(
            'fz_clear_pixmap_with_value')
        .asFunction();
    fz_pixmap_samples = lib
        .lookup<NativeFunction<_fz_pixmap_samples_native>>('fz_pixmap_samples')
        .asFunction();
    fz_pixmap_width = lib
        .lookup<NativeFunction<_fz_pixmap_width_native>>('fz_pixmap_width')
        .asFunction();
    fz_pixmap_height = lib
        .lookup<NativeFunction<_fz_pixmap_height_native>>('fz_pixmap_height')
        .asFunction();
    fz_pixmap_stride = lib
        .lookup<NativeFunction<_fz_pixmap_stride_native>>('fz_pixmap_stride')
        .asFunction();
    fz_drop_pixmap = lib
        .lookup<NativeFunction<_fz_drop_pixmap_native>>('fz_drop_pixmap')
        .asFunction();
    fz_device_rgb = lib
        .lookup<NativeFunction<_fz_device_rgb_native>>('fz_device_rgb')
        .asFunction();
    fz_new_draw_device = lib
        .lookup<NativeFunction<_fz_new_draw_device_native>>(
            'fz_new_draw_device')
        .asFunction();
    fz_close_device = lib
        .lookup<NativeFunction<_fz_close_device_native>>('fz_close_device')
        .asFunction();
    fz_drop_device = lib
        .lookup<NativeFunction<_fz_drop_device_native>>('fz_drop_device')
        .asFunction();
    fz_new_stext_page_from_page = lib
        .lookup<NativeFunction<_fz_new_stext_page_from_page_native>>(
            'fz_new_stext_page_from_page')
        .asFunction();
    fz_new_buffer_from_stext_page = lib
        .lookup<NativeFunction<_fz_new_buffer_from_stext_page_native>>(
            'fz_new_buffer_from_stext_page')
        .asFunction();
    fz_drop_stext_page = lib
        .lookup<NativeFunction<_fz_drop_stext_page_native>>(
            'fz_drop_stext_page')
        .asFunction();
    fz_search_page = lib
        .lookup<NativeFunction<_fz_search_page_native>>('fz_search_page')
        .asFunction();
    fz_buffer_storage = lib
        .lookup<NativeFunction<_fz_buffer_storage_native>>('fz_buffer_storage')
        .asFunction();
    fz_drop_buffer = lib
        .lookup<NativeFunction<_fz_drop_buffer_native>>('fz_drop_buffer')
        .asFunction();
    fz_load_outline = lib
        .lookup<NativeFunction<_fz_load_outline_native>>('fz_load_outline')
        .asFunction();
    fz_drop_outline = lib
        .lookup<NativeFunction<_fz_drop_outline_native>>('fz_drop_outline')
        .asFunction();
    fz_load_links = lib
        .lookup<NativeFunction<_fz_load_links_native>>('fz_load_links')
        .asFunction();
    fz_drop_link = lib
        .lookup<NativeFunction<_fz_drop_link_native>>('fz_drop_link')
        .asFunction();
    pdf_create_annot = lib
        .lookup<NativeFunction<_pdf_create_annot_native>>('pdf_create_annot')
        .asFunction();
    pdf_first_widget = lib
        .lookup<NativeFunction<_pdf_first_widget_native>>('pdf_first_widget')
        .asFunction();
    pdf_next_widget = lib
        .lookup<NativeFunction<_pdf_next_widget_native>>('pdf_next_widget')
        .asFunction();
    pdf_set_field_value = lib
        .lookup<NativeFunction<_pdf_set_field_value_native>>(
            'pdf_set_field_value')
        .asFunction();
    pdf_create_signature_widget = lib
        .lookup<NativeFunction<_pdf_create_signature_widget_native>>(
            'pdf_create_signature_widget')
        .asFunction();
    pdf_sign_signature = lib
        .lookup<NativeFunction<_pdf_sign_signature_native>>(
            'pdf_sign_signature')
        .asFunction();
    pdf_check_widget_certificate = lib
        .lookup<NativeFunction<_pdf_check_widget_certificate_native>>(
            'pdf_check_widget_certificate')
        .asFunction();
    pdf_check_widget_digest = lib
        .lookup<NativeFunction<_pdf_check_widget_digest_native>>(
            'pdf_check_widget_digest')
        .asFunction();
    pdf_clear_signature = lib
        .lookup<NativeFunction<_pdf_clear_signature_native>>(
            'pdf_clear_signature')
        .asFunction();
  }

  // --- Funções Vinculadas ---
  late final _fz_new_context_imp_dart _fz_new_context_imp;
  late final fz_drop_context_dart fz_drop_context;
  late final fz_register_document_handlers_dart fz_register_document_handlers;
  late final fz_open_document_dart fz_open_document;
  late final fz_needs_password_dart fz_needs_password;
  late final fz_authenticate_password_dart fz_authenticate_password;
  late final fz_count_pages_dart fz_count_pages;
  late final fz_lookup_metadata_dart fz_lookup_metadata;
  late final pdf_save_document_dart pdf_save_document;
  late final fz_drop_document_dart fz_drop_document;
  late final fz_load_page_dart fz_load_page;
  late final fz_bound_page_dart fz_bound_page;
  late final fz_run_page_dart fz_run_page;
  late final fz_drop_page_dart fz_drop_page;
  late final fz_new_pixmap_dart fz_new_pixmap;
  late final fz_clear_pixmap_with_value_dart fz_clear_pixmap_with_value;
  late final fz_pixmap_samples_dart fz_pixmap_samples;
  late final fz_pixmap_width_dart fz_pixmap_width;
  late final fz_pixmap_height_dart fz_pixmap_height;
  late final fz_pixmap_stride_dart fz_pixmap_stride;
  late final fz_drop_pixmap_dart fz_drop_pixmap;
  late final fz_device_rgb_dart fz_device_rgb;
  late final fz_new_draw_device_dart fz_new_draw_device;
  late final fz_close_device_dart fz_close_device;
  late final fz_drop_device_dart fz_drop_device;
  late final fz_new_stext_page_from_page_dart fz_new_stext_page_from_page;
  late final fz_new_buffer_from_stext_page_dart fz_new_buffer_from_stext_page;
  late final fz_drop_stext_page_dart fz_drop_stext_page;
  late final fz_search_page_dart fz_search_page;
  late final fz_buffer_storage_dart fz_buffer_storage;
  late final fz_drop_buffer_dart fz_drop_buffer;
  late final fz_load_outline_dart fz_load_outline;
  late final fz_drop_outline_dart fz_drop_outline;
  late final fz_load_links_dart fz_load_links;
  late final fz_drop_link_dart fz_drop_link;
  late final pdf_create_annot_dart pdf_create_annot;
  late final pdf_first_widget_dart pdf_first_widget;
  late final pdf_next_widget_dart pdf_next_widget;
  late final pdf_set_field_value_dart pdf_set_field_value;
  late final pdf_create_signature_widget_dart pdf_create_signature_widget;
  late final pdf_sign_signature_dart pdf_sign_signature;
  late final pdf_check_widget_certificate_dart pdf_check_widget_certificate;
  late final pdf_check_widget_digest_dart pdf_check_widget_digest;
  late final pdf_clear_signature_dart pdf_clear_signature;

  /// Wrapper para `fz_new_context_imp` que simula o macro C `fz_new_context`.
  fz_context fz_new_context(
      Pointer<Void> alloc, Pointer<Void> locks, int max_store,
      {String version = mupdfVersion}) {
    final versionPtr = mupdfVersion.toNativeUtf8();
    try {
      return _fz_new_context_imp(alloc, locks, max_store, versionPtr);
    } finally {
      malloc.free(versionPtr);
    }
  }

  /// Factory para abrir a biblioteca dinâmica e criar uma instância de MuPDFBindings.
  factory MuPDFBindings.open([String dllPath = 'libmupdf.dll']) {
    return MuPDFBindings(DynamicLibrary.open(dllPath));
  }
}
