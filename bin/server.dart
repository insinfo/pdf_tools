// ignore_for_file: constant_identifier_names, prefer_function_declarations_over_variables, unnecessary_brace_in_string_interps

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import 'package:pdf_tools/src/gs_stdio_/ghostscript.dart' as gs_api;
import 'package:pdf_tools/src/mupdf.dart' as mupdf_api;
import 'package:pdf_tools/src/qpdf.dart' as qpdf_api;

final _uuid = const Uuid();

// --- CONFIGURAÇÕES GLOBAIS DE PERFORMANCE ---
const MAX_CONCURRENT_FILES =
    6; // Máximo de PDFs processados simultaneamente pela API.
const MIN_PAGES_FOR_SPLIT =
    4; // A partir de quantas páginas um PDF é dividido em isolates.
const MAX_ISOLATES_PER_PDF =
    8; // Máximo de isolates (cores de CPU) para um único PDF.

final _fileQueueSemaphore = _AsyncSemaphore(MAX_CONCURRENT_FILES);
int get _filesInQueue => _fileQueueSemaphore.inUse;
int get _filesMaxQueue => _fileQueueSemaphore.max;

typedef _Job = Map<String, Object?>;
typedef _JobRes = Map<String, Object?>;

Future<_JobRes> _compressIsolate(_Job job) async {
  final send = job['send'] as SendPort?;
  final input = job['input'] as String;
  final output = job['output'] as String;

  final firstPage = job['firstPage'] as int?;
  final lastPage = job['lastPage'] as int?;
  final dpi = job['dpi'] as int;
  final quality = job['quality'] as String;
  final jpegQuality = job['jpegQuality'] as int; // NOVO
  final mode = (job['mode'] as String?) ?? 'color';
  final isolateId = job['isolateId'] as String;

  void emit(Map<String, Object?> m) {
    m['ts'] = DateTime.now().millisecondsSinceEpoch;
    send?.send(m);
  }

  try {
    emit({
      'stage': 'start',
      'isolateId': isolateId,
      'totalPagesInJob': (lastPage! - firstPage! + 1),
      'firstPage': firstPage,
    });

    final args = _gsArgs(
        input: input,
        output: output,
        dpi: dpi,
        quality: quality,
        jpegQuality: jpegQuality, // NOVO
        first: firstPage,
        last: lastPage,
        mode: mode);
    print('[$isolateId] Ghostscript Args: ${args.join(' ')}');
    emit({'stage': 'gs-args', 'args': args});

    final re = RegExp(r'^\s*Page\s+(\d+)\s*$', caseSensitive: false);
    final gs = gs_api.Ghostscript.open();
    var pdfWasRepaired = false;
    int rc = -1;

    // MUDANÇA: try/finally para garantir o fechamento do Ghostscript
    try {
      rc = gs.runWithProgress(args, (String line) {
        print('[$isolateId] GS > $line');
        emit({'stage': 'gs-line', 'line': line.trim()});
        if (line.contains('xref table was repaired')) {
          pdfWasRepaired = true;
        }
        final m = re.firstMatch(line);
        if (m != null) {
          final pNum = int.tryParse(m.group(1)!);
          if (pNum != null) {
            emit({'stage': 'page', 'page': pNum, 'isolateId': isolateId});
          }
        }
      });
    } finally {
      // gs.close() ou gs.dispose(), dependendo da sua API. Usando close() como pedido.
      try {
        (gs as dynamic).close();
      } catch (_) {}
    }

    if (pdfWasRepaired) {
      emit({'stage': 'repaired'});
    }

    print('[$isolateId] Ghostscript finalizado com rc=$rc');
    if (rc < 0) throw gs_api.GhostscriptException(rc);

    final outSize = await File(output).length();
    return {'rc': rc, 'outSize': outSize, 'finalPath': output};
  } catch (e, st) {
    print('[$isolateId] ERRO NO ISOLATE: $e\n$st');
    emit({'stage': 'error', 'error': e.toString()});
    return {'rc': -1, 'outSize': 0, 'error': e.toString()};
  }
}

Future<void> main(List<String> args) async {
  final ip = InternetAddress.anyIPv4;
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final router = Router()
    ..get('/health', _health)
    ..get('/', (req) => Response.found('/ui'))
    ..get('/assets/<path|.*>', _asset)
    ..get('/ui', _ui)
    ..post('/compress', _compress)
    ..get('/progress/<id>', (req, String id) => _progressSse(req, id))
    ..get('/status', (req) {
      final s = jsonEncode({
        'cpus': Platform.numberOfProcessors,
        'pdfProcessingQueue': {'inUse': _filesInQueue, 'max': _filesMaxQueue},
        'activeJobs': _jobs.length,
      });
      return Response.ok(s, headers: {'content-type': 'application/json'});
    });

  final handler = Pipeline()
      .addMiddleware(_logRequestsWithoutBody())
      .addMiddleware(_cors())
      .addHandler(router.call);

  final server = await serve(handler, ip, port, shared: true);
  final host = server.address.host;
  print('Octopus PDF API ouvindo em http://$host:${server.port}');
  print(
      'GUI WEB http://${host == '0.0.0.0' ? 'localhost' : host}:${server.port}/ui');
}

