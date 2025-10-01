import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;

import 'package:pdf_tools/src/libui/libui.dart';
import 'package:pdf_tools/src/compress/compress_logic.dart' as logic;

void main() async {
  LibUI.init();

  final window = Window('Octopus PDF Compressor', 600, 340);
  window.margined = true;

  final mainBox = VerticalBox();
  mainBox.padded = true;
  window.child = mainBox;

  // --- UI Setup ---
  final fileSelectionBox = HorizontalBox()..padded = true;
  final selectFileButton = Button('Selecionar PDF...');
  final selectFolderButton = Button('Selecionar Pasta...');
  final selectedFileLabel = Label('Nenhum arquivo ou pasta selecionado.');
  fileSelectionBox.add(selectFileButton, stretchy: false);
  fileSelectionBox.add(selectFolderButton, stretchy: false);
  mainBox.add(fileSelectionBox);
  mainBox.add(selectedFileLabel);

  final optionsGrid = Grid()..padded = true;
  optionsGrid.add(Label('Qualidade (Preset)'), 0, 0, 1, 1, false, Align.Fill,
      false, Align.Fill);
  final qualityCombo = Combobox();
  qualityCombo.append('Padrão (default)');
  qualityCombo.append('Tela (screen)');
  qualityCombo.append('E-book (ebook)');
  qualityCombo.append('Impressora (printer)');
  qualityCombo.append('Gráfica (prepress)');
  qualityCombo.selected = 0;
  optionsGrid.add(
      qualityCombo, 1, 0, 1, 1, true, Align.Fill, false, Align.Fill);

  optionsGrid.add(Label('DPI para imagens'), 0, 1, 1, 1, false, Align.Fill,
      false, Align.Fill);
  final dpiSpinbox = Spinbox(72, 600)..value = 150;
  optionsGrid.add(dpiSpinbox, 1, 1, 1, 1, true, Align.Fill, false, Align.Fill);
  mainBox.add(optionsGrid);

  final actionBox = VerticalBox()..padded = true;
  final compressButton = Button('Comprimir');
  compressButton.enabled = false;
  final progressLabel = Label('');
  final progressBar = ProgressBar();
  actionBox.add(compressButton);
  actionBox.add(progressLabel);
  actionBox.add(progressBar);
  mainBox.add(actionBox);

  // --- Application State and Logic ---
  final List<String> filesToProcess = [];

  String formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  void updateUiAfterSelection() {
    if (filesToProcess.isEmpty) {
      selectedFileLabel.text = 'Nenhum arquivo ou pasta selecionado.';
      compressButton.enabled = false;
      return;
    }
    if (filesToProcess.length == 1) {
      final file = File(filesToProcess.first);
      try {
        final size = file.lengthSync();
        final displayName = p.basename(file.path);
        // CORREÇÃO APLICADA AQUI
        selectedFileLabel.text = 'Arquivo: $displayName (${formatBytes(size)})';
        compressButton.text = 'Comprimir PDF';
        compressButton.enabled = true;
      } catch (e) {
        selectedFileLabel.text = 'Erro ao ler o arquivo selecionado.';
        compressButton.enabled = false;
      }
    } else {
      selectedFileLabel.text =
          '${filesToProcess.length} arquivos PDF selecionados para processamento em lote.';
      compressButton.text = 'Comprimir ${filesToProcess.length} PDFs';
      compressButton.enabled = true;
    }
  }

  selectFileButton.onClicked = () {
    final path = window.openFile();
    if (path != null) {
      filesToProcess
        ..clear()
        ..add(path);
      LibUI.queueMain(updateUiAfterSelection);
    }
  };

  selectFolderButton.onClicked = () {
    final path = window.openFolder();
    if (path != null) {
      filesToProcess.clear();
      final dir = Directory(path);
      try {
        final pdfs = dir
            .listSync()
            .whereType<File>()
            .where((f) => p.extension(f.path).toLowerCase() == '.pdf');
        filesToProcess.addAll(pdfs.map((f) => f.path));
      } catch (e) {
        LibUI.msgBoxError(window, 'Erro ao Ler Pasta',
            'Não foi possível ler os arquivos da pasta selecionada:\n$e');
      }
      LibUI.queueMain(updateUiAfterSelection);
    }
  };

  compressButton.onClicked = () {
    if (filesToProcess.isEmpty) return;

    final controlsToToggle = [
      selectFileButton,
      selectFolderButton,
      compressButton,
      qualityCombo,
      dpiSpinbox
    ];
    for (var c in controlsToToggle) {
      c.enabled = false;
    }

    progressBar.value = 0;
    progressLabel.text = 'Iniciando lote...';

    // A função `processBatch` agora está mais limpa
    processBatch(
      files: List.from(filesToProcess),
      dpi: dpiSpinbox.value,
      quality: [
        'default',
        'screen',
        'ebook',
        'printer',
        'prepress'
      ][qualityCombo.selected],
      window: window,
      progressLabel: progressLabel,
      progressBar: progressBar,
    ).whenComplete(() {
      LibUI.queueMain(() {
        for (var c in controlsToToggle) {
          c.enabled = true;
        }
        progressLabel.text = 'Lote finalizado.';
        progressBar.value = 0;
      });
    });
  };

  window.onClosing = () {
    LibUI.quit();
    return true;
  };

  window.show();
  await LibUI.run();
}

// Função para processar o lote de arquivos sequencialmente
Future<void> processBatch({
  required List<String> files,
  required int dpi,
  required String quality,
  required Window window,
  required Label progressLabel,
  required ProgressBar progressBar,
}) async {
  int successCount = 0;
  for (int i = 0; i < files.length; i++) {
    final filePath = files[i];
    try {
      await logic.compressPdfFile(
        inputPath: filePath,
        dpi: dpi,
        quality: quality,
        onProgress: (message, percentage) {
          LibUI.queueMain(() {
            progressLabel.text =
                '[${i + 1}/${files.length}] ${p.basename(filePath)}: $message';
            progressBar.value = percentage ?? -1;
          });
        },
      );
      successCount++;
    } catch (e) {
      LibUI.queueMain(() {
        LibUI.msgBoxError(window, 'Erro no Arquivo',
            'Falha ao processar ${p.basename(filePath)}:\n$e');
      });
    }
  }
  LibUI.queueMain(() {
    LibUI.msgBox(window, 'Processamento Concluído',
        '$successCount de ${files.length} arquivo(s) processado(s) com sucesso.');
  });
}
