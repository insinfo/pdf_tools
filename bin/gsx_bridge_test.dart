// bin/gsx_bridge_test.dart
// ignore_for_file: curly_braces_in_flow_control_structures, prefer_interpolation_to_compose_strings

import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:pdf_tools/src/gsx_bridge/gsx_bridge.dart';
import 'package:pdf_tools/src/gsx_bridge/gsx_bridge_bindings.dart';

//dart run bin/gsx_bridge_test.dart --async --in "C:\MyDartProjects\pdf_tools\pdfs\input\14_34074_Vol 5.pdf"

void printUsage([String? err]) {
  if (err != null) stderr.writeln('Erro: $err\n');
  stdout.writeln('''
Uso:
  dart run bin/gsx_bridge_test.dart --in <arquivo.pdf> [--out <saida.pdf>] [opções]
  dart run bin/gsx_bridge_test.dart --dir <pasta_entrada> --outdir <pasta_saida> [opções]

Opções:
  --dpi <n>            DPI alvo p/ imagens (padrão 150)
  --q <1-100>          Qualidade JPEG (padrão 65)
  --preset <nome>      default|screen|ebook|printer|prepress
  --mode <color|gray|bilevel>   (padrão color)
  --async              Usa API assíncrona para arquivo único
  --args               Somente imprime os args que seriam usados (não executa)
  --help               Mostra esta ajuda

Cancelamento:
  Pressione Ctrl+C para cancelar.
''');
}

int _parseMode(String s) {
  switch (s.toLowerCase()) {
    case 'gray':
    case 'grey':
      return GsxColorMode.gray;
    case 'bilevel':
    case 'mono':
    case 'bw':
      return GsxColorMode.bilevel;
    default:
      return GsxColorMode.color;
  }
}