Future<Response> _asset(Request req, String path) async {
  // evita subir fora da pasta
  final safe = path.replaceAll('\\', '/');
  final file = File(p.join('assets', safe));
  if (!await file.exists()) return Response.notFound('asset not found');

  // content-type básico
  final ext = p.extension(safe).toLowerCase();
  final ct = switch (ext) {
    '.svg' => 'image/svg+xml; charset=utf-8',
    '.png' => 'image/png',
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.css' => 'text/css; charset=utf-8',
    '.js' => 'application/javascript; charset=utf-8',
    _ => 'application/octet-stream',
  };

  return Response.ok(file.openRead(),
      headers: {HttpHeaders.contentTypeHeader: ct});
}

// Middleware de log personalizado
Middleware _logRequestsWithoutBody() {
  return (innerHandler) {
    return (request) {
      final startTime = DateTime.now();
      final watch = Stopwatch()..start();

      return Future.sync(() => innerHandler(request)).then((response) {
        final log =
            '${startTime.toIso8601String()} ${watch.elapsed} ${request.method.padRight(7)} [${response.statusCode}] ${request.requestedUri}';
        print(log);
        return response;
      }, onError: (Object error, StackTrace stackTrace) {
        if (error is HijackException) throw error;
        final log =
            '${startTime.toIso8601String()} ${watch.elapsed} ${request.method.padRight(7)} ${request.requestedUri}\n$error';
        print('ERROR - $log');
        // ignore: only_throw_errors
        throw error;
      });
    };
  };
}

Future<int> _getPageCount(String path) async {
  mupdf_api.MuPDFContext? context;
  mupdf_api.MuPDFDocument? document;
  try {
    context = mupdf_api.MuPDFContext.initialize();
    document = context.openDocument(path);
    return document.pageCount;
  } finally {
    document?.dispose();
    context?.dispose();
  }
}

Future<void> _mergePdfs(List<String> inputPaths, String outputPath) async {
  final qpdf = qpdf_api.Qpdf.open();
  final args = ['--empty', '--pages', ...inputPaths, '--'];
  final rc = qpdf.run(args, outputPath: outputPath);
  if (rc != 0) {
    throw qpdf_api.QpdfException(rc, "Falha ao mesclar PDFs");
  }
}

