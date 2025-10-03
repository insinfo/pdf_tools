// FILE: bin/octopus_desktop2.dart
// -
// Octopus PDF (Nuklear + GDI) — versão com correções e debug
// - Corrige SCISSOR (reset do clip antes de aplicar)
// - Corrige cálculo do ponteiro do texto em NK_COMMAND_TEXT

// - CORRIGIDO: Usa um TextEditingController persistente para o campo de saída
// -

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:pdf_tools/src/nuklear/nuklear.dart';
import 'package:pdf_tools/src/nuklear/nuklear_bindings.dart' as nk;
import 'package:pdf_tools/src/compress/compress_logic.dart' as logic;

class AppState {
  List<String> filesToProcess = [];
  String outputDir = '';
  // Controller persistente para o campo de texto do diretório de saída.
  final outputDirController = TextEditingController(text: '');

  final qualityOptions = ['Padrão', 'Tela', 'E-book', 'Impressora', 'Gráfica'];
  final qualityValues = ['default', 'screen', 'ebook', 'printer', 'prepress'];
  int qualityIndex = 0;
  final dpiController = TextEditingController(text: '150');
  final coresController =
      TextEditingController(text: Platform.numberOfProcessors.toString());
  bool isProcessing = false;
  bool cancelRequested = false;
  String progressMessage = '';
  double progressValue = 0.0; // 0.0 a 1.0
}

void main() async {
  final state = AppState();
  final app = Nuklear(
    title: 'Octopus PDF',
    width: 800,
    height: 600,
    builder: (ui) => buildUi(ui, state),
    // Ative prints detalhados do wrapper:
    debug: true,
  );

  await app.run();
}

