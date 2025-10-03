//C:\MyDartProjects\pdf_tools\lib\src\mupdf.dart
import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'dart:math' show Rectangle;
import 'package:ffi/ffi.dart';
import 'mupdf_bindings.dart';

MuPDFBindings? _maybeBindings;
late final MuPDFBindings _bindings;

class MuPDFException implements Exception {
  final String message;
  MuPDFException(this.message);
  @override
  String toString() => 'MuPDFException: $message';
}

final class _DropToken extends Struct {
  external fz_context ctx;
  external Pointer<Void> obj;
}

// void _dropPixmapWrapper(Pointer<Void> token) {
//   final tokenPtr = token.cast<_DropToken>();
//   _bindings.fz_drop_pixmap(tokenPtr.ref.ctx, tokenPtr.ref.obj.cast());
//   calloc.free(tokenPtr);
// }

// void _dropPageWrapper(Pointer<Void> token) {
//   final tokenPtr = token.cast<_DropToken>();
//   _bindings.fz_drop_page(tokenPtr.ref.ctx, tokenPtr.ref.obj.cast());
//   calloc.free(tokenPtr);
// }

// void _dropDocumentWrapper(Pointer<Void> token) {
//   final tokenPtr = token.cast<_DropToken>();
//   _bindings.fz_drop_document(tokenPtr.ref.ctx, tokenPtr.ref.obj.cast());
//   calloc.free(tokenPtr);
// }

// void _dropContextWrapper(Pointer<Void> token) {
//   _bindings.fz_drop_context(token.cast());
// }

class MuPDFPixmap implements Finalizable {
  final fz_context _ctx;
  final fz_pixmap _pixmap;

  MuPDFPixmap._(this._ctx, this._pixmap) {
    final token = calloc<_DropToken>();
    token.ref.ctx = _ctx;
    token.ref.obj = _pixmap.cast();
    _finalizer.attach(this, token.cast(), detach: this);
  }

  static final _finalizer = Finalizer<Pointer<Void>>((token) {
    final t = token.cast<_DropToken>();
    _bindings.fz_drop_pixmap(t.ref.ctx, t.ref.obj.cast());
    calloc.free(t);
  });

  void dispose() {
    _finalizer.detach(this);
    _bindings.fz_drop_pixmap(_ctx, _pixmap);
  }

  int get width => _bindings.fz_pixmap_width(_ctx, _pixmap);
  int get height => _bindings.fz_pixmap_height(_ctx, _pixmap);
  int get stride => _bindings.fz_pixmap_stride(_ctx, _pixmap);
  Uint8List get pixels {
    final samplesPtr = _bindings.fz_pixmap_samples(_ctx, _pixmap);
    if (samplesPtr == nullptr) {
      throw MuPDFException("Não foi possível obter os samples do pixmap.");
    }
    return samplesPtr.asTypedList(stride * height);
  }
}

class MuPDFPage implements Finalizable {
  final fz_context _ctx;
  final fz_page _page;
  final int pageNumber;

  MuPDFPage._(this._ctx, this._page, this.pageNumber) {
    final token = calloc<_DropToken>();
    token.ref.ctx = _ctx;
    token.ref.obj = _page.cast();
    _finalizer.attach(this, token.cast(), detach: this);
  }

  static final _finalizer = Finalizer<Pointer<Void>>((token) {
    final tokenPtr = token.cast<_DropToken>();
    _bindings.fz_drop_page(tokenPtr.ref.ctx, tokenPtr.ref.obj.cast());
    calloc.free(tokenPtr);
  });

  void dispose() {
    _finalizer.detach(this);
    _bindings.fz_drop_page(_ctx, _page);
  }

  Rectangle<double> get bounds {
    final rect = _bindings.fz_bound_page(_ctx, _page);
    return Rectangle(rect.x0, rect.y0, rect.x1 - rect.x0, rect.y1 - rect.y0);
  }

  MuPDFPixmap render({double zoom = 1.0}) {
    fz_device dev = nullptr;
    final transform = calloc<fz_matrix>();
    fz_pixmap? pix;
    try {
      transform.ref.a = zoom;
      transform.ref.d = zoom;
      final pageBounds = bounds;
      final pixmapWidth = (pageBounds.width * zoom).round();
      final pixmapHeight = (pageBounds.height * zoom).round();
      final colorspace = _bindings.fz_device_rgb(_ctx);
      pix = _bindings.fz_new_pixmap(
          _ctx, colorspace, pixmapWidth, pixmapHeight, nullptr, 1);
      _bindings.fz_clear_pixmap_with_value(_ctx, pix, 255);
      dev = _bindings.fz_new_draw_device(_ctx, transform.ref, pix);
      _bindings.fz_run_page(_ctx, _page, dev, transform.ref, nullptr);
      _bindings.fz_close_device(_ctx, dev);
      return MuPDFPixmap._(_ctx, pix);
    } catch (e) {
      if (pix != null) _bindings.fz_drop_pixmap(_ctx, pix);
      rethrow;
    } finally {
      if (dev != nullptr) _bindings.fz_drop_device(_ctx, dev);
      calloc.free(transform);
    }
  }
}