// SUBSTITUA A SUA FUNÇÃO _compress POR ESTA
Future<Response> _compress(Request req) async {
  final reqStart = DateTime.now();
  final reqId = _uuid.v4().substring(0, 8);
  print('[$reqId] /compress recebido');

  final ct = req.headers[HttpHeaders.contentTypeHeader];
  if (ct == null || !ct.toLowerCase().startsWith('multipart/form-data')) {
    return Response(415,
        body: 'Content-Type multipart/form-data é obrigatório.');
  }

  final boundary = MediaType.parse(ct).parameters['boundary']!;
  final tmpRoot =
      Directory(p.join(Directory.systemTemp.path, 'pdf-compressor-server'));
  await tmpRoot.create(recursive: true);

  File? uploaded;
  String? originalName;
  final fields = <String, String>{};
  final jobId = req.url.queryParameters['jobId'] ?? _uuid.v4();
  final prog = _ensureJob(jobId);
  print('[$reqId] Job ID: $jobId');

  try {
    final partsStream =
        MimeMultipartTransformer(boundary).bind(req.read().cast<List<int>>());
    await for (final part in partsStream) {
      final cd = part.headers['content-disposition']!;
      final disp = HeaderValue.parse(cd, preserveBackslash: true);
      final name = disp.parameters['name'];
      final filename = disp.parameters['filename'];
      if (filename != null && name == 'file') {
        originalName = filename;
        final tmpPath = p.join(tmpRoot.path, '${_uuid.v4()}-upload.pdf');
        uploaded = File(tmpPath);
        await part.pipe(uploaded.openWrite());
        final size = await uploaded.length();
        print('[$reqId] Upload concluído: $originalName ($size bytes)');
        prog.emit({'stage': 'upload-done', 'bytes': size});
      } else if (name != null) {
        final bytes =
            await part.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
        fields[name] = utf8.decode(bytes);
      }
    }
  } catch (e) {
    print('[$reqId] Erro no upload: $e');
    return Response.internalServerError(body: "Erro no upload: $e");
  }

  if (uploaded == null) {
    return Response(400, body: 'campo "file" não encontrado');
  }

  // MUDANÇA: Validação de assinatura PDF mais robusta
  try {
    final raf = await uploaded.open();
    // Lê um pouco mais para encontrar o header, ignorando possíveis bytes no início (BOM)
    final bytes = await raf.read(1024);
    await raf.close();
    final txt = utf8.decode(bytes, allowMalformed: true);
    if (!txt.contains('%PDF-')) {
      return Response(400, body: 'Arquivo não parece ser um PDF válido.');
    }
  } catch (e) {
    return Response(500, body: 'Erro ao ler arquivo para validação: $e');
  }

  return _fileQueueSemaphore.withPermit<Response>(() async {
    final List<String> tempFiles = [uploaded!.path];
    StreamSubscription? sub;
    ReceivePort? progressPort;

    try {
      print('[$reqId] Iniciando processamento do arquivo: ${uploaded.path}');
      final totalPagesInFile = await _getPageCount(uploaded.path);
      if (totalPagesInFile <= 0) {
        throw Exception("PDF inválido ou sem páginas.");
      }

      final inSize = await uploaded.length();
      final userFirstPage = int.tryParse(fields['firstPage'] ?? '');
      final userLastPage = int.tryParse(fields['lastPage'] ?? '');

      int firstPageToProcess = userFirstPage ?? 1;
      int lastPageToProcess = userLastPage ?? totalPagesInFile;
      if (firstPageToProcess < 1) firstPageToProcess = 1;
      if (lastPageToProcess > totalPagesInFile) {
        lastPageToProcess = totalPagesInFile;
      }
      if (firstPageToProcess > lastPageToProcess) {
        // Opção: retornar um erro 400 aqui. Por enquanto, ajustamos.
        firstPageToProcess = lastPageToProcess;
      }

      final totalPagesToProcess = (lastPageToProcess - firstPageToProcess) + 1;

      print(
          '[$reqId] Intervalo de páginas a ser processado: $firstPageToProcess - $lastPageToProcess (Total: $totalPagesToProcess páginas)');

      prog.emit({
        'stage': 'queued',
        'totalPages': totalPagesToProcess,
        'inSize': inSize
      });

      String finalCompressedPath;
      final engine = (fields['engine'] ?? 'gs').toLowerCase();
      print('[$reqId] Usando engine: $engine');

      // MUDANÇA: Lógica de ramificação para QPDF vs Ghostscript
      if (engine == 'qpdf') {
        prog.emit({'stage': 'processing'});
        final q = qpdf_api.Qpdf.open();

        // Passo 1: Aplica o intervalo de páginas
        String pathAfterRange = uploaded.path;
        if (userFirstPage != null || userLastPage != null) {
          final tmpRangePath = p.join(tmpRoot.path, '${_uuid.v4()}-range.pdf');
          final rangeSpec = '$firstPageToProcess-$lastPageToProcess';
          print(
              '[$reqId] Aplicando intervalo com QPDF: --pages ${uploaded.path} $rangeSpec --');
          final rcRange = q.run(
              ['--empty', '--pages', uploaded.path, rangeSpec, '--'],
              outputPath: tmpRangePath);
          if (rcRange != 0) {
            throw qpdf_api.QpdfException(
                rcRange, 'Falha ao aplicar intervalo (QPDF)');
          }
          tempFiles.add(tmpRangePath);
          pathAfterRange = tmpRangePath;
        }

        // Passo 2: Lineariza
        prog.emit({'stage': 'linearizing'});
        final linPath = p.join(tmpRoot.path, '${_uuid.v4()}-linearized.pdf');
        print('[$reqId] Linearizando com QPDF: --linearize $pathAfterRange');
        final rcLin =
            q.run(['--linearize', pathAfterRange], outputPath: linPath);
        if (rcLin != 0) {
          throw qpdf_api.QpdfException(rcLin, 'Falha ao linearizar (QPDF)');
        }

        tempFiles.add(linPath);
        finalCompressedPath = linPath;
        prog.emit({'stage': 'done'});
      } else {
        // engine == 'gs' (lógica original)
        progressPort = ReceivePort();
        sub = progressPort.listen((msg) {
          if (msg is Map) prog.emit(msg.cast<String, Object?>());
        });

        if (totalPagesToProcess < MIN_PAGES_FOR_SPLIT) {
          print(
              '[$reqId] PDF/Intervalo pequeno ($totalPagesToProcess páginas), processando em um único isolate.');
          final outPath = p.join(tmpRoot.path, '${_uuid.v4()}-compressed.pdf');
          tempFiles.add(outPath);
          final job = _createJob(
              fields, uploaded.path, outPath, totalPagesToProcess,
              firstPage: firstPageToProcess,
              lastPage: lastPageToProcess,
              sendPort: progressPort.sendPort,
              isolateId: '$reqId-main');
          final result = await _runIsolate(job);
          if ((result['rc'] as int) < 0) throw Exception(result['error']);
          finalCompressedPath = result['finalPath'] as String;
        } else {
          final cpus =
              Platform.numberOfProcessors.clamp(2, MAX_ISOLATES_PER_PDF);
          final chunks = min(cpus, (totalPagesToProcess / 2).ceil());
          final pagesPerChunk = (totalPagesToProcess / chunks).ceil();
          print(
              '[$reqId] PDF/Intervalo grande ($totalPagesToProcess páginas), dividindo em $chunks isolates.');

          final futures = <Future<_JobRes>>[];
          final outParts = <String>[];

          for (var i = 0; i < chunks; i++) {
            final start = firstPageToProcess + i * pagesPerChunk;
            final end = (i == chunks - 1)
                ? lastPageToProcess
                : min(lastPageToProcess, start + pagesPerChunk - 1);
            if (start > end) break;

            final partPath =
                p.join(tmpRoot.path, '${_uuid.v4()}-part${i + 1}.pdf');
            outParts.add(partPath);
            tempFiles.add(partPath);

            final job = _createJob(
                fields, uploaded.path, partPath, totalPagesToProcess,
                firstPage: start,
                lastPage: end,
                sendPort: progressPort.sendPort,
                isolateId: '$reqId-iso${i + 1}');
            futures.add(_runIsolate(job));
          }

          final results = await Future.wait(futures);
          for (final r in results) {
            if ((r['rc'] as int) < 0) {
              throw Exception(r['error'] ?? 'Erro em um dos isolates.');
            }
          }

          print('[$reqId] Mesclando ${outParts.length} partes.');
          prog.emit({'stage': 'merging'});
          final mergedPath = p.join(tmpRoot.path, '${_uuid.v4()}-merged.pdf');
          tempFiles.add(mergedPath);
          await _mergePdfs(outParts, mergedPath);
          finalCompressedPath = mergedPath;
          print('[$reqId] Mesclagem concluída para: $mergedPath');
        }

        final wantsLinearize =
            (fields['linearize'] ?? '').toLowerCase() == 'true';
        if (wantsLinearize) {
          print('[$reqId] Linearizando o PDF final com QPDF.');
          prog.emit({'stage': 'linearizing'});
          final linPath = p.join(tmpRoot.path, '${_uuid.v4()}-linearized.pdf');
          final rc = qpdf_api.Qpdf.open()
              .run(['--linearize', finalCompressedPath], outputPath: linPath);
          if (rc != 0) {
            throw qpdf_api.QpdfException(rc, 'Falha ao linearizar (QPDF)');
          }
          tempFiles.add(linPath);
          finalCompressedPath = linPath;
        }
      }

      final outFile = File(finalCompressedPath);
      final outSize = await outFile.length();
      final safeName = (originalName ?? 'output.pdf').replaceAll('"', '');
      final elapsed = DateTime.now().difference(reqStart).inSeconds;

      print(
          '[$reqId] finalizado in=$inSize out=$outSize tempo=${elapsed}s. Iniciando stream de resposta.');

      prog.emit({'stage': 'stats', 'elapsed': elapsed});

      StreamSubscription<List<int>>? fileSub;
      late final StreamController<List<int>> ctrl;
      ctrl = StreamController<List<int>>(
        onListen: () {
          final source = outFile.openRead();
          fileSub = source.listen(
            ctrl.add,
            onError: ctrl.addError,
            onDone: () async {
              await ctrl.close();
              print('[$reqId] Stream da resposta finalizado (onDone).');
              prog.emit({'stage': 'done'});
            },
          );
        },
        onCancel: () async {
          await fileSub?.cancel();
          print('[$reqId] Conexão cancelada pelo cliente.');
        },
      );

      ctrl.done.whenComplete(() async {
        print('[$reqId] Limpando arquivos temporários: $tempFiles');
        for (final path in tempFiles) {
          try {
            await File(path).delete();
          } catch (e) {
            print('[$reqId] Erro ao deletar arquivo temporário $path: $e');
          }
        }
        prog.close();
        _jobs.remove(jobId);
        print('[$reqId] Limpeza concluída.');
      });

      return Response.ok(ctrl.stream, headers: {
        HttpHeaders.contentTypeHeader: 'application/pdf',
        'content-disposition': 'attachment; filename="$safeName"',
        'x-original-size': '$inSize',
        'x-compressed-size': '$outSize',
      });
    } catch (e, st) {
      stderr.writeln('[$reqId] Erro no processamento principal: $e\n$st');
      prog.emit({'stage': 'error', 'error': e.toString()});
      for (final path in tempFiles) {
        // ignore: body_might_complete_normally_catch_error
        File(path).delete().catchError((e) {
          print(
              '[$reqId] Erro (no bloco catch) ao deletar arquivo temporário $path: $e');
        });
      }
      prog.close();
      _jobs.remove(jobId);
      return Response.internalServerError(body: 'Falha ao comprimir PDF: $e');
    } finally {
      await sub?.cancel();
      progressPort?.close();
    }
  });
}

