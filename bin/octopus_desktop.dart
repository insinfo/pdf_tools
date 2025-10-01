import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;

import 'package:pdf_tools/src/libui/libui.dart';
import 'package:pdf_tools/src/compress/compress_logic.dart' as logic;

void main() async {
  LibUI.init();

  final window = Window('Octopus PDF Compressor', 600, 420);
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

  optionsGrid.add(
      Label('Núcleos (máx)'), 0, 2, 1, 1, false, Align.Fill, false, Align.Fill);
  final coresSpin = Spinbox(1, Platform.numberOfProcessors)
    ..value = Platform.numberOfProcessors;
  optionsGrid.add(coresSpin, 1, 2, 1, 1, true, Align.Fill, false, Align.Fill);
  mainBox.add(optionsGrid);

  final outDirBox = HorizontalBox()..padded = true;
  final outDirEntry = Entry()..readOnly = true;
  final chooseOutBtn = Button('Pasta de Saída...');
  outDirBox.add(Label('Salvar em:'), stretchy: false);
  outDirBox.add(outDirEntry, stretchy: true);
  outDirBox.add(chooseOutBtn, stretchy: false);
  mainBox.add(outDirBox);

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
  bool isProcessing = false;
  bool cancelRequested = false;

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
      outDirEntry.text = '';
      return;
    }
    if (filesToProcess.length == 1) {
      final file = File(filesToProcess.first);
      try {
        final size = file.lengthSync();
        final displayName = p.basename(file.path);
        selectedFileLabel.text = 'Arquivo: $displayName (${formatBytes(size)})';
        compressButton.text = 'Comprimir PDF';
        outDirEntry.text = p.dirname(file.path);
        compressButton.enabled = true;
      } catch (e) {
        selectedFileLabel.text = 'Erro ao ler o arquivo selecionado.';
        compressButton.enabled = false;
      }
    } else {
      selectedFileLabel.text =
          '${filesToProcess.length} arquivos PDF selecionados para processamento em lote.';
      compressButton.text = 'Comprimir ${filesToProcess.length} PDFs';
      outDirEntry.text = p.dirname(filesToProcess.first);
      compressButton.enabled = true;
    }
  }

  // Declara a função de compressão para poder restaurá-la depois
  late void Function() compressHandler;

  // A função que é chamada quando o botão de cancelar é clicado
  void cancelHandler() {
    cancelRequested = true;
    progressLabel.text = 'Cancelando após o arquivo atual...';
    compressButton.enabled =
        false; // Desabilita o botão para evitar múltiplos cliques
  }

  // A função principal que inicia o processo
  compressHandler = () {
    if (filesToProcess.isEmpty) return;

    final controlsToToggle = [
      selectFileButton,
      selectFolderButton,
      qualityCombo,
      dpiSpinbox,
      chooseOutBtn,
      outDirEntry
    ];
    for (var c in controlsToToggle) {
      c.enabled = false;
    }

    isProcessing = true;
    cancelRequested = false;
    compressButton.text = 'Cancelar';
    compressButton.onClicked = cancelHandler;

    progressBar.value = 0;
    progressLabel.text = 'Iniciando lote...';

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
      maxCores: coresSpin.value,
      outputDir: outDirEntry.text,
      window: window,
      progressLabel: progressLabel,
      progressBar: progressBar,
      // Passa uma função para verificar se o cancelamento foi solicitado
      isCancelRequested: () => cancelRequested,
    ).whenComplete(() {
      LibUI.queueMain(() {
        for (var c in controlsToToggle) {
          c.enabled = true;
        }
        progressLabel.text =
            cancelRequested ? 'Processo cancelado.' : 'Lote finalizado.';
        progressBar.value = 0;
        compressButton.text = 'Comprimir';
        compressButton.onClicked =
            compressHandler; // Restaura o handler original
        isProcessing = false;
      });
    });
  };

  compressButton.onClicked = compressHandler;

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
        if (filesToProcess.isNotEmpty) outDirEntry.text = path;
      } catch (e) {
        LibUI.msgBoxError(window, 'Erro ao Ler Pasta',
            'Não foi possível ler os arquivos da pasta selecionada:\n$e');
      }
      LibUI.queueMain(updateUiAfterSelection);
    }
  };

  chooseOutBtn.onClicked = () {
    final path = window.openFolder();
    if (path != null) {
      outDirEntry.text = path;
    }
  };

  window.onClosing = () {
    if (isProcessing) {
      LibUI.msgBox(window, 'Processamento em Andamento',
          'Por favor, aguarde ou cancele o processo antes de fechar.');
      return false; // Impede o fechamento
    }
    LibUI.quit();
    return true;
  };

  window.show();
  await LibUI.run();
}

// CORREÇÃO: Adicionado o parâmetro `isCancelRequested`
Future<void> processBatch({
  required List<String> files,
  required int dpi,
  required String quality,
  required int maxCores,
  required String outputDir,
  required Window window,
  required Label progressLabel,
  required ProgressBar progressBar,
  required bool Function() isCancelRequested,
}) async {
  int successCount = 0;
  for (int i = 0; i < files.length; i++) {
    // CORREÇÃO: Usa a função passada como parâmetro para verificar
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
          LibUI.queueMain(() {
            if (!isCancelRequested()) {
              progressLabel.text =
                  '[${i + 1}/${files.length}] ${p.basename(filePath)}: $message';
              progressBar.value = percentage ?? -1;
            }
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

  if (!isCancelRequested()) {
    LibUI.queueMain(() {
      LibUI.msgBox(window, 'Processamento Concluído',
          '$successCount de ${files.length} arquivo(s) processado(s) com sucesso.');
    });
  }
}
