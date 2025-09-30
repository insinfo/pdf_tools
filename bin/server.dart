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

import 'package:pdf_tools/src/ghostscript.dart' as gs_api;
import 'package:pdf_tools/src/qpdf.dart' as qpdf_api;

final _uuid = const Uuid();

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

final _pool = _AsyncSemaphore((Platform.numberOfProcessors ~/ 2).clamp(1, 8));
int get _poolInUse => _pool.inUse;
int get _poolMax => _pool.max;

typedef _Job = Map<String, Object?>;
typedef _JobRes = Map<String, Object?>;

Future<_JobRes> _compressIsolate(_Job job) async {
  final send = job['send'] as SendPort?;
  final engine = job['engine'] as String;
  final input = job['input'] as String;
  String output = job['output'] as String;
  final total = job['totalPages'] as int;
  final firstPage = job['firstPage'] as int?;
  final lastPage = job['lastPage'] as int?;
  final dpi = job['dpi'] as int;
  final quality = job['quality'] as String;
  final mode = (job['mode'] as String?) ?? 'color';
  final linearize = (job['linearize'] as bool?) ?? false;

  void _emit(Map<String, Object?> m) {
    m['ts'] = DateTime.now().millisecondsSinceEpoch;
    send?.send(m);
  }

  try {
    _emit({'stage': 'start', if (total > 0) 'total': total});

    final inSize = await File(input).length();
    int rc = 0;

    if (engine == 'qpdf') {
      _emit({'stage': 'qpdf-start'});
      final q = qpdf_api.Qpdf.open('qpdf30.dll');
      rc = q.linearize(input, output, enable: true);
      _emit({'stage': rc == 0 ? 'done' : 'error', 'code': rc});
      if (rc < 0) throw qpdf_api.QpdfException(rc);
    } else {
      final args = _gsArgs(
          input: input,
          output: output,
          dpi: dpi,
          quality: quality,
          first: firstPage,
          last: lastPage,
          mode: mode);
      _emit({'stage': 'gs-args', 'args': args});

      final re = RegExp(r'^\s*Page\s+(\d+)\s*$', caseSensitive: false);
      final gs = gs_api.Ghostscript.open();
      int lastTs = DateTime.now().millisecondsSinceEpoch;
      int lastPageNum = 0;
      int lastDump = lastTs;

      rc = gs.runWithProgress(args, (String line) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastDump > 150) {
          _emit({'stage': 'gs-line', 'line': line.trim()});
          lastDump = now;
        }
        final m = re.firstMatch(line);
        if (m != null) {
          final pNum = int.tryParse(m.group(1)!);
          if (pNum != null) {
            final dt = (now - lastTs).clamp(1, 1 << 30);
            final dp = (pNum - lastPageNum).clamp(0, 999);
            lastTs = now;
            lastPageNum = pNum;
            final rate = dp * 1000 / dt;
            _emit({'stage': 'page', 'page': pNum, 'rate': rate});
          }
        }
      });
      if (rc < 0) throw gs_api.GhostscriptException(rc);
    }

    if (linearize) {
      _emit({'stage': 'linearize-start'});
      final tmpLin = p.join(p.dirname(output), '${_uuid.v4()}-linearized.pdf');
      final q = qpdf_api.Qpdf.open('qpdf30.dll');
      final rc2 = q.linearize(output, tmpLin, enable: true);
      if (rc2 < 0) throw qpdf_api.QpdfException(rc2);
      try {
        await File(output).delete();
      } catch (_) {}
      output = tmpLin;
      _emit({'stage': 'linearize-done'});
    }

    _emit({'stage': 'done'});
    final outSize = await File(output).length();
    return {
      'rc': rc,
      'inSize': inSize,
      'outSize': outSize,
      'finalPath': output
    };
  } catch (e) {
    _emit({'stage': 'error', 'error': e.toString()});
    return {'rc': -1, 'inSize': 0, 'outSize': 0, 'error': e.toString()};
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
    ..get('/help', _help)
    ..get('/progress/<id>', (req, String id) => _progressSse(req, id))
    ..get('/status', (req) {
      final s = jsonEncode({
        'cpus': Platform.numberOfProcessors,
        'pool': {'inUse': _poolInUse, 'max': _poolMax},
        'jobs': _jobs.length,
      });
      return Response.ok(s, headers: {'content-type': 'application/json'});
    });
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_cors())
      .addHandler(router.call);
  final server = await serve(handler, ip, port, shared: true);
  print(
      'PDF Compressor API ouvindo em http://${server.address.host}:${server.port}');
  print('GUI: http://localhost:8080/ui');
  print('Status: http://localhost:8080/status');
}

Response _health(Request _) => Response.ok(jsonEncode({'status': 'ok'}),
    headers: {'content-type': 'application/json'});