class MuPDFDocument implements Finalizable {
  final fz_context _ctx;
  final fz_document _doc;

  MuPDFDocument._(this._ctx, this._doc) {
    final token = calloc<_DropToken>();
    token.ref.ctx = _ctx;
    token.ref.obj = _doc.cast();
    _finalizer.attach(this, token.cast(), detach: this);
  }

  static final _finalizer = Finalizer<Pointer<Void>>((token) {
    final tokenPtr = token.cast<_DropToken>();
    _bindings.fz_drop_document(tokenPtr.ref.ctx, tokenPtr.ref.obj.cast());
    calloc.free(tokenPtr);
  });

  void dispose() {
    _finalizer.detach(this);
    _bindings.fz_drop_document(_ctx, _doc);
  }

  int get pageCount => _bindings.fz_count_pages(_ctx, _doc);

  MuPDFPage loadPage(int pageNumber) {
    if (pageNumber < 0 || pageNumber >= pageCount) {
      throw ArgumentError('Número de página inválido: $pageNumber');
    }
    final page = _bindings.fz_load_page(_ctx, _doc, pageNumber);
    if (page == nullptr) {
      throw MuPDFException('Não foi possível carregar a página $pageNumber.');
    }
    return MuPDFPage._(_ctx, page, pageNumber);
  }

  String? getMetadata(String key) {
    return using((arena) {
      final cKey = key.toNativeUtf8(allocator: arena);
      const bufferSize = 256;
      final cValue = arena<Uint8>(bufferSize).cast<Utf8>();
      final neededSize =
          _bindings.fz_lookup_metadata(_ctx, _doc, cKey, cValue, bufferSize);
      if (neededSize < 0) return null;
      if (neededSize > bufferSize) {
        final newCValue = arena<Uint8>(neededSize).cast<Utf8>();
        _bindings.fz_lookup_metadata(_ctx, _doc, cKey, newCValue, neededSize);
        return newCValue.toDartString();
      }
      return cValue.toDartString();
    });
  }

  /// Salva o documento em um novo arquivo, reescrevendo sua estrutura.
  /// Ideal para reparar arquivos com tabelas xref corrompidas.
  void saveDocument(String outputPath) {
    final optionsPtr = calloc<pdf_write_options>();
    try {
      final options = optionsPtr.ref;
      // Opções simples para apenas reescrever e consertar o arquivo.
      options.do_garbage = 1; // Coleta de lixo leve
      options.do_clean = 1; // Limpa a sintaxe
      options.do_sanitize = 1; // Sanitiza

      final cPath = outputPath.toNativeUtf8();
      try {
        _bindings.pdf_save_document(_ctx, _doc.cast(), cPath, optionsPtr);
      } finally {
        calloc.free(cPath);
      }
    } finally {
      calloc.free(optionsPtr);
    }
  }

  /// Salva o documento em um novo arquivo com opções de otimização.
  ///
  /// Mapeia as opções comuns de otimização para a API do MuPDF.
  /// NOTA: O downsampling de imagens não é uma opção direta aqui,
  /// requer uma abordagem mais complexa de reescrita de imagens.
  void saveOptimized(
    String outputPath, {
    bool garbageCollect = true,
    bool decompress = false,
    bool recompress = true,
    bool sanitize = true,
  }) {
    // Aloca a struct de opções na memória nativa
    final optionsPtr = calloc<pdf_write_options>();

    try {
      // Preenche a struct com os valores desejados
      final options = optionsPtr.ref;
      options.do_incremental =
          0; // Salvar como um novo arquivo, não incrementalmente
      options.do_garbage = garbageCollect ? 1 : 0; // 1 para coletar lixo
      options.do_decompress = decompress ? 1 : 0;
      options.do_compress = recompress ? 1 : 0;
      options.do_compress_fonts = recompress ? 1 : 0;
      options.do_compress_images = recompress ? 1 : 0;
      options.do_sanitize = sanitize ? 1 : 0;
      options.do_clean = sanitize
          ? 1
          : 0; // 'clean' é frequentemente usado junto com 'sanitize'

      final cPath = outputPath.toNativeUtf8();
      try {
        _bindings.pdf_save_document(_ctx, _doc, cPath, optionsPtr);
      } finally {
        calloc.free(cPath);
      }
    } finally {
      // Libera a memória da struct de opções
      calloc.free(optionsPtr);
    }
  }
}

enum DownsampleMethod { average, bicubic, subsample }

enum RecompressMethod { never, same, lossless, jpeg, j2k, fax }

