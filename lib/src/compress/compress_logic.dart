// C:\MyDartProjects\pdf_tools\lib\src\compress\compress_logic.dart
// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

// Importe os bindings das suas ferramentas de linha de comando
import 'package:pdf_tools/src/ghostscript.dart' as gs_api;
import 'package:pdf_tools/src/mupdf.dart' as mupdf_api;
import 'package:pdf_tools/src/qpdf.dart' as qpdf_api;

const MIN_PAGES_FOR_SPLIT = 4;
const MAX_ISOLATES_PER_PDF = 8;
final _uuid = const Uuid();

// --- LÓGICA DO ISOLATE (QUASE IDÊNTICA À VERSÃO WEB) ---

// Define um tipo para o callback de progresso
typedef ProgressCallback = void Function(String message, int? percentage);

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

Future<Map<String, Object?>> _compressIsolate(Map<String, Object?> job) async {
  final send = job['send'] as SendPort?;
  final input = job['input'] as String;
  final output = job['output'] as String;
  final firstPage = job['firstPage'] as int;
  final lastPage = job['lastPage'] as int;
  final dpi = job['dpi'] as int;
  final quality = job['quality'] as String;
  final isolateId = job['isolateId'] as String;

  void emit(Map<String, Object?> m) => send?.send(m);

  try {
    emit({
      'stage': 'start',
      'isolateId': isolateId,
      'firstPage': firstPage,
    });

    final args = _gsArgs(
        input: input,
        output: output,
        dpi: dpi,
        quality: quality,
        first: firstPage,
        last: lastPage);
    print('[$isolateId] Ghostscript Args: ${args.join(' ')}');

    final gs = gs_api.Ghostscript.open();
    int currentPageInJob = 0;
    final rc = gs.runWithProgress(args, (String line) {
      print('[$isolateId] GS > $line');
      final match = RegExp(r'^\s*Page\s+(\d+)\s*$').firstMatch(line);
      if (match != null) {
        final pageNum = int.parse(match.group(1)!);
        currentPageInJob = pageNum - firstPage + 1;
        emit({
          'stage': 'page',
          'pagesDoneInIsolate': currentPageInJob,
          'isolateId': isolateId
        });
      }
    });

    if (rc < 0) throw gs_api.GhostscriptException(rc);

    return {'rc': rc, 'finalPath': output};
  } catch (e, st) {
    print('[$isolateId] ERRO NO ISOLATE: $e\n$st');
    emit({'stage': 'error', 'error': e.toString()});
    return {'rc': -1, 'error': e.toString()};
  }
}