Future<int> main(List<String> argv) async {
  if (argv.isEmpty || argv.contains('--help')) {
    printUsage();
    return 0;
  }

  String? inPath;
  String? outPath;
  String? inDir;
  String? outDir;
  String? preset;
  int dpi = 150;
  int q = 65;
  int mode = GsxColorMode.color;
  bool useAsync = false;
  bool onlyArgs = false;

  for (int i = 0; i < argv.length; i++) {
    final a = argv[i];
    String? next([String msg = 'faltando valor para a']) {
      if (i + 1 >= argv.length) {
        printUsage(msg);
        exitCode = 64;
        return null;
      }
      return argv[++i];
    }

    switch (a) {
      case '--in':
        inPath = next();
        if (inPath == null) return exitCode;
        break;
      case '--out':
        outPath = next();
        if (outPath == null) return exitCode;
        break;
      case '--dir':
        inDir = next();
        if (inDir == null) return exitCode;
        break;
      case '--outdir':
        outDir = next();
        if (outDir == null) return exitCode;
        break;
      case '--dpi':
        final v = next();
        if (v == null) return exitCode;
        dpi = int.tryParse(v) ?? dpi;
        break;
      case '--q':
        final v = next();
        if (v == null) return exitCode;
        q = int.tryParse(v) ?? q;
        break;
      case '--preset':
        preset = next();
        if (preset == null) return exitCode;
        break;
      case '--mode':
        final v = next();
        if (v == null) return exitCode;
        mode = _parseMode(v);
        break;
      case '--async':
        useAsync = true;
        break;
      case '--args':
        onlyArgs = true;
        break;
      default:
        printUsage('opção desconhecida: $a');
        return 64;
    }
  }

  if (inDir != null) {
    if (outDir == null) {
      printUsage('para --dir é obrigatório informar --outdir');
      return 64;
    }
  } else if (inPath == null) {
    printUsage('informe --in <arquivo.pdf> ou --dir <pasta>');
    return 64;
  }

  final bridge = GsxBridge.open(); // carrega a DLL/.so padrão no PATH
  // Se precisar de um caminho específico: GsxBridge.open('C:/.../gsx_bridge.dll');

  // Progress printer

  void onProgress(int page, int total, String line) {
    // Constrói a string de progresso de forma robusta
    String progressMessage;
    if (page > 0) {
      if (total > 0) {
        // Caso ideal: sabemos o total
        final percent = (page / total * 100).toStringAsFixed(1);
        progressMessage = 'Progresso: $percent% (página $page de $total)';
      } else {
        // Caso comum: não sabemos o total, mas sabemos a página atual
        progressMessage = 'Progresso: Processando página $page...';
      }
    } else if (line.trim().isNotEmpty) {
      // Mostra a linha de log inicial, mas corta para não ser muito longa
      progressMessage = line.length > 70 ? line.substring(0, 67) + '...' : line;
    } else {
      return; // Ignora linhas vazias
    }

    // Limpa a linha e escreve a mensagem
    // O 'padRight' garante que a linha anterior seja completamente apagada
    stdout.write('\r${progressMessage.padRight(72)}');
  }

  // Ctrl+C -> cancel
  final cancel = GsxCancelToken();
  final sub = ProcessSignal.sigint.watch().listen((_) {
    stderr.writeln('\nCancelando…');
    cancel.cancel();
  });

  int rc = 0;

  try {
    if (inDir != null) {
      // ------- MODO PASTA → PASTA -------
      if (!Directory(inDir).existsSync()) {
        stderr.writeln('Diretório de entrada não existe: $inDir');
        return 66;
      }
      Directory(outDir!).createSync(recursive: true);

      if (onlyArgs) {
        stdout.writeln(
            '(modo pasta) --args não imprime argv por arquivo; executando direto.');
      }

      rc = bridge.compressDirSync(
        inputDir: inDir,
        outputDir: outDir,
        dpi: dpi,
        jpegQuality: q,
        preset: preset,
        colorMode: mode,
        onProgress: onProgress,
        onFile: (inp, outp) {
          stdout.writeln(
              '\nArquivo: ${p.basename(inp)} -> ${p.relative(outp, from: outDir)}');
        },
        cancel: cancel,
      );
      stdout.writeln('\nResultado: rc=$rc');
    } else {
      // ------- MODO ARQUIVO ÚNICO -------
      final input = inPath!;
      final output = outPath ??
          p.join(p.dirname(input),
              '${p.basenameWithoutExtension(input)}.compressed.pdf');

      if (onlyArgs) {
        final args = bridge.buildPdfwriteArgs(
          input: input,
          output: output,
          dpi: dpi,
          jpegQuality: q,
          preset: preset,
          colorMode: mode,
        );
        stdout.writeln('Args (${args.length}):');
        for (final a in args) stdout.writeln('  $a');
        return 0;
      }

      final sw = Stopwatch()..start();

      if (useAsync) {
        stdout.writeln('Executando assíncrono…');
        final job = bridge.compressFileNativeAsync(
          inputPath: input,
          outputPath: output,
          dpi: dpi,
          jpegQuality: q,
          preset: preset,
          colorMode: mode,
          onProgress: onProgress,
          cancel: cancel,
        );

        // Poll simples
        while (true) {
          final st = job.status();
          if (st != 0) {
            rc = job.join();
            break;
          }
          await Future.delayed(const Duration(milliseconds: 120));
        }
      } else {
        stdout.writeln('Executando síncrono…');
        rc = bridge.compressFileNativeSync(
          inputPath: input,
          outputPath: output,
          dpi: dpi,
          jpegQuality: q,
          preset: preset,
          colorMode: mode,
          onProgress: onProgress,
          cancel: cancel,
        );
      }

      sw.stop();
      stdout.writeln('\nrc=$rc   tempo=${sw.elapsed}');
      if (rc >= 0) {
        final inSize = File(input).lengthSync();
        final outSize = File(output).lengthSync();
        stdout.writeln(
            'OK → ${p.basename(output)}  (${_fmtBytes(outSize)})  [era ${_fmtBytes(inSize)}]');
      }
    }
  } on GsxException catch (e) {
    stderr.writeln('\nFalhou: $e');
    rc = e.code;
  } catch (e, st) {
    stderr.writeln('\nErro inesperado: $e\n$st');
    rc = -1;
  } finally {
    await sub.cancel();
    // Se no seu app você planeja descartar a lib:
    bridge.dispose(); // libera NativeCallables do registry
  }

  return rc;
}

String _fmtBytes(int b) {
  const u = ['B', 'KB', 'MB', 'GB', 'TB'];
  var i = 0;
  var v = b.toDouble();
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(2)} ${u[i]}';
}
