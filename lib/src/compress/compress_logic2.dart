// C:\MyDartProjects\pdf_tools\lib\src\compress\compress_logic2.dart
// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

// Ferramentas nativas
import 'package:pdf_tools/src/gsx_bridge/gsx_bridge.dart' as gsx_api;
import 'package:pdf_tools/src/gsx_bridge/gsx_bridge_bindings.dart'
    as gsx_bindings;
import 'package:pdf_tools/src/mupdf/mupdf.dart' as mupdf_api;
import 'package:pdf_tools/src/qpdf/qpdf.dart' as qpdf_api;

const MIN_PAGES_FOR_SPLIT = 4;
final _uuid = const Uuid();

typedef ProgressCallback = void Function(String message, int? percentage);
typedef LogCallback = void Function(String line);

class _SpawnedJob {
  final Isolate iso;
  final Future<Map<String, Object?>> result;
  _SpawnedJob(this.iso, this.result);
}

Future<void> _compressIsolateEntry(Map<String, Object?> msg) async {
  final SendPort result = msg['result'] as SendPort;
  final job = (msg['job'] as Map).cast<String, Object?>();
  try {
    final res = await _compressIsolate(job);
    result.send(res);
  } catch (e, st) {
    result.send({'rc': -1, 'error': '$e', 'stack': '$st'});
  }
}

String _presetForQuality(String q) {
  switch (q) {
    case 'screen':
    case 'ebook':
    case 'printer':
    case 'prepress':
    case 'default':
      return q;
    default:
      return 'default';
  }
}

int _colorModeToInt(String mode) {
  switch (mode) {
    case 'gray':
      return gsx_bindings.GsxColorMode.gray;
    case 'bilevel':
      return gsx_bindings.GsxColorMode.bilevel;
    default:
      return gsx_bindings.GsxColorMode.color;
  }
}

Future<Map<String, Object?>> _compressIsolate(Map<String, Object?> job) async {
  final send = job['send'] as SendPort?;
  final isolateId = job['isolateId'] as String;

  void emit(Map<String, Object?> m) => send?.send(m);

  final jobCompleter = Completer<int>();
  gsx_api.GsxCancelToken? cancelToken;

  try {
    final input = job['input'] as String;
    final output = job['output'] as String;
    final firstPage = job['firstPage'] as int;
    final lastPage = job['lastPage'] as int;
    final dpi = job['dpi'] as int;
    final quality = job['quality'] as String;
    final jpegQuality = job['jpegQuality'] as int;
    final colorMode = job['colorMode'] as String;

    emit({'stage': 'start', 'isolateId': isolateId, 'firstPage': firstPage});

    final bridge = gsx_api.GsxBridge.open();
    cancelToken = gsx_api.GsxCancelToken();
    job['cancelToken'] = cancelToken;

    int pagesDoneInIsolate = 0;
    final preset = _presetForQuality(quality);

    final jobHandle = bridge.compressFileNativeAsync(
      inputPath: input,
      outputPath: output,
      dpi: dpi,
      jpegQuality: jpegQuality,
      preset: preset,
      colorMode: _colorModeToInt(colorMode),
      firstPage: firstPage,
      lastPage: lastPage,
      cancel: cancelToken,
      onProgress: (pageDone, total, line) {
        // 1) Repassa a linha bruta do Ghostscript (stdout/stderr normalizados)
        if (line.isNotEmpty) {
          emit({
            'stage': 'log',
            'isolateId': isolateId,
            'line': line,
          });
        }

        // 2) Atualiza progresso por página (mantém comportamento anterior)
        final done = max(0, pageDone - (firstPage - 1));
        if (done > pagesDoneInIsolate) {
          pagesDoneInIsolate = done;
          emit({
            'stage': 'page',
            'pagesDoneInIsolate': pagesDoneInIsolate,
            'isolateId': isolateId,
            'totalPages': total,
          });
        }
      },
    );

    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (jobCompleter.isCompleted) {
        timer.cancel();
        return;
      }
      final status = jobHandle.status();
      if (status != 0) {
        timer.cancel();
        final rc = jobHandle.join();
        jobCompleter.complete(rc);
      }
    });

    final int rc = await jobCompleter.future;
    bridge.dispose();

    if (rc < 0) {
      throw Exception('GsxBridge falhou com o código de retorno: $rc');
    }

    return {'rc': rc, 'finalPath': output};
  } catch (e, st) {
    // também aparece no console do Dart, mas as linhas do GS vão via 'log'
    print('[$isolateId] ERRO NO ISOLATE: $e\n$st');
    emit({'stage': 'error', 'error': e.toString()});
    return {'rc': -1, 'error': e.toString()};
  } finally {
    cancelToken?.dispose();
  }
}