void buildUi(Nuklear nkui, AppState state) {
  if (nkui.begin('Main',
      x: 0,
      y: 0,
      width: nkui.width.toDouble(),
      height: nkui.height.toDouble(),
      flags: nk.nk_panel_flags.NK_WINDOW_NO_SCROLLBAR)) {
    //  SELEÇÃO DE ARQUIVOS
    nkui.layoutRowDynamic(height: 35, columns: 2);
    if (nkui.button('Selecionar PDF...') && !state.isProcessing) {
      final path = nkui.showOpenFileDialog(
          title: 'Selecione um PDF',
          filter: 'Arquivos PDF\x00*.pdf\x00Todos os Arquivos\x00*.*\x00');
      if (path != null) {
        state.filesToProcess = [path];
        _updateUiAfterSelection(state);
        stdout.writeln('[UI] PDF selecionado: $path');
      }
    }
    if (nkui.button('Selecionar Pasta...') && !state.isProcessing) {
      final path =
          nkui.showOpenFolderDialog(title: 'Selecione uma pasta com PDFs');
      if (path != null) {
        state.filesToProcess = Directory(path)
            .listSync()
            .whereType<File>()
            .where((f) => p.extension(f.path).toLowerCase() == '.pdf')
            .map((f) => f.path)
            .toList();
        _updateUiAfterSelection(state);
        stdout.writeln('[UI] Pasta selecionada: $path '
            '(${state.filesToProcess.length} PDFs)');
      }
    }

    //  RÓTULO DE STATUS DO ARQUIVO
    nkui.layoutRowDynamic(height: 30, columns: 1);
    final fileLabel = state.filesToProcess.isEmpty
        ? 'Nenhum arquivo ou pasta selecionado.'
        : (state.filesToProcess.length == 1
            ? 'Arquivo: ${p.basename(state.filesToProcess.first)} '
                '(${_formatBytes(File(state.filesToProcess.first).lengthSync())})'
            : '${state.filesToProcess.length} arquivos PDF selecionados.');
    nkui.label(fileLabel, alignment: nk.nk_text_alignment.NK_TEXT_LEFT);

    //  PAINEL DE OPÇÕES
    nkui.layoutRowDynamic(height: 150, columns: 1);
    if (nkui.groupBegin('Opções',
        flags: nk.nk_panel_flags.NK_WINDOW_BORDER |
            nk.nk_panel_flags.NK_WINDOW_TITLE)) {
      nkui.layoutRowDynamic(height: 30, columns: 2);
      nkui.label('Qualidade (Preset):');
      state.qualityIndex = nkui.combo(
          state.qualityOptions[state.qualityIndex], 200, state.qualityOptions);

      nkui.layoutRowDynamic(height: 30, columns: 2);
      nkui.label('DPI para imagens:');
      nkui.propertyInt('DPI',
          min: 72,
          controller: state.dpiController,
          max: 600,
          step: 10,
          incPerPixel: 1);

      nkui.layoutRowDynamic(height: 30, columns: 2);
      nkui.label('Núcleos (máx):');
      nkui.propertyInt('Cores',
          min: 1,
          controller: state.coresController,
          max: Platform.numberOfProcessors,
          step: 1,
          incPerPixel: 1);

      nkui.groupEnd();
    }

    //  PASTA DE SAÍDA
    nkui.layoutRowDynamic(height: 35, columns: 3);
    nkui.label('Salvar em:');
    // CORRIGIDO: Usa o controller do AppState
    nkui.editString(
      nk.nk_edit_flags.NK_EDIT_READ_ONLY,
      state.outputDirController,
    );
    if (nkui.button('Alterar...') && !state.isProcessing) {
      final path =
          nkui.showOpenFolderDialog(title: 'Selecione a pasta de saída');
      if (path != null) {
        state.outputDir = path;
        state.outputDirController.text = path;
        stdout.writeln('[UI] Pasta de saída: $path');
      }
    }

    //  AÇÕES E PROGRESSO
    nkui.spacing(1);
    nkui.layoutRowDynamic(height: 35, columns: 1);
    if (state.isProcessing) {
      if (nkui.button('Cancelar')) {
        state.cancelRequested = true;
        state.progressMessage = 'Cancelando após o arquivo atual...';
        stdout.writeln('[UI] Cancelar requisitado.');
      }
    } else {
      if (nkui.button('Comprimir ${state.filesToProcess.length} PDF(s)') &&
          state.filesToProcess.isNotEmpty &&
          state.outputDir.isNotEmpty) {
        _startCompression(state, nkui.requestRepaint); // <-- passa callback
      }
    }

    nkui.layoutRowDynamic(height: 20, columns: 1);
    nkui.label(state.progressMessage);

    nkui.layoutRowDynamic(height: 20, columns: 1);
    nkui.progress((state.progressValue * 100).toInt(), 100);
  }
  nkui.end();
}

// ===================== LÓGICA =====================

void _updateUiAfterSelection(AppState state) {
  state.outputDir = state.filesToProcess.isNotEmpty
      ? p.dirname(state.filesToProcess.first)
      : '';
  state.outputDirController.text =
      state.outputDir; // CORRIGIDO: Atualiza o controller
}

