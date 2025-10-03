// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import 'package:pdf_tools/src/gs_stdio_/ghostscript.dart' as gs_api;
import 'package:pdf_tools/src/qpdf.dart' as qpdf_api;
import 'package:pdf_tools/src/mupdf.dart' as mupdf_api;

final _uuid = const Uuid();

const MAX_CONCURRENT_FILES = 6;
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
  final mode = (job['mode'] as String?) ?? 'color';
  final isolateId = job['isolateId'] as String;

  void emit(Map<String, Object?> m) {
    m['ts'] = DateTime.now().millisecondsSinceEpoch;
    send?.send(m);
  }

  try {
    // CORREÇÃO: Adicionado 'firstPage' ao payload para a UI.
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
        first: firstPage,
        last: lastPage,
        mode: mode);
    print('[$isolateId] Ghostscript Args: ${args.join(' ')}');
    emit({'stage': 'gs-args', 'args': args});

    final re = RegExp(r'^\s*Page\s+(\d+)\s*$', caseSensitive: false);
    final gs = gs_api.Ghostscript.open();

    final rc = gs.runWithProgress(args, (String line) {
      print('[$isolateId] GS > $line');
      emit({'stage': 'gs-line', 'line': line.trim()});
      final m = re.firstMatch(line);
      if (m != null) {
        final pNum = int.tryParse(m.group(1)!);
        if (pNum != null) {
          emit({'stage': 'page', 'page': pNum, 'isolateId': isolateId});
        }
      }
    });

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

  // Usando um middleware customizado que não lê o corpo da resposta.
  final handler = Pipeline()
      .addMiddleware(_logRequestsWithoutBody())
      .addMiddleware(_cors())
      .addHandler(router.call);

  final server = await serve(handler, ip, port, shared: true);
  final host = server.address.host;
  print('PDF Compressor API ouvindo em http://$host:${server.port}');
  print(
      'GUI WEB http://${host == '0.0.0.0' ? 'localhost' : host}:${server.port}/ui');
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