Future<int> getPageCount(String path) async {
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

Future<void> _getPageCountIsolate(Map<String, Object> msg) async {
  final sendPort = msg['sendPort'] as SendPort;
  final path = msg['path'] as String;
  try {
    final count = await getPageCount(path);
    sendPort.send(count);
  } catch (e) {
    sendPort.send(e);
  }
}

Future<int> getPageCountAsync(String path) async {
  final receivePort = ReceivePort();
  await Isolate.spawn(
    _getPageCountIsolate,
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

// --- FUNÇÃO PRINCIPAL DE COMPRESSÃO ---

/// Comprime um arquivo PDF usando a lógica de múltiplos isolates.
/// Retorna o caminho do arquivo de saída.
Future<String> compressPdfFile({
  required String inputPath,
  required int dpi,
  required String quality,
  required ProgressCallback onProgress,
  int? maxCores,
  String? outputDir,
  bool Function()? isCancelRequested, // opcional (para Cancelar)
}) async {
  final tmpRoot =
      Directory(p.join(Directory.systemTemp.path, 'pdf_compressor_desktop'));
  await tmpRoot.create(recursive: true);

  final List<String> tempFiles = [];
  final List<_SpawnedJob> running = []; // rastrear isolates ativos (p/ cancel)
  ReceivePort? progressPort;
  StreamSubscription? sub;

  // ignore: no_leading_underscores_for_local_identifiers
  void _killAllRunning() {
    for (final j in running) {
      j.iso.kill(priority: Isolate.immediate);
    }
    running.clear();
  }

  try {
    onProgress("Analisando PDF...", null);
    final totalPages = await getPageCountAsync(inputPath);
    if (totalPages <= 0) throw Exception("PDF inválido ou sem páginas.");

    progressPort = ReceivePort();
    final isolateProgress = <String, int>{};
    final started = DateTime.now();

    sub = progressPort.listen((msg) {
      if (msg is Map<String, Object?>) {
        final stage = msg['stage'] as String?;
        if (stage == 'page') {
          final isolateId = msg['isolateId'] as String;
          final pagesDoneInIsolate = msg['pagesDoneInIsolate'] as int;
          isolateProgress[isolateId] = pagesDoneInIsolate;

          final totalPagesDone =
              isolateProgress.values.fold<int>(0, (sum, v) => sum + v);
          final pct = (totalPagesDone * 100 / totalPages).round().clamp(0, 100);

          final elapsed = DateTime.now().difference(started).inSeconds;
          final rate = elapsed > 0 ? (totalPagesDone / elapsed) : 0.0; // pág/s
          final remaining = max(0, totalPages - totalPagesDone);
          final etaSec = rate > 0 ? (remaining / rate).round() : 0;

          onProgress(
              "Processando... $totalPagesDone/$totalPages | ${rate.toStringAsFixed(1)} pág/s | ETA ${etaSec}s",
              pct);
        } else if (stage == 'merge-start') {
          onProgress("Mesclando partes...", null);
        } else if (stage == 'merge-done') {
          onProgress("Mesclagem concluída.", null);
        } else if (stage == 'merge-error') {
          onProgress("Erro na mesclagem: ${msg['error']}", null);
        }
      }
    });

    String finalCompressedPath;

    // --- Caminho 1: arquivo pequeno (sem split)
    if (totalPages < MIN_PAGES_FOR_SPLIT) {
      if (isCancelRequested?.call() == true) {
        _killAllRunning();
        throw Exception('cancelled');
      }

      onProgress("Processando (arquivo pequeno)...", null);
      final outPath = p.join(tmpRoot.path, '${_uuid.v4()}-compressed.pdf');
      tempFiles.add(outPath);

      final job = {
        'input': inputPath,
        'output': outPath,
        'dpi': dpi,
        'quality': quality,
        'firstPage': 1,
        'lastPage': totalPages,
        'send': progressPort.sendPort,
        'isolateId': 'main-iso',
      };

      final spawned = await _spawnCompressIsolate(job);
      running.add(spawned);

      final res = await spawned.result;
      if (isCancelRequested?.call() == true) {
        _killAllRunning();
        throw Exception('cancelled');
      }
      if ((res['rc'] as int) < 0) throw Exception(res['error']);
      finalCompressedPath = res['finalPath'] as String;
    }
    // --- Caminho 2: arquivo grande (split + merge)
    else {
      final cpus = (maxCores ?? Platform.numberOfProcessors)
          .clamp(1, MAX_ISOLATES_PER_PDF);
      final chunks = min(cpus, (totalPages / 2).ceil());
      final pagesPerChunk = (totalPages / chunks).ceil();

      onProgress("Dividindo em $chunks partes...", null);

      final outParts = <String>[];
      for (var i = 0; i < chunks; i++) {
        if (isCancelRequested?.call() == true) {
          _killAllRunning();
          throw Exception('cancelled');
        }

        final start = 1 + i * pagesPerChunk;
        final end = (i == chunks - 1) ? totalPages : start + pagesPerChunk - 1;
        if (start > end) break;

        final partPath = p.join(tmpRoot.path, '${_uuid.v4()}-part${i + 1}.pdf');
        tempFiles.add(partPath);
        outParts.add(partPath);

        final job = {
          'input': inputPath,
          'output': partPath,
          'dpi': dpi,
          'quality': quality,
          'firstPage': start,
          'lastPage': end,
          'send': progressPort.sendPort,
          'isolateId': 'iso${i + 1}',
        };

        final spawned = await _spawnCompressIsolate(job);
        running.add(spawned);
      }

      // aguarda cada chunk (permite checar cancel entre awaits)
      for (final j in List<_SpawnedJob>.from(running)) {
        if (isCancelRequested?.call() == true) {
          _killAllRunning();
          throw Exception('cancelled');
        }
        final r = await j.result;
        if ((r['rc'] as int) < 0) {
          _killAllRunning();
          throw Exception(r['error'] ?? 'Erro em um dos isolates.');
        }
      }

      if (isCancelRequested?.call() == true) {
        _killAllRunning();
        throw Exception('cancelled');
      }

      final mergedPath = p.join(tmpRoot.path, '${_uuid.v4()}-merged.pdf');
      tempFiles.add(mergedPath);

      await _mergeInIsolate(outParts, mergedPath, progressPort.sendPort);
      finalCompressedPath = mergedPath;
    }

    // encerra escuta de progresso
    await sub.cancel();
    progressPort.close();

    onProgress("Finalizando...", 100);

    final originalDir = outputDir ?? p.dirname(inputPath);
    final originalFilename = p.basenameWithoutExtension(inputPath);
    final finalOutputPath =
        p.join(originalDir, '${originalFilename}_comprimido.pdf');

// Mover e limpar em outro isolate com entrypoint top-level
    await _finalizeInIsolate(
      src: finalCompressedPath,
      dst: finalOutputPath,
      temps: tempFiles,
    );

    return finalOutputPath;
  } catch (e) {
    _killAllRunning(); // garante matar em erro/cancelamento
    for (final path in tempFiles) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    rethrow;
  } finally {
    await sub?.cancel();
    progressPort?.close();
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
    // mover resultado
    await File(src).rename(dst);
    // limpar temporários
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
  );
  final future = resultPort.first.then((v) {
    resultPort.close();
    return (v as Map).cast<String, Object?>();
  });
  return _SpawnedJob(iso, future);
}

void _mergeIsolateEntry(Map<String, Object?> m) async {
  final progress = m['send'] as SendPort?;
  final result = m['result'] as SendPort; // <— use este!
  final inputs = (m['inputs'] as List).cast<String>();
  final out = m['out'] as String;

  try {
    progress?.send({'stage': 'merge-start'});
    final qpdf = qpdf_api.Qpdf.open();
    final args = ['--empty', '--pages', ...inputs, '--'];
    final rc = qpdf.run(args, outputPath: out);
    if (rc != 0) throw qpdf_api.QpdfException(rc, "Falha ao mesclar PDFs");
    progress?.send({'stage': 'merge-done'});
    result.send({'rc': rc}); // <— envia sucesso
  } catch (e, st) {
    progress?.send({'stage': 'merge-error', 'error': e.toString()});
    result.send({'rc': -1, 'error': '$e\n$st'}); // <— envia erro
  }
}

Future<void> _mergeInIsolate(
  List<String> inputs,
  String out,
  SendPort progress,
) async {
  final resPort = ReceivePort();
  final iso = await Isolate.spawn(_mergeIsolateEntry, {
    'inputs': inputs,
    'out': out,
    'send': progress,
    'result': resPort.sendPort,
  });

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

List<String> _gsArgs({
  required String input,
  required String output,
  required int dpi,
  required String quality,
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

  return <String>[
    '-dSAFER',
    '-dBATCH',
    '-dNOPAUSE',
    '-sDEVICE=pdfwrite',
    '-o',
    output,
    if (first != null) '-dFirstPage=$first',
    if (last != null) '-dLastPage=$last',
    ...qualityArgs,

    // --- PARÂMETROS ADICIONADOS/MODIFICADOS PARA FORÇAR A COMPRESSÃO ---

    // 1. Assegura que as políticas de imagem sejam aplicadas
    '-dDetectDuplicateImages=true',
    '-dColorImageDownsampleType=/Average',
    '-dGrayImageDownsampleType=/Average',
    '-dMonoImageDownsampleType=/Subsample',
    '-dDownsampleColorImages=true',
    '-dDownsampleGrayImages=true',
    '-dDownsampleMonoImages=true',

    // 2. Define a resolução alvo
    '-dColorImageResolution=$dpi',
    '-dGrayImageResolution=$dpi',
    '-dMonoImageResolution=$dpi',

    // 3. FORÇA a conversão para JPEG (a parte mais importante)
    '-sColorConversionStrategy=sRGB',
    // '-sColorImageDict.jpeg_DCTEncode=true', // Força a compressão JPEG para imagens coloridas
    //  '-sGrayImageDict.jpeg_DCTEncode=true', // Força a compressão JPEG para imagens em tons de cinza
    '-dAutoFilterColorImages=false',
    '-dColorImageFilter=/DCTEncode',
    '-dAutoFilterGrayImages=false',
    '-dGrayImageFilter=/DCTEncode',
    '-dJPEGQ=75', // Qualidade JPEG (0-100, padrão é ~75)
    '-dAntiAliasColorImages=false',
    '-dAntiAliasGrayImages=false',

    // -----------------------------------------------------------------

    input,
  ];
}