Future<int> getPageCountAsync(String path) async {
  final receivePort = ReceivePort();
  await Isolate.spawn(
    (Map<String, Object> msg) async {
      final sendPort = msg['sendPort'] as SendPort;
      final path = msg['path'] as String;
      mupdf_api.MuPDFContext? context;
      mupdf_api.MuPDFDocument? document;
      try {
        context = mupdf_api.MuPDFContext.initialize();
        document = context.openDocument(path);
        sendPort.send(document.pageCount);
      } catch (e) {
        sendPort.send(e);
      } finally {
        document?.dispose();
        context?.dispose();
      }
    },
    {'path': path, 'sendPort': receivePort.sendPort},
    errorsAreFatal: true,
  );
  final result = await receivePort.first;
  if (result is int) {
    return result;
  } else {
    throw result;
  }
}

/// FUNÇÃO PRINCIPAL DE COMPRESSÃO
Future<String> compressPdfFile({
  required String inputPath,
  required int dpi,
  required String quality,
  required int jpegQuality,
  required String colorMode,
  required int firstPage,
  required int lastPage,
  required int maxIsolatesPerPdf,
  required ProgressCallback onProgress,
  String? outputDir,
  bool Function()? isCancelRequested,
  LogCallback? onLog, // <-- NOVO: callback para cada linha do Ghostscript
}) async {
  final tmpRoot =
      Directory(p.join(Directory.systemTemp.path, 'pdf_compressor_desktop'));
  await tmpRoot.create(recursive: true);

  final List<String> tempFiles = [];
  final List<_SpawnedJob> running = [];
  ReceivePort? progressPort;
  StreamSubscription? sub;
  final cancelTokens = <String, gsx_api.GsxCancelToken>{};

  void killAllRunning() {
    for (var token in cancelTokens.values) {
      token.cancel();
    }
    for (final j in running) {
      j.iso.kill(priority: Isolate.immediate);
    }
    running.clear();
  }

  try {
    onProgress("Analisando PDF...", null);
    final totalPagesInFile = await getPageCountAsync(inputPath);
    if (totalPagesInFile <= 0) throw Exception("PDF inválido ou sem páginas.");

    final int firstPageToProcess =
        (firstPage > 0 && firstPage <= totalPagesInFile) ? firstPage : 1;
    final int lastPageToProcess =
        (lastPage > 0 && lastPage >= firstPageToProcess)
            ? min(lastPage, totalPagesInFile)
            : totalPagesInFile;
    final totalPagesToProcess = (lastPageToProcess - firstPageToProcess) + 1;

    progressPort = ReceivePort();
    final isolateProgress = <String, int>{};
    final started = DateTime.now();
    final lastSend = <String, int>{};

    sub = progressPort.listen((msg) {
      if (msg is! Map<String, Object?>) return;

      final stage = msg['stage'] as String?;

      // Token (opcional – ignorado aqui)
      if (msg.containsKey('cancelToken')) {
        final isolateId = msg['isolateId'] as String;
        cancelTokens[isolateId] = msg['cancelToken'] as gsx_api.GsxCancelToken;
      }

      if (stage == 'log') {
        final line = (msg['line'] as String?) ?? '';
        if (line.isNotEmpty) onLog?.call(line);
        return;
      }

      if (stage == 'page') {
        final isolateId = msg['isolateId'] as String;
        final pagesDoneInIsolate = msg['pagesDoneInIsolate'] as int;
        isolateProgress[isolateId] = pagesDoneInIsolate;

        final totalPagesDone =
            isolateProgress.values.fold<int>(0, (sum, v) => sum + v);
        final pct =
            (totalPagesDone * 100 / totalPagesToProcess).round().clamp(0, 100);

        final elapsed = DateTime.now().difference(started).inSeconds;
        final rate = elapsed > 0 ? (totalPagesDone / elapsed) : 0.0;
        final remaining = max(0, totalPagesToProcess - totalPagesDone);
        final etaSec = rate > 0 ? (remaining / rate).round() : 0;

        final now = DateTime.now().millisecondsSinceEpoch;
        final id = msg['isolateId'] as String;
        final last = lastSend[id] ?? 0;
        if (now - last >= 100) {
          lastSend[id] = now;
          onProgress(
              "Processando... $totalPagesDone/$totalPagesToProcess | ${rate.toStringAsFixed(1)} pág/s | ETA ${etaSec}s",
              pct);
        }
        return;
      }

      if (stage == 'merge-start') {
        onProgress("Mesclando partes...", null);
        return;
      }
      if (stage == 'merge-done') {
        onProgress("Mesclagem concluída.", null);
        return;
      }
      if (stage == 'merge-error') {
        onProgress("Erro na mesclagem: ${msg['error']}", null);
        return;
      }
    });

    String finalCompressedPath;

    final jobData = {
      'dpi': dpi,
      'quality': quality,
      'jpegQuality': jpegQuality,
      'colorMode': colorMode,
      'send': progressPort.sendPort,
    };

    if (totalPagesToProcess < MIN_PAGES_FOR_SPLIT) {
      onProgress("Processando (arquivo pequeno)...", null);
      final outPath = p.join(tmpRoot.path, '${_uuid.v4()}-compressed.pdf');
      tempFiles.add(outPath);

      final job = {
        ...jobData,
        'input': inputPath,
        'output': outPath,
        'firstPage': firstPageToProcess,
        'lastPage': lastPageToProcess,
        'isolateId': 'main-iso',
      };

      final spawned = await _spawnCompressIsolate(job);
      running.add(spawned);

      final res = await _waitForJobWithCancel(
          spawned, isCancelRequested, killAllRunning);

      if ((res['rc'] as int) < 0) throw Exception(res['error']);
      finalCompressedPath = res['finalPath'] as String;
    } else {
      final chunks =
          maxIsolatesPerPdf.clamp(1, (totalPagesToProcess / 2).ceil());
      final pagesPerChunk = (totalPagesToProcess / chunks).ceil();
      onProgress("Dividindo em $chunks partes...", null);

      final outParts = <String>[];
      for (var i = 0; i < chunks; i++) {
        if (isCancelRequested?.call() == true) throw Exception('cancelled');

        final start = firstPageToProcess + i * pagesPerChunk;
        final end = (i == chunks - 1)
            ? lastPageToProcess
            : min(lastPageToProcess, start + pagesPerChunk - 1);
        if (start > end) break;

        final partPath = p.join(tmpRoot.path, '${_uuid.v4()}-part${i + 1}.pdf');
        tempFiles.add(partPath);
        outParts.add(partPath);

        final job = {
          ...jobData,
          'input': inputPath,
          'output': partPath,
          'firstPage': start,
          'lastPage': end,
          'isolateId': 'iso${i + 1}',
        };
        final spawned = await _spawnCompressIsolate(job);
        running.add(spawned);
      }

      for (final j in List<_SpawnedJob>.from(running)) {
        final r =
            await _waitForJobWithCancel(j, isCancelRequested, killAllRunning);
        if ((r['rc'] as int) < 0) {
          killAllRunning();
          throw Exception(r['error'] ?? 'Erro em um dos isolates.');
        }
      }

      if (isCancelRequested?.call() == true) throw Exception('cancelled');

      final mergedPath = p.join(tmpRoot.path, '${_uuid.v4()}-merged.pdf');
      tempFiles.add(mergedPath);
      await _mergeInIsolate(outParts, mergedPath, progressPort.sendPort);
      finalCompressedPath = mergedPath;
    }

    await sub.cancel();
    progressPort.close();
    onProgress("Finalizando...", 100);

    final originalDir = outputDir ?? p.dirname(inputPath);
    final originalFilename = p.basenameWithoutExtension(inputPath);
    final finalOutputPath =
        p.join(originalDir, '${originalFilename}_comprimido.pdf');
    await _finalizeInIsolate(
      src: finalCompressedPath,
      dst: finalOutputPath,
      temps: tempFiles,
    );

    return finalOutputPath;
  } catch (e) {
    killAllRunning();
    if (!e.toString().contains('cancelled')) rethrow;
    return '';
  } finally {
    await sub?.cancel();
    progressPort?.close();
  }
}