_Job _createJob(Map<String, String> fields, String inputPath, String outputPath,
    int totalPages,
    {int? firstPage,
    int? lastPage,
    required SendPort sendPort,
    required String isolateId}) {
  final dpi = int.tryParse(fields['dpi'] ?? '150') ?? 150;
  final quality = (fields['quality'] ?? 'default').toLowerCase();
  final mode = (fields['mode'] ?? 'color').toLowerCase();
  // NOVO: Lê a qualidade JPEG do formulário, com um padrão razoável
  final jpegQuality = int.tryParse(fields['jpegQuality'] ?? '65') ?? 65;

  return {
    'input': inputPath,
    'output': outputPath,
    'totalPages': totalPages,
    'firstPage': firstPage,
    'lastPage': lastPage,
    'dpi': dpi,
    'quality': quality,
    'mode': mode,
    'send': sendPort,
    'isolateId': isolateId,
    'jpegQuality': jpegQuality,
  };
}

Future<_JobRes> _runIsolate(_Job job) async {
  final resultPort = ReceivePort();
  await Isolate.spawn(
      _compressIsolateEntry, {'result': resultPort.sendPort, 'job': job},
      errorsAreFatal: true);
  final result = await resultPort.first as Map;
  resultPort.close();
  return result.cast<String, Object?>();
}