Future<Response> _compress(Request req) async {
  final reqStart = DateTime.now();
  final reqId = _uuid.v4().substring(0, 8);
  print('[$reqId] /compress recebido');

  final contentType =
      MediaType.parse(req.headers[HttpHeaders.contentTypeHeader]!);
  final boundary = contentType.parameters['boundary']!;
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
      print(
          '[$reqId] Intervalo de páginas a ser processado: userFirstPage $userFirstPage userLastPage $userLastPage');
      int firstPageToProcess = userFirstPage ?? 1;
      int lastPageToProcess = userLastPage ?? totalPagesInFile;

      if (firstPageToProcess < 1) firstPageToProcess = 1;
      if (lastPageToProcess > totalPagesInFile) {
        lastPageToProcess = totalPagesInFile;
      }
      if (firstPageToProcess > lastPageToProcess) {
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

      progressPort = ReceivePort();
      sub = progressPort.listen((msg) {
        if (msg is Map) prog.emit(msg.cast<String, Object?>());
      });

      String finalCompressedPath;

      if (totalPagesToProcess < 4) {
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
        finalCompressedPath = result['finalPath'] as String;
      } else {
        final midPoint = firstPageToProcess + (totalPagesToProcess ~/ 2) - 1;
        print(
            '[$reqId] PDF/Intervalo grande ($totalPagesToProcess páginas), dividindo em 2 isolates ($firstPageToProcess-$midPoint, ${midPoint + 1}-$lastPageToProcess)');

        final outPath1 = p.join(tmpRoot.path, '${_uuid.v4()}-part1.pdf');
        final outPath2 = p.join(tmpRoot.path, '${_uuid.v4()}-part2.pdf');
        tempFiles.addAll([outPath1, outPath2]);

        final job1 = _createJob(
            fields, uploaded.path, outPath1, totalPagesToProcess,
            firstPage: firstPageToProcess,
            lastPage: midPoint,
            sendPort: progressPort.sendPort,
            isolateId: '$reqId-iso1');
        final job2 = _createJob(
            fields, uploaded.path, outPath2, totalPagesToProcess,
            firstPage: midPoint + 1,
            lastPage: lastPageToProcess,
            sendPort: progressPort.sendPort,
            isolateId: '$reqId-iso2');

        final results =
            await Future.wait([_runIsolate(job1), _runIsolate(job2)]);

        final res1 = results[0];
        final res2 = results[1];

        if ((res1['rc'] as int) < 0) {
          throw Exception(res1['error'] ?? "Erro no isolate 1");
        }
        if ((res2['rc'] as int) < 0) {
          throw Exception(res2['error'] ?? "Erro no isolate 2");
        }

        print('[$reqId] Mesclando partes: $outPath1 e $outPath2');
        prog.emit({'stage': 'merging'});
        final mergedPath = p.join(tmpRoot.path, '${_uuid.v4()}-merged.pdf');
        tempFiles.add(mergedPath);
        await _mergePdfs([outPath1, outPath2], mergedPath);
        finalCompressedPath = mergedPath;
        print('[$reqId] Mesclagem concluída para: $mergedPath');
      }

      // ========= INÍCIO DA CORREÇÃO PRINCIPAL =========
      final outFile = File(finalCompressedPath);
      final outSize = await outFile.length();
      final safeName = (originalName ?? 'output.pdf').replaceAll('"', '');

      // Cria um stream transformado que executa a limpeza quando o stream termina.
      final bodyStream = outFile.openRead().transform<List<int>>(
            StreamTransformer.fromHandlers(handleData: (chunk, sink) {
              // Apenas repassa os dados do arquivo.
              sink.add(chunk);
            }, handleDone: (sink) async {
              // Este bloco é executado quando o shelf termina de enviar o arquivo.
              try {
                print('[$reqId] Stream da resposta finalizado.');
                prog.emit({'stage': 'done'});

                print('[$reqId] Limpando arquivos temporários: $tempFiles');
                for (final path in tempFiles) {
                  try {
                    await File(path).delete();
                  } catch (e) {
                    print(
                        '[$reqId] Erro ao deletar arquivo temporário $path: $e');
                  }
                }
              } finally {
                // Garante que o progresso seja fechado e o job removido.
                prog.close();
                _jobs.remove(jobId);
                sink.close(); // Fecha o sink do transformador.
                print('[$reqId] Limpeza concluída.');
              }
            }, handleError: (error, stackTrace, sink) {
              print('[$reqId] Erro durante o stream da resposta: $error');
              sink.addError(error, stackTrace);
            }),
          );

      print(
          '[$reqId] finalizado in=$inSize out=$outSize tempo=${DateTime.now().difference(reqStart).inSeconds}s. Iniciando stream de resposta.');

      // Retorna a resposta com o corpo do stream transformado.
      return Response.ok(
        bodyStream,
        headers: {
          HttpHeaders.contentTypeHeader: 'application/pdf',
          'content-disposition': 'attachment; filename="$safeName"',
          'x-original-size': '$inSize',
          'x-compressed-size': '$outSize',
        },
      );
      // ========= FIM DA CORREÇÃO PRINCIPAL =========
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

  print(
      '_createJob dpi $dpi | quality $quality | mode $mode | firstPage $firstPage | lastPage $lastPage');

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

List<String> _gsArgs(
    {required String input,
    required String output,
    required int dpi,
    required String quality,
    String mode = 'color',
    int? first,
    int? last}) {
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
        '-sProcessColorModel=DeviceGray',
        '-sColorConversionStrategy=Gray',
        '-dOverrideICC=true',
        '-sColorConversionStrategyForImages=Gray',
        '-dConvertImagesTo1bpp=true',
        '-dMonoImageDownsampleType=/Subsample',
        '-dMonoImageResolution=${dpi * 2}',
        '-sCompression=tiffg4'
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
    'Access-Control-Allow-Headers': 'Origin,Content-Type,Accept'
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
    if (!ctrl.isClosed) {
      final s = 'data: ${jsonEncode(data)}\n\n';
      ctrl.add(s);
    }
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
  <title>PDF Compressor</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    :root { font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial; } body { margin: 24px; max-width: 900px; } h1 { margin: 0 0 16px; } form, .card { border: 1px solid #ddd; border-radius: 12px; padding: 16px; } .row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; } .row3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 12px; } label { font-weight: 600; display: block; margin-bottom: 6px;} input[type="number"] { width: 100%; } .muted { color: #666; font-size: .9rem; } button { padding: 10px 16px; border-radius: 10px; border: 1px solid #ccc; cursor: pointer; } progress { width: 100%; height: 16px; } .hidden { display:none; } .ok { color: #0a7c2f; } .err { color: #b00020; white-space: pre-wrap;} .stats { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; } fieldset { border: 1px dashed #ddd; border-radius: 10px; padding: 10px 12px; } fieldset legend { padding: 0 6px; color: #555; font-size: .95rem; } .inline { display:flex; gap:14px; align-items:center; flex-wrap: wrap; }
  </style>
</head>
<body>
  <h1>PDF Compressor</h1>
  <p class="muted">Faça upload de um PDF grande e receba o arquivo comprimido. Você também pode chamar a API direto em <code>POST /compress</code> (multipart/form-data).</p>
  <form id="f" class="card">
    <div class="row"> <div> <label>Arquivo PDF</label> <input required type="file" id="file" name="file" accept="application/pdf"> </div> <div> <label>Engine</label> <select name="engine" id="engine"> <option value="gs" selected>Ghostscript (melhor redução)</option> <option value="qpdf">QPDF (rápido; só lineariza)</option> </select> <div class="muted" style="margin-top:6px"> <small> • <b>Ghostscript</b>: reduz tamanho (downsample/qualidade).<br> • <b>QPDF</b>: não reduz, apenas <i>lineariza</i> (otimiza para web). </small> </div> </div> </div>
    <div class="row3" style="margin-top:12px"> <div> <label>Qualidade</label> <select name="quality" id="quality"> <option value="default" selected>default</option> <option value="screen">screen</option> <option value="ebook">ebook</option> <option value="printer">printer</option> <option value="prepress">prepress</option> </select> </div> <div> <label>DPI</label> <input type="number" id="dpi" name="dpi" min="72" max="600" step="1" value="150"> </div> <div> <label>Intervalo (opcional)</label> <div class="row" style="grid-template-columns: 1fr 1fr;"> <input type="number" id="firstPage" name="firstPage" placeholder="Primeira"> <input type="number" id="lastPage"  name="lastPage"  placeholder="Última"> </div> </div> </div>
    <div class="row" style="margin-top:12px"> <fieldset> <legend>Modo de cor</legend> <div class="inline"> <label class="inline"><input type="radio" name="mode" value="color" checked> Colorido</label> <label class="inline"><input type="radio" name="mode" value="gray"> Tons de cinza</label> <label class="inline"><input type="radio" name="mode" value="bilevel"> Preto e branco (bilevel/CCITT)</label> </div> <div class="muted" style="margin-top:6px"> <small>“Gray” reduz para escala de cinza. “Bilevel” força imagens 1-bit com CCITT Fax (ótimo para documentos escaneados em PB).</small> </div> </fieldset> <fieldset> <legend>Otimização web</legend> <label class="inline"> <input type="checkbox" id="linearize" name="linearize" value="true"> Linearizar após compressão (QPDF / fast-web-view) </label> <div class="muted" id="linNote" style="margin-top:6px"> <small>Disponível quando o engine for Ghostscript. Com QPDF como engine, a saída já é somente linearizada.</small> </div> </fieldset> </div>
    <div style="margin-top:16px; display:flex; gap:12px; align-items:center;"> <button id="btn" type="submit">Comprimir</button> <progress id="pg" class="hidden" max="100" value="0"></progress> <span id="msg" class="muted"></span> </div>
  </form>
  <div id="out" class="card hidden" style="margin-top:16px;"> <div class="ok" id="ok"></div> <div style="margin:8px 0;"> <a id="dl" download="compressed.pdf">Baixar arquivo comprimido</a> </div> <div class="stats" id="stats"></div> </div>
  <div id="err" class="card err hidden" style="margin-top:16px;"></div>
<script>
const $ = (id) => document.getElementById(id);
const fmtBytes = n => { if (!n) return '0 B'; const i = Math.floor(Math.log(n) / Math.log(1024)); const u = ['B','KB','MB','GB','TB']; return `${(n / Math.pow(1024, i)).toFixed(2)} ${u[i]}`; };
const fmtTime = s => { s = Math.max(0, Math.round(s)); const m = Math.floor(s/60), r = s%60; return m > 0 ? `${m}m ${r}s` : `${r}s`; };
let es = null;
const jobProgress = {};
$('f').addEventListener('submit', async (ev) => {
  ev.preventDefault();
  $('err').classList.add('hidden'); $('err').textContent = '';
  $('out').classList.add('hidden');
  $('pg').classList.remove('hidden');
  $('pg').removeAttribute('max'); $('pg').removeAttribute('value');
  $('msg').textContent = 'Enviando…';
  const jobId = (crypto && crypto.randomUUID) ? crypto.randomUUID() : String(Date.now());
  const fd = new FormData(ev.currentTarget);
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
        if (data.stage === 'start') {
            jobProgress[jobId][data.isolateId] = { pagesDone: 0, totalInJob: data.totalPagesInJob, firstPage: data.firstPage };
        }
        if (data.stage === 'gs-line' && data.line) console.log(data.line);
        if (data.stage === 'page' && data.page) {
            const isolateId = data.isolateId;
            const progress = jobProgress[jobId];
            if (!progress[isolateId]) return;

            // Com a correção do backend, 'firstPage' estará sempre definido aqui.
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
        if (data.stage === 'merging') $('msg').textContent = 'Mesclando partes (QPDF)…';
        if (data.stage === 'done') { $('pg').value = 100; $('msg').textContent = 'Concluído.'; }
        if (data.stage === 'error') $('msg').textContent = 'Falha no processamento.';
      } catch(_) {}
    };
  } catch(_) {}
  try {
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
    const m = cd.match(/filename\s*=\s*"?([^"]+)"?/i);
    const filename = m ? m[1] : 'compressed.pdf';
    const blob = await resp.blob();
    const url = URL.createObjectURL(blob);
    const a = $('dl'); a.href = url; a.download = filename;
    const orig  = Number(resp.headers.get('x-original-size')   || 0);
    const comp  = Number(resp.headers.get('x-compressed-size') || blob.size);
    const ratio = (orig > 0) ? (comp / orig) : 0;
    $('ok').textContent = 'Pronto! Arquivo comprimido gerado.';
    $('stats').innerHTML = `Original: <b>${fmtBytes(orig)}</b> — Comprimido: <b>${fmtBytes(comp)}</b> — Razão: <b>${(ratio*100).toFixed(2)}%</b>`;
    $('out').classList.remove('hidden');
    $('msg').textContent = '';
  } catch (e) {
    $('pg').classList.add('hidden');
    if (es) { es.close(); es = null; }
    $('err').textContent = String(e);
    $('err').classList.remove('hidden');
    $('msg').textContent = '';
  }
});
</script>
</body>
</html>
''';
  return Response.ok(html,
      headers: {HttpHeaders.contentTypeHeader: 'text/html; charset=utf-8'});
}