Response _help(Request _) => Response.ok('''
POST /compress  (multipart/form-data)
  campos:
    - file:         arquivo PDF (obrigatório)
    - engine:       "gs" (Ghostscript) | "qpdf" (padrão: gs)
    - firstPage:    inteiro opcional
    - lastPage:     inteiro opcional
    - quality:      "screen" | "ebook" | "printer" | "prepress" | "default"
    - dpi:          inteiro (padrão 150)
resposta:
  application/pdf (stream) com o arquivo comprimido.
''', headers: {'content-type': 'text/plain; charset=utf-8'});

Future<Response> _compress(Request req) async {
  final reqStart = DateTime.now();
  final reqId = _uuid.v4().substring(0, 8);
  print(
      '[${reqId}] /compress recebido. pool inUse=${_poolInUse}/${_poolMax} cpus=${Platform.numberOfProcessors}');

  final urlJobId = req.url.queryParameters['jobId'];
  _Prog? earlyProg =
      urlJobId == null || urlJobId.isEmpty ? null : _ensureJob(urlJobId);

  if (!req.headers.containsKey(HttpHeaders.contentTypeHeader)) {
    return Response(400, body: 'Content-Type ausente');
  }
  final contentType =
      MediaType.parse(req.headers[HttpHeaders.contentTypeHeader]!);
  if (contentType.type != 'multipart' || contentType.subtype != 'form-data') {
    return Response(400, body: 'Content-Type deve ser multipart/form-data');
  }
  final boundary = contentType.parameters['boundary'];
  if (boundary == null) return Response(400, body: 'boundary ausente');

  final tmpRoot =
      Directory(p.join(Directory.systemTemp.path, 'pdf-compressor'));
  await tmpRoot.create(recursive: true);
  print('[${reqId}] pasta tmp: ${tmpRoot.path}');

  File? uploaded;
  String? originalName;
  final fields = <String, String>{};
  String? jobId = urlJobId;
  Timer? hb;
  if (earlyProg != null) {
    hb = Timer.periodic(const Duration(seconds: 1), (_) {
      earlyProg!.emit({'stage': 'hb'});
    });
  }

  try {
    final partsStream =
        MimeMultipartTransformer(boundary).bind(req.read().cast<List<int>>());
    await for (final part in partsStream) {
      final cd = part.headers['content-disposition'];
      if (cd == null) continue;
      final disp = HeaderValue.parse(cd, preserveBackslash: true);
      final name = disp.parameters['name'];
      final filename = disp.parameters['filename'];
      if (name == 'jobId' && (jobId == null || jobId.isEmpty)) {
        final bytes =
            await part.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
        jobId = utf8.decode(bytes);
        if (jobId.isNotEmpty && earlyProg == null) {
          earlyProg = _ensureJob(jobId);
          hb ??= Timer.periodic(const Duration(seconds: 1), (_) {
            earlyProg!.emit({'stage': 'hb'});
          });
        }
        continue;
      }
      if (filename != null && name == 'file') {
        originalName = filename;
        final tmpPath = p.join(tmpRoot.path, '${_uuid.v4()}-upload.pdf');
        uploaded = File(tmpPath);
        final sink = uploaded.openWrite();
        int received = 0;
        final prog = earlyProg;
        final t0 = Stopwatch()..start();
        if (prog != null) prog.emit({'stage': 'upload-start'});
        await for (final chunk in part) {
          received += chunk.length;
          sink.add(chunk);
          if (t0.elapsedMilliseconds > 200) {
            prog?.emit({'stage': 'upload', 'bytes': received});
            t0.reset();
          }
        }
        await sink.close();
        t0.stop();
        print('[${reqId}] upload concluído: ${received} bytes');
        prog?.emit({'stage': 'upload-done', 'bytes': received});
      } else if (name != null) {
        final bytes =
            await part.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
        fields[name] = utf8.decode(bytes);
      }
    }
  } finally {
    hb?.cancel();
  }
  if (uploaded == null) {
    return Response(400, body: 'campo "file" não encontrado');
  }

  int totalPages = 0;
  try {
    print('[${reqId}] Obtendo número de páginas de ${uploaded.path}');
    final q = qpdf_api.Qpdf.open('qpdf30.dll');
    totalPages = q.getNumPages(uploaded.path);
    print('[${reqId}] Total de páginas detectado: $totalPages');
  } catch (e) {
    print(
        '[${reqId}] Falha ao obter contagem de páginas com QPDF: $e. Continuando sem total.');
  }

  final engine = (fields['engine'] ?? 'gs').toLowerCase();
  final first = int.tryParse(fields['firstPage'] ?? '');
  final last = int.tryParse(fields['lastPage'] ?? '');
  final dpi = int.tryParse(fields['dpi'] ?? '150') ?? 150;
  final quality = (fields['quality'] ?? 'default').toLowerCase();
  final mode = (fields['mode'] ?? 'color').toLowerCase();
  final linear = (fields['linearize'] ?? 'false').toLowerCase() == 'true';
  jobId ??= fields['jobId'];
  print(
      '[${reqId}] opts: engine=$engine quality=$quality dpi=$dpi mode=$mode first=$first last=$last linear=$linear');

  final outPath = p.join(tmpRoot.path, '${_uuid.v4()}-compressed.pdf');
  var outFile = File(outPath);
  final progressPort = ReceivePort();
  StreamSubscription? sub;
  if (jobId != null && jobId.isNotEmpty) {
    final prog = _ensureJob(jobId);
    sub = progressPort.listen((msg) {
      if (msg is Map) prog.emit(msg.cast<String, Object?>());
    });
  } else {
    progressPort.listen((_) {});
  }

  final job = <String, Object?>{
    'engine': engine,
    'input': uploaded.path,
    'output': outFile.path,
    'totalPages': totalPages,
    'firstPage': first,
    'lastPage': last,
    'dpi': dpi,
    'quality': quality,
    'mode': mode,
    'linearize': linear,
    'send': progressPort.sendPort,
  };

  final resultPort = ReceivePort();
  print('[${reqId}] aguardando worker... inUse=${_poolInUse}/${_poolMax}');
  try {
    final Map<String, Object?> res = await _pool.withPermit(() async {
      print('[${reqId}] worker adquirido. inUse=${_poolInUse + 1}/${_poolMax}');
      await Isolate.spawn(
          _compressIsolateEntry, {'result': resultPort.sendPort, 'job': job},
          errorsAreFatal: true);
      final msg = await resultPort.first;
      return (msg as Map).cast<String, Object?>();
    });
    final elapsed = DateTime.now().difference(reqStart);
    print(
        '[${reqId}] finalizado rc=${(res['rc'] as int?)} in=${res['inSize']} out=${res['outSize']} tempo=${elapsed.inSeconds}s');
    final rc = (res['rc'] as int?) ?? -1;
    if (rc < 0) throw Exception(res['error'] ?? 'Falha nativa (rc=$rc)');
    final inSize = (res['inSize'] as int?) ?? 0;
    final finalPath = (res['finalPath'] as String?) ?? outFile.path;
    outFile = File(finalPath);
    final outSize = await outFile.length();
    final stream = outFile.openRead();
    final safeName = (originalName ?? 'output.pdf').replaceAll('"', '');
    return Response.ok(stream, headers: {
      HttpHeaders.contentTypeHeader: 'application/pdf',
      'content-disposition': 'attachment; filename="$safeName"',
      'x-original-size': '$inSize',
      'x-compressed-size': '$outSize',
    });
  } catch (e, st) {
    stderr.writeln('[${reqId}] Erro: $e\n$st');
    if (jobId != null && jobId.isNotEmpty) {
      _ensureJob(jobId).emit({'stage': 'error', 'error': e.toString()});
    }
    return Response.internalServerError(body: 'Falha ao comprimir PDF: $e');
  } finally {
    await sub?.cancel();
    progressPort.close();
    resultPort.close();
    try {
      await uploaded.delete();
    } catch (_) {}
    if (jobId != null && jobId.isNotEmpty) {
      Future.delayed(const Duration(seconds: 2), () {
        _jobs[jobId!]?.close();
        _jobs.remove(jobId);
      });
    }
  }
}