Future<void> _compressIsolateEntry(Map<String, Object?> msg) async {
  final SendPort result = msg['result'] as SendPort;
  final _Job job = (msg['job'] as Map).cast<String, Object?>();
  try {
    final _JobRes res = await _compressIsolate(job);
    result.send(res);
  } catch (e, st) {
    result.send({'rc': -1, 'error': '$e', 'stack': '$st'});
  }
}

class _AsyncSemaphore {
  _AsyncSemaphore(this._max);
  final int _max;
  int _inUse = 0;
  final _waiters = <Completer<void>>[];
  int get inUse => _inUse;
  int get max => _max;
  Future<T> withPermit<T>(Future<T> Function() action) async {
    if (_inUse >= _max) {
      final c = Completer<void>();
      _waiters.add(c);
      await c.future;
    }
    _inUse++;
    try {
      return await action();
    } finally {
      _inUse--;
      if (_waiters.isNotEmpty) {
        _waiters.removeAt(0).complete();
      }
    }
  }
}

Response _health(Request _) => Response.ok(jsonEncode({'status': 'ok'}),
    headers: {'content-type': 'application/json'});

List<String> _gsArgs({
  required String input,
  required String output,
  required int dpi,
  required String quality,
  required int jpegQuality,
  String mode = 'color',
  int? first,
  int? last,
}) {
  final profiles = {
    'screen': ['-dPDFSETTINGS=/screen'],
    'ebook': ['-dPDFSETTINGS=/ebook'],
    'printer': ['-dPDFSETTINGS=/printer'],
    'prepress': ['-dPDFSETTINGS=/prepress'],
    'default': ['-dPDFSETTINGS=/default']
  };
  final qualityArgs = profiles[quality] ?? profiles['default']!;

  final args = <String>[
    '-dSAFER',
    '-dBATCH',
    '-dNOPAUSE',
    '-sDEVICE=pdfwrite',
    '-o',
    output,
    if (first != null) '-dFirstPage=$first',
    if (last != null) '-dLastPage=$last',
    ...qualityArgs,
    '-dDetectDuplicateImages=true',
    '-dCompressFonts=true',
    '-dSubsetFonts=true',
    '-dColorImageResolution=$dpi',
    '-dGrayImageResolution=$dpi',
    '-dMonoImageResolution=${dpi * 2}',
    '-dAutoRotatePages=/None',
  ];

  switch (mode) {
    case 'gray':
      args.addAll([
        '-sProcessColorModel=DeviceGray',
        '-sColorConversionStrategy=Gray',
        '-dOverrideICC=true'
      ]);
      break;
    

    case 'bilevel':
      args.addAll([
        // converte tudo para cinza
        '-sProcessColorModel=DeviceGray',
        '-sColorConversionStrategy=Gray',
        '-dOverrideICC=true',

        // NÃO forçar filtros mono aqui (evita conflito com imagens não-1bpp)
        // Otimizações "fortes" em cinza para reduzir tamanho:
        '-dDownsampleGrayImages=true',
        '-dGrayImageDownsampleType=/Subsample',
        '-dGrayImageResolution=${dpi}', // pode usar dpi*1.3 se quiser apertar mais
      ]);
      break;
    default:
      break;
  }
  args.add(input);
  return args;
}