Future<Map<String, Object?>> _waitForJobWithCancel(
  _SpawnedJob job,
  bool Function()? isCancelRequested,
  void Function() killAll,
) async {
  while (true) {
    if (isCancelRequested?.call() == true) {
      killAll();
      throw Exception('cancelled');
    }
    try {
      final result =
          await job.result.timeout(const Duration(milliseconds: 600));
      return result;
    } on TimeoutException {
      continue;
    }
  }
}

Future<void> _finalizeInIsolate({
  required String src,
  required String dst,
  required List<String> temps,
}) async {
  final resPort = ReceivePort();
  await Isolate.spawn(_finalizeEntry, {
    'src': src,
    'dst': dst,
    'temps': temps,
    'result': resPort.sendPort,
  });
  final res = (await resPort.first as Map).cast<String, Object?>();
  resPort.close();
  if ((res['rc'] as int) != 0) {
    throw Exception(res['error'] ?? 'Falha ao finalizar saída');
  }
}

Future<void> _finalizeEntry(Map<String, Object?> m) async {
  final send = m['result'] as SendPort;
  final src = m['src'] as String;
  final dst = m['dst'] as String;
  final temps = (m['temps'] as List).cast<String>();
  try {
    await File(src).rename(dst);
    for (final t in temps) {
      try {
        await File(t).delete();
      } catch (_) {}
    }
    send.send({'rc': 0});
  } catch (e, st) {
    send.send({'rc': -1, 'error': '$e\n$st'});
  }
}