class MuPDFContext implements Finalizable {
  final fz_context _ctx;

  MuPDFContext._(this._ctx) {
    _finalizer.attach(this, _ctx, detach: this);
  }

  static final _finalizer = Finalizer<Pointer<Void>>((token) {
    _bindings.fz_drop_context(token.cast());
  });

  factory MuPDFContext.initialize({String? libraryPath}) {
    // Inicializa bindings UMA única vez
    if (_maybeBindings == null) {
      final path = libraryPath ?? _getLibraryPath();
      _maybeBindings = MuPDFBindings.open(path);
      _bindings =
          _maybeBindings!; // primeira (e única) atribuição do late final
    }

    // Daqui para frente só usa o que já foi aberto
    final ctx = _maybeBindings!.fz_new_context(nullptr, nullptr, 0);
    if (ctx == nullptr) {
      throw MuPDFException('Não foi possível criar o contexto do MuPDF.');
    }
    _maybeBindings!.fz_register_document_handlers(ctx);
    return MuPDFContext._(ctx);
  }

  static String _getLibraryPath() {
    if (Platform.isWindows) {
      return 'libmupdf.dll';
    } else if (Platform.isLinux || Platform.isAndroid) {
      return 'libmupdf.so';
    } else if (Platform.isMacOS) {
      return 'libmupdf.dylib';
    } else {
      throw UnsupportedError(
          'Sistema operacional não suportado: ${Platform.operatingSystem}');
    }
  }

  void dispose() {
    _finalizer.detach(this);
    _bindings.fz_drop_context(_ctx);
  }

  MuPDFDocument openDocument(String filePath) {
    return using((arena) {
      final cPath = filePath.toNativeUtf8(allocator: arena);
      final doc = _bindings.fz_open_document(_ctx, cPath);
      if (doc == nullptr) {
        throw MuPDFException('Não foi possível abrir o documento: $filePath');
      }
      return MuPDFDocument._(_ctx, doc);
    });
  }

  /// Otimiza um arquivo PDF, incluindo limpeza, recompressão e downsampling de imagens.
  /// Esta é uma operação poderosa que reescreve o arquivo inteiro.
  void cleanAndOptimize({
    required String inputFile,
    required String outputFile,
    String? password,
    int colorImageDPI = 150,
    int grayImageDPI = 150,
    int monoImageDPI = 300,
  }) {
    // Aloca a estrutura de opções de limpeza na memória nativa
    final cleanOptsPtr = calloc<pdf_clean_options>();

    try {
      final cleanOpts = cleanOptsPtr.ref;

      // --- Configurações Gerais de Limpeza ---
      // Não salvar incrementalmente
      cleanOpts.write.do_incremental = 0;
      // Garbage collect agressivo (de-duplicate)
      cleanOpts.write.do_garbage = 3;
      // Comprimir fluxos
      cleanOpts.write.do_compress = 1;
      cleanOpts.write.do_compress_fonts = 1;
      cleanOpts.write.do_compress_images = 1;
      cleanOpts.write.do_sanitize = 1;
      cleanOpts.write.do_clean = 1;
      cleanOpts.subset_fonts = 1;

      // --- Configurações de Downsampling de Imagem ---
      final imageOpts = cleanOpts.image;

      // Imagens coloridas
      imageOpts.color_lossy_image_subsample_threshold = colorImageDPI;
      imageOpts.color_lossy_image_subsample_to = colorImageDPI;
      // 0 = Average
      imageOpts.color_lossy_image_subsample_method =
          DownsampleMethod.average.index;

      // Imagens em escala de cinza
      // (Assumindo que os campos existem no seu struct, se não, adicione-os)
      // imageOpts.gray_lossy_image_subsample_threshold = grayImageDPI;
      // imageOpts.gray_lossy_image_subsample_to = grayImageDPI;
      // imageOpts.gray_lossy_image_subsample_method = DownsampleMethod.average.index;

      // Imagens monocromáticas
      // (Assumindo que os campos existem no seu struct, se não, adicione-os)
      // imageOpts.bitonal_image_subsample_threshold = monoImageDPI;
      // imageOpts.bitonal_image_subsample_to = monoImageDPI;
      // imageOpts.bitonal_image_subsample_method = DownsampleMethod.subsample.index; // 2 = Subsample

      using((arena) {
        final cInputFile = inputFile.toNativeUtf8(allocator: arena);
        final cOutputFile = outputFile.toNativeUtf8(allocator: arena);
        final cPassword = password?.toNativeUtf8(allocator: arena) ?? nullptr;

        // A função C espera um array de strings para 'retainlist',
        // que não usaremos, então passamos 0 e nullptr.
        _bindings.pdf_clean_file(
            _ctx, cInputFile, cOutputFile, cPassword, cleanOptsPtr, 0, nullptr);
      });
    } finally {
      calloc.free(cleanOptsPtr);
    }
  }
}