Middleware _cors() {
  const allowHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Origin,Content-Type,Accept',
    // MELHORIA 1 (Bônus): Expor headers customizados para clientes de outros domínios.
    'Access-Control-Expose-Headers':
        'content-disposition,x-original-size,x-compressed-size',
  };
  Response options(Request req) => Response.ok('', headers: allowHeaders);
  return (Handler inner) {
    return (Request req) async {
      if (req.method == 'OPTIONS') return options(req);
      final res = await inner(req);
      return res.change(headers: allowHeaders);
    };
  };
}

class _Prog {
  final ctrl = StreamController<String>.broadcast();
  void emit(Map<String, Object?> data) {
    if (!ctrl.isClosed) ctrl.add('data: ${jsonEncode(data)}\n\n');
  }

  void close() {
    if (!ctrl.isClosed) ctrl.close();
  }
}

final Map<String, _Prog> _jobs = {};
_Prog _ensureJob(String id) => _jobs.putIfAbsent(id, () => _Prog());
Response _progressSse(Request req, String id) {
  final job = _ensureJob(id);
  final headers = {
    HttpHeaders.contentTypeHeader: 'text/event-stream; charset=utf-8',
    HttpHeaders.cacheControlHeader: 'no-cache',
    HttpHeaders.connectionHeader: 'keep-alive'
  };
  final byteStream = job.ctrl.stream.map(utf8.encode);
  return Response.ok(byteStream, headers: headers);
}