Future<_SpawnedJob> _spawnCompressIsolate(Map<String, Object?> job) async {
  final resultPort = ReceivePort();
  final iso = await Isolate.spawn(
    _compressIsolateEntry,
    {'result': resultPort.sendPort, 'job': job},
    errorsAreFatal: true,
  );
  final future = resultPort.first.then((v) {
    resultPort.close();
    return (v as Map).cast<String, Object?>();
  });
  return _SpawnedJob(iso, future);
}

void _mergeIsolateEntry(Map<String, Object?> m) async {
  final progress = m['send'] as SendPort?;
  final result = m['result'] as SendPort;
  final inputs = (m['inputs'] as List).cast<String>();
  final out = m['out'] as String;

  try {
    progress?.send({'stage': 'merge-start'});
    final qpdf = qpdf_api.Qpdf.open();
    final args = ['--empty', '--pages', ...inputs, '--'];
    final rc = qpdf.run(args, outputPath: out);
    if (rc != 0) throw qpdf_api.QpdfException(rc, "Falha ao mesclar PDFs");
    progress?.send({'stage': 'merge-done'});
    result.send({'rc': rc});
  } catch (e, st) {
    progress?.send({'stage': 'merge-error', 'error': e.toString()});
    result.send({'rc': -1, 'error': '$e\n$st'});
  }
}

Future<void> _mergeInIsolate(
  List<String> inputs,
  String out,
  SendPort progress,
) async {
  final resPort = ReceivePort();
  final iso = await Isolate.spawn(
    _mergeIsolateEntry,
    {
      'inputs': inputs,
      'out': out,
      'send': progress,
      'result': resPort.sendPort,
    },
    errorsAreFatal: true,
  );

  try {
    final result = (await resPort.first as Map).cast<String, Object?>();
    if ((result['rc'] as int) != 0) {
      throw Exception(result['error'] ?? 'Falha ao mesclar PDFs');
    }
  } finally {
    resPort.close();
    iso.kill(priority: Isolate.immediate);
  }
}