void _startCompression(AppState state, void Function() requestRepaint) async {
  if (state.filesToProcess.isEmpty || state.outputDir.isEmpty) return;

  state.isProcessing = true;
  state.cancelRequested = false;
  state.progressValue = 0.0;
  state.progressMessage = 'Iniciando...';
  requestRepaint();

  final int dpi = int.tryParse(state.dpiController.text) ?? 150;
  final int maxCores =
      int.tryParse(state.coresController.text) ?? Platform.numberOfProcessors;

  stdout.writeln('[COMPRESS] Início — arquivos=${state.filesToProcess.length}, '
      'dpi=$dpi, quality=${state.qualityValues[state.qualityIndex]}, '
      'maxCores=$maxCores, out=${state.outputDir}');

  final uiPort = ReceivePort();
  Isolate? iso;
  SendPort? workerPort;

  uiPort.listen((msg) {
    if (msg is SendPort) {
      workerPort = msg;
      workerPort!.send({
        'cmd': 'start',
        'files': List.from(state.filesToProcess),
        'dpi': dpi,
        'quality': state.qualityValues[state.qualityIndex],
        'maxCores': maxCores,
        'outputDir': state.outputDir,
      });
      return;
    }

    final map = (msg is Map) ? Map<String, dynamic>.from(msg) : const {};
    switch (map['type']) {
      case 'progress':
        final message = map['message'] as String? ?? '';
        final percentage = map['percentage'] as int?;
        final idx = map['fileIndex'] as int? ?? 1;
        final total = map['totalFiles'] as int? ?? 1;
        state.progressMessage = '[$idx/$total] $message';
        state.progressValue = (idx - 1 + ((percentage ?? 0) / 100.0)) / total;
        requestRepaint(); // <-- repintar
        break;

      case 'done':
        state.isProcessing = false;
        state.progressMessage = state.cancelRequested
            ? 'Processo cancelado.'
            : 'Lote finalizado com sucesso!';
        state.progressValue = state.cancelRequested ? state.progressValue : 1.0;
        stdout.writeln('[COMPRESS] Fim — cancelado=${state.cancelRequested}');
        uiPort.close();
        iso?.kill(priority: Isolate.immediate);
        requestRepaint(); // <-- repintar
        break;

      case 'error':
        state.progressMessage = 'Erro: ${map['error']}';
        state.isProcessing = false;
        uiPort.close();
        iso?.kill(priority: Isolate.immediate);
        requestRepaint(); // <-- repintar
        break;
    }
  });

  iso = await Isolate.spawn(_compressionWorker, uiPort.sendPort);

  // Cancelamento
  Timer.periodic(const Duration(milliseconds: 100), (t) {
    if (!state.isProcessing) {
      t.cancel();
      return;
    }
    if (state.cancelRequested && workerPort != null) {
      workerPort!.send({'cmd': 'cancel'});
      t.cancel();
    }
  });
}

void _compressionWorker(SendPort mainPort) async {
  final inbox = ReceivePort();
  mainPort.send(inbox.sendPort);

  // Estado de cancelamento (atualizado por mensagens)
  var cancelFlag = false;

  await for (final msg in inbox) {
    if (msg is Map && msg['cmd'] == 'start') {
      final files = (msg['files'] as List).cast<String>();
      final dpi = msg['dpi'] as int;
      final quality = msg['quality'] as String;
      final maxCores = msg['maxCores'] as int;
      final outputDir = msg['outputDir'] as String;

      try {
        await processBatch(
          files: files,
          dpi: dpi,
          quality: quality,
          maxCores: maxCores,
          outputDir: outputDir,
          isCancelRequested: () => cancelFlag,
          onProgress: (message, percentage, fileIndex, totalFiles) {
            mainPort.send({
              'type': 'progress',
              'message': message,
              'percentage': percentage,
              'fileIndex': fileIndex,
              'totalFiles': totalFiles,
            });
          },
        );
        mainPort.send({'type': 'done'});
      } catch (e, s) {
        mainPort.send({'type': 'error', 'error': '$e\n$s'});
      }
    } else if (msg is Map && msg['cmd'] == 'cancel') {
      cancelFlag = true;
    }
  }
}

Future<void> processBatch({
  required List<String> files,
  required int dpi,
  required String quality,
  required int maxCores,
  required String outputDir,
  required bool Function() isCancelRequested,
  required void Function(
          String message, int? percentage, int fileIndex, int totalFiles)
      onProgress,
}) async {
  for (int i = 0; i < files.length; i++) {
    if (isCancelRequested()) break;
    final filePath = files[i];
    try {
      await logic.compressPdfFile(
        inputPath: filePath,
        dpi: dpi,
        quality: quality,
        maxCores: maxCores,
        outputDir: outputDir,
        isCancelRequested: isCancelRequested,
        onProgress: (message, percentage) {
          if (!isCancelRequested()) {
            onProgress('${p.basename(filePath)}: $message', percentage, i + 1,
                files.length);
          }
        },
      );
    } catch (e, s) {
      stderr.writeln('[COMPRESS][ERRO] ${p.basename(filePath)}: $e\n$s');
    }
  }
}

// ===================== UTILS =====================

String _formatBytes(int bytes, {int decimals = 2}) {
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB"];
  var i = (log(bytes) / log(1024)).floor();
  return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
}