Response _ui(Request _) {
  const html = r'''
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <title>Octopus PDF</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css" rel="stylesheet">
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js"></script>

  <style>
    :root { font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial; } body { margin: 10px; max-width: 900px; } h1 { margin: 0 0 16px; } form, .card { border: 1px solid #ddd; border-radius: 12px; padding: 16px; } .row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; } .row3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 12px; } label { font-weight: 600; display: block; margin-bottom: 6px;} input[type="number"], input[type="range"] { width: 100%; box-sizing: border-box; } .muted { color: #666; font-size: .9rem; } button { padding: 10px 16px; border-radius: 10px; border: 1px solid #ccc; cursor: pointer; } button:disabled { cursor: not-allowed; background-color: #eee; } progress { width: 100%; height: 16px; } .hidden { display:none; } .ok { color: #0a7c2f; } .err { color: #b00020; white-space: pre-wrap;} .stats { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; } fieldset { border: 1px dashed #ddd; border-radius: 10px; padding: 10px 12px; } fieldset:disabled { opacity: 0.6; } fieldset legend { padding: 0 6px; color: #555; font-size: .95rem; } .inline { display:flex; gap:14px; align-items:center; flex-wrap: wrap; }
  </style>
</head>
<body>
  <div style="display:flex;align-items:center;gap:12px;margin-bottom:8px">
    <img src="/assets/logo_octopus_pdf.svg" alt="Octopus PDF" style="height:90px">
    <h1 style="margin:0">Octopus PDF</h1>
  </div>
  <p class="muted">Faça upload de um PDF grande e receba o arquivo comprimido. Você também pode chamar a API direto em <code>POST /compress</code> (multipart/form-data).</p>
  <form id="f" class="card">
    <fieldset id="form-fields">
      <div class="row">
        <div>
          <label>Arquivo PDF</label>
          <input required type="file" id="file" name="file" accept="application/pdf">
          <div id="file-info" class="muted" style="margin-top: 4px; min-height: 1.2em;"></div>
        </div>
        <div>
          <label>Engine</label>
          <select name="engine" id="engine">
            <option value="gs" selected>Ghostscript (melhor redução)</option>
            <option value="qpdf">QPDF (rápido; só lineariza)</option>
          </select>
          <div class="muted" style="margin-top:6px">
            <small>• <b>Ghostscript</b>: reduz tamanho (downsample/qualidade).<br> • <b>QPDF</b>: não reduz, apenas <i>lineariza</i> (otimiza para web).</small>
          </div>
        </div>
      </div>

      <div id="gs-options">
        <div class="row3" style="margin-top:12px">
          <div>
            <label>Qualidade (Preset)</label>
            <select name="quality" id="quality">
              <option value="default" selected>Padrão</option> <option value="screen">Tela (menor)</option> <option value="ebook">E-book</option> <option value="printer">Impressora</option> <option value="prepress">Gráfica (maior)</option>
            </select>
          </div>
          <div>
            <label>DPI</label>
            <input type="number" id="dpi" name="dpi" min="72" max="600" step="1" value="150">
          </div>
          <div>
            <label for="jpegQuality">Qualidade JPEG (<span id="jpegQualityValue">65</span>%)</label>
            <input type="range" id="jpegQuality" name="jpegQuality" min="10" max="100" value="65">
          </div>
        </div>
        <div class="row" style="margin-top:12px">
          <fieldset>
            <legend>Modo de cor</legend>
            <div class="inline">
              <label class="inline"><input type="radio" name="mode" value="color" checked> Colorido</label> <label class="inline"><input type="radio" name="mode" value="gray"> Tons de cinza</label> <label class="inline"><input type="radio" name="mode" value="bilevel"> Preto e branco</label>
            </div>
            <div class="muted" style="margin-top:6px"><small>“Tons de cinza” ou “Preto e branco” pode reduzir drasticamente o tamanho de documentos escaneados.</small></div>
          </fieldset>
          <fieldset>
            <legend>Otimização web</legend>
            <label class="inline">
              <input type="checkbox" id="linearize" name="linearize" value="true"> Linearizar após compressão (QPDF)
            </label>
            <div class="muted" id="linNote" style="margin-top:6px"></div>
          </fieldset>
        </div>
      </div>
      
      <div style="margin-top:12px">
        <label>Intervalo de páginas (opcional)</label>
        <div class="row" >
          <input type="number" id="firstPage" name="firstPage" placeholder="Primeira página">
          <input type="number" id="lastPage" name="lastPage" placeholder="Última página">
        </div>
      </div>
    </fieldset>

    <div style="margin-top:16px; display:flex; gap:12px; align-items:center;">
      <button id="btn" type="submit">Comprimir</button>
      <progress id="pg" class="hidden" max="100" value="0"></progress>
      <span id="msg" class="muted"></span>
    </div>
  </form>
  <div id="out" class="card hidden" style="margin-top:16px;">
    <div class="ok" id="ok"></div>
    <div style="margin:8px 0;">
      <a id="dl" download="compressed.pdf">Baixar arquivo comprimido</a>
    </div>
    <div class="stats" id="stats"></div>
  </div>
  <div id="err" class="card err hidden" style="margin-top:16px;"></div>

<script>
  const $ = (id) => document.getElementById(id);
  const fmtBytes = n => { if (!n) return '0 B'; const i = Math.floor(Math.log(n) / Math.log(1024)); const u = ['B','KB','MB','GB','TB']; return `${(n / Math.pow(1024, i)).toFixed(2)} ${u[i]}`; };
  const fmtTime = s => { s = Math.max(0, Math.round(s)); const m = Math.floor(s/60), r = s%60; return m > 0 ? `${m}m ${r}s` : `${r}s`; };
  
  let es = null;
  const jobProgress = {};

  // --- Lógica da UI Dinâmica ---
  const engineSelect = $('engine');
  const gsOptions = $('gs-options');
  const linearizeNote = $('linNote');
  const linearizeCheckbox = $('linearize');

  function toggleEngineOptions() {
    const isQpdf = engineSelect.value === 'qpdf';
    gsOptions.classList.toggle('hidden', isQpdf);
    linearizeCheckbox.checked = !isQpdf;
    linearizeCheckbox.disabled = isQpdf;
    if (isQpdf) {
      linNote.innerHTML = '<small>A opção QPDF já gera um PDF otimizado (linearizado) por padrão.</small>';
    } else {
      linNote.innerHTML = '<small>Otimiza o PDF para visualização rápida na web.</small>';
    }
  }
  engineSelect.addEventListener('change', toggleEngineOptions);
  toggleEngineOptions();

  // --- Feedback de Seleção de Arquivo ---
  $('file').addEventListener('change', (ev) => {
    const fileInfo = $('file-info');
    if (ev.target.files.length > 0) {
      const file = ev.target.files[0];
      fileInfo.innerHTML = `Arquivo: <b>${file.name}</b> (${fmtBytes(file.size)})`;
    } else {
      fileInfo.innerHTML = '';
    }
  });

  // --- Feedback do Slider de Qualidade JPEG ---
  const jpegQualitySlider = $('jpegQuality');
  const jpegQualityValue = $('jpegQualityValue');
  jpegQualitySlider.addEventListener('input', () => {
    jpegQualityValue.textContent = jpegQualitySlider.value;
  });

  // --- Lógica de Submissão do Formulário ---
  $('f').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const btn = $('btn');
    const formFields = $('form-fields');

    // Resetar UI
    $('err').classList.add('hidden'); $('err').textContent = '';
    $('out').classList.add('hidden');
    $('pg').classList.remove('hidden');
    $('pg').removeAttribute('value');
    $('msg').textContent = 'Enviando…';

    // ########## INÍCIO DA CORREÇÃO ##########
    // 1. CRIE o FormData com os dados do formulário ANTES de desabilitar os campos.
    const fd = new FormData(ev.currentTarget);
    const jobId = (crypto && crypto.randomUUID) ? crypto.randomUUID() : String(Date.now());
    
    // 2. AGORA sim, desabilite os campos para o usuário não interagir.
    btn.disabled = true;
    btn.textContent = 'Enviando...';
    formFields.disabled = true;
    // ########## FIM DA CORREÇÃO ##########

    try {
      es = new EventSource(`/progress/${jobId}`);
      jobProgress[jobId] = { total: 0 };
      
      es.onmessage = (e) => {
        try {
          const data = JSON.parse(e.data);
          if (data.stage === 'upload-done') $('msg').textContent = 'Upload concluído. Preparando…';
          if (data.stage === 'queued') {
            jobProgress[jobId].total = Number(data.totalPages || 0);
            $('pg').max = 100; $('pg').value = 0;
            $('msg').textContent = `Na fila... 0/${jobProgress[jobId].total}`;
          }
          if (data.stage === 'repaired') $('msg').textContent = 'PDF reparado pelo engine.';
          if (data.stage === 'linearizing') $('msg').textContent = 'Otimizando para web (QPDF)...';
          if (data.stage === 'merging') $('msg').textContent = 'Mesclando partes (QPDF)…';

          if (data.stage === 'start') {
              jobProgress[jobId][data.isolateId] = { pagesDone: 0, totalInJob: data.totalPagesInJob, firstPage: data.firstPage };
          }
          if (data.stage === 'page' && data.page) {
            const isolateId = data.isolateId;
            const progress = jobProgress[jobId];
            if (!progress[isolateId]) return;
            progress[isolateId].pagesDone = data.page - progress[isolateId].firstPage + 1;
            
            let totalPagesDone = 0;
            for (const key in progress) {
              if (typeof progress[key] === 'object' && progress[key] !== null && 'pagesDone' in progress[key]) {
                  totalPagesDone += progress[key].pagesDone;
              }
            }
            if (progress.total > 0) {
              const perc = Math.min(100, Math.round(totalPagesDone * 100 / progress.total));
              $('pg').value = perc;
              $('msg').textContent = `Processando... ${totalPagesDone}/${progress.total} (${perc}%)`;
            } else {
              $('msg').textContent = `Processando página ${data.page}…`;
            }
          }
          if (data.stage === 'done') { $('pg').value = 100; $('msg').textContent = 'Concluído.'; }
          if (data.stage === 'error') $('msg').textContent = 'Falha no processamento.';
        } catch(_) {}
      };

      es.onerror = () => {
        $('msg').textContent = '';
        $('err').textContent = 'Conexão com o servidor perdida. Verifique sua rede e tente novamente.';
        $('err').classList.remove('hidden');
        $('pg').classList.add('hidden');
        if(es) es.close(); es = null;
      };
      
      const resp = await fetch(`/compress?jobId=${encodeURIComponent(jobId)}`, { method: 'POST', body: fd });
      $('pg').classList.add('hidden');
      if (es) { es.close(); es = null; }
      
      if (!resp.ok) {
        const txt = await resp.text();
        $('err').textContent = txt || ('Erro HTTP ' + resp.status);
        $('err').classList.remove('hidden');
        $('msg').textContent = '';
        return;
      }
      
      const cd = resp.headers.get('content-disposition') || '';
      const m = cd.match(/filename\\s*=\\s*"?([^"]+)"?/i);
      const filename = m ? m[1] : 'compressed.pdf';
      const blob = await resp.blob();
      const url = URL.createObjectURL(blob);
      
      const a = $('dl'); a.href = url; a.download = filename;
      const orig = Number(resp.headers.get('x-original-size') || 0);
      const comp = Number(resp.headers.get('x-compressed-size') || blob.size);
      const ratio = (orig > 0) ? (comp / orig) : 0;
      
      $('ok').textContent = 'Pronto! Arquivo comprimido gerado.';
      let statsHTML = `Original: <b>${fmtBytes(orig)}</b> — Comprimido: <b>${fmtBytes(comp)}</b> — Redução: <b>${(100 - (ratio*100)).toFixed(1)}%</b>`;

      // Busca o tempo total que foi enviado no evento 'stats'
      const finalStatsEvent = await new Promise(resolve => {
        const tempEs = new EventSource(`/progress/${jobId}`);
        tempEs.onmessage = e => {
            const data = JSON.parse(e.data);
            if (data.stage === 'stats') {
                resolve(data);
                tempEs.close();
            }
        };
        // Adiciona um timeout para não ficar esperando para sempre
        setTimeout(() => { tempEs.close(); resolve(null); }, 5000);
      });

      if (finalStatsEvent && typeof finalStatsEvent.elapsed === 'number') {
        statsHTML += ` — Tempo: <b>${fmtTime(finalStatsEvent.elapsed)}</b>`;
      }

      $('stats').innerHTML = statsHTML;
      $('out').classList.remove('hidden');
      $('msg').textContent = '';

    } catch (e) {
      $('pg').classList.add('hidden');
      if (es) { es.close(); es = null; }
      $('err').textContent = String(e);
      $('err').classList.remove('hidden');
      $('msg').textContent = '';
    } finally {
      btn.disabled = false;
      btn.textContent = 'Comprimir';
      formFields.disabled = false;
      if (es) { es.close(); es = null; }
    }
  });
</script>
</body>
</html>
''';
  return Response.ok(html,
      headers: {HttpHeaders.contentTypeHeader: 'text/html; charset=utf-8'});
}