List<String> _gsArgs(
    {required String input,
    required String output,
    required int dpi,
    required String quality,
    String mode = 'color',
    int? first,
    int? last}) {
  final profiles = <String, List<String>>{
    'screen': [
      '-dColorImageResolution=$dpi',
      '-dGrayImageResolution=$dpi',
      '-dMonoImageResolution=${(dpi * 2).clamp(150, 600)}'
    ],
    'ebook': [
      '-dColorImageResolution=${(dpi * 1.5).round()}',
      '-dGrayImageResolution=${(dpi * 1.5).round()}',
      '-dMonoImageResolution=${(dpi * 2).clamp(150, 600)}'
    ],
    'printer': [
      '-dColorImageResolution=${(dpi * 2).round()}',
      '-dGrayImageResolution=${(dpi * 2).round()}',
      '-dMonoImageResolution=${(dpi * 3).clamp(300, 1200)}'
    ],
    'prepress': [
      '-dColorImageResolution=${(dpi * 3).round()}',
      '-dGrayImageResolution=${(dpi * 3).round()}',
      '-dMonoImageResolution=${(dpi * 4).clamp(600, 2400)}'
    ],
    'default': [
      '-dColorImageResolution=$dpi',
      '-dGrayImageResolution=$dpi',
      '-dMonoImageResolution=${(dpi * 2).clamp(150, 600)}'
    ],
  };
  final reso = profiles[quality] ?? profiles['default']!;
  final args = <String>[
    '-dSAFER',
    '-dBATCH',
    '-dNOPAUSE',
    '-dProgress',
    '-sDEVICE=pdfwrite',
    '-o',
    output,
    if (first != null) '-dFirstPage=$first',
    if (last != null) '-dLastPage=$last',
    '-dCompatibilityLevel=1.5',
    '-dDetectDuplicateImages=true',
    '-dCompressFonts=true',
    '-dSubsetFonts=true',
    '-dAutoRotatePages=/None',
  ];
  switch (mode) {
    case 'gray':
      args.addAll([
        '-dProcessColorModel=/DeviceGray',
        '-dColorConversionStrategy=/Gray',
        '-dDownsampleGrayImages=true',
        '-dGrayImageDownsampleType=/Average',
        ...reso.where((e) => e.contains('Gray')),
        '-dDownsampleMonoImages=true',
        '-dMonoImageDownsampleType=/Subsample',
        ...reso.where((e) => e.contains('Mono')),
        '-dEncodeGrayImages=true',
        '-dEncodeMonoImages=true'
      ]);
      break;
    case 'bilevel':
      args.addAll([
        '-dProcessColorModel=/DeviceGray',
        '-dColorConversionStrategy=/Gray',
        '-dDownsampleColorImages=false',
        '-dDownsampleGrayImages=false',
        '-dAutoFilterColorImages=false',
        '-dAutoFilterGrayImages=false',
        '-sColorImageFilter=/CCITTFaxEncode',
        '-sGrayImageFilter=/CCITTFaxEncode',
        '-dEncodeMonoImages=true',
        '-dMonoImageDownsampleType=/Subsample',
        '-dMonoImageResolution=300'
      ]);
      break;
    default:
      args.addAll([
        '-dDownsampleColorImages=true',
        '-dColorImageDownsampleType=/Average',
        ...reso.where((e) => e.contains('Color')),
        '-dDownsampleGrayImages=true',
        '-dGrayImageDownsampleType=/Average',
        ...reso.where((e) => e.contains('Gray')),
        '-dDownsampleMonoImages=true',
        '-dMonoImageDownsampleType=/Subsample',
        ...reso.where((e) => e.contains('Mono')),
        '-dEncodeColorImages=true',
        '-dEncodeGrayImages=true',
        '-dEncodeMonoImages=true'
      ]);
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
    let total = 0, lastPage = 0, uploadBytes = 0;
    es.onmessage = (e) => {
      try {
        const data = JSON.parse(e.data);
        if (data.stage === 'upload-start') $('msg').textContent = 'Enviando…';
        if (data.stage === 'upload' && typeof data.bytes === 'number') {
          uploadBytes = data.bytes;
          $('msg').textContent = `Enviando… ${fmtBytes(uploadBytes)}`;
        }
        if (data.stage === 'upload-done') $('msg').textContent = 'Upload concluído. Preparando…';
        if (data.stage === 'start') {
          total = Number(data.total || 0);
          $('pg').classList.remove('hidden');
          if (total > 0) { $('pg').max = 100; $('pg').value = 0; }
          else { $('pg').removeAttribute('max'); $('pg').removeAttribute('value'); }
          $('msg').textContent = total > 0 ? `Iniciando… 0/${total}` : 'Processando…';
        }
        if (data.stage === 'gs-args' && data.args) console.debug('GS args:', data.args);
        if (data.stage === 'gs-line' && data.line) console.debug('[gs]', data.line);
        if (data.stage === 'page' && data.page) {
          lastPage = Number(data.page);
          if (total > 0) {
            const perc = Math.min(100, Math.round(lastPage * 100 / total));
            $('pg').max = 100; $('pg').value = perc;
            let eta = '';
            if (typeof data.rate === 'number' && data.rate > 0) {
              const remaining = Math.max(0, total - lastPage);
              eta = ` — ETA ${fmtTime(remaining / data.rate)}`;
            }
            $('msg').textContent = `Processando página ${lastPage}/${total} (${perc}%)${eta}`;
          } else {
            $('msg').textContent = `Processando página ${lastPage}…`;
          }
        }
        if (data.stage === 'linearize-start') $('msg').textContent = 'Linearizando (QPDF)…';
        if (data.stage === 'linearize-done')  $('msg').textContent = 'Finalizando…';
        if (data.stage === 'done') { $('pg').max = 100; $('pg').value = 100; $('msg').textContent = 'Concluído.'; }
        if (data.stage === 'error') $('msg').textContent = 'Falha no processamento.';
        if (data.stage === 'hb' && !total) $('msg').textContent = 'Processando…';
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