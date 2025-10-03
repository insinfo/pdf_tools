//C:\MyDartProjects\pdf_tools\flutter_pdf_tools\lib\main.dart

// ignore_for_file: implementation_imports, deprecated_member_use

// Octopus PDF verção flutter
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'package:pdf_tools/src/compress/compress_logic.dart' as logic;
import 'package:window_manager/window_manager.dart';
//import 'package:pdf_tools/pdf_tools.dart';
// flutter run -d windows 
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Define as opções da janela
  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 750), 
    minimumSize: Size(800, 700), 
    center: true, 
    title: "Octopus PDF", 
  );

  // Espera a janela estar pronta para mostrar com as opções definidas
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Octopus PDF',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      home: const MyHomePage(title: 'Octopus PDF Tools 🐙'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // --- Estado da Aplicação ---
  final List<String> _filesToProcess = [];
  String _outputDir = '';
  bool _isProcessing = false;
  bool _cancelRequested = false;

  // --- Estado das Opções ---
  String _selectedQuality = 'default';
  final _dpiController = TextEditingController(text: '150');
  final _coresController =
      TextEditingController(text: Platform.numberOfProcessors.toString());

  // --- Estado do Progresso ---
  String _progressMessage = '';
  double? _progressValue; // null para progresso indeterminado

  @override
  void dispose() {
    _dpiController.dispose();
    _coresController.dispose();
    super.dispose();
  }

  // --- Lógica de Seleção de Arquivos ---
  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() {
        _filesToProcess
          ..clear()
          ..add(path);
        _outputDir = p.dirname(path);
      });
    }
  }

  Future<void> _selectFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;

    try {
      final dir = Directory(path);
      final pdfs = dir
          .listSync()
          .whereType<File>()
          .where((f) => p.extension(f.path).toLowerCase() == '.pdf')
          .map((f) => f.path)
          .toList();

      setState(() {
        _filesToProcess
          ..clear()
          ..addAll(pdfs);
        if (pdfs.isNotEmpty) {
          _outputDir = path;
        } else {
          _showInfoDialog('Nenhum PDF encontrado',
              'A pasta selecionada não contém arquivos .pdf.');
        }
      });
    } catch (e) {
      _showErrorDialog('Erro ao Ler Pasta',
          'Não foi possível ler os arquivos da pasta selecionada:\n$e');
    }
  }

  Future<void> _selectOutputDir() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      setState(() {
        _outputDir = path;
      });
    }
  }

  // --- Lógica de Compressão ---
  void _onCompressButtonPressed() {
    if (_isProcessing) {
      _cancelCompression();
    } else {
      _startCompression();
    }
  }

  void _cancelCompression() {
    setState(() {
      _cancelRequested = true;
      _progressMessage = 'Cancelando após o arquivo atual...';
    });
  }

  Future<void> _startCompression() async {
    if (_filesToProcess.isEmpty || _outputDir.isEmpty) return;

    // Esconde o teclado caso esteja aberto
    FocusScope.of(context).unfocus();

    setState(() {
      _isProcessing = true;
      _cancelRequested = false;
      _progressMessage = 'Iniciando lote...';
      _progressValue = 0.0;
    });

    final int dpi = int.tryParse(_dpiController.text) ?? 150;
    final int maxCores =
        int.tryParse(_coresController.text) ?? Platform.numberOfProcessors;
    int successCount = 0;
    final totalFiles = _filesToProcess.length;

    // Nota: Se a função `compressPdfFile` for uma operação síncrona e demorada,
    // ela pode congelar a interface do usuário. Para uma aplicação de produção,
    // considere executá-la em um Isolate separado usando `compute()`.
    for (int i = 0; i < totalFiles; i++) {
      if (_cancelRequested) break;

      final filePath = _filesToProcess[i];
      try {
        await logic.compressPdfFile(
          inputPath: filePath,
          dpi: dpi,
          quality: _selectedQuality,
          maxCores: maxCores,
          outputDir: _outputDir,
          isCancelRequested: () => _cancelRequested,
          onProgress: (message, percentage) {
            if (mounted) {
              setState(() {
                if (!_cancelRequested) {
                  _progressMessage =
                      '[${i + 1}/$totalFiles] ${p.basename(filePath)}: $message';
                  // Assumindo que a porcentagem é de 0 a 100
                  _progressValue =
                      (percentage != null) ? percentage / 100.0 : null;
                }
              });
            }
          },
        );
        successCount++;
      } catch (e) {
        if (mounted) {
          await _showErrorDialog('Erro no Arquivo',
              'Falha ao processar ${p.basename(filePath)}:\n$e');
        }
      }
    }

    final String finalMessage = _cancelRequested
        ? 'Processo cancelado pelo usuário.'
        : '$successCount de $totalFiles arquivo(s) processado(s) com sucesso.';

    if (mounted) {
      await _showInfoDialog(
        _cancelRequested ? 'Processo Cancelado' : 'Processamento Concluído',
        finalMessage,
      );
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _cancelRequested = false;
        _progressMessage = finalMessage;
        _progressValue = 0.0;
      });
    }
  }

  // --- Helpers de UI (Diálogos e Formatadores) ---
  String _formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  String get _selectedFileLabelText {
    if (_filesToProcess.isEmpty) {
      return 'Nenhum arquivo ou pasta selecionado.';
    }
    if (_filesToProcess.length == 1) {
      final file = File(_filesToProcess.first);
      try {
        final size = file.lengthSync();
        final displayName = p.basename(file.path);
        return 'Arquivo: $displayName (${_formatBytes(size)})';
      } catch (e) {
        return 'Erro ao ler o arquivo selecionado.';
      }
    }
    return '${_filesToProcess.length} arquivos PDF selecionados.';
  }

  Future<void> _showInfoDialog(String title, String content) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _showErrorDialog(String title, String content) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.error, color: Theme.of(context).colorScheme.error),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canCompress =
        _filesToProcess.isNotEmpty && _outputDir.isNotEmpty;
    final String compressButtonText = _isProcessing
        ? 'Cancelar'
        : (_filesToProcess.length > 1
            ? 'Comprimir ${_filesToProcess.length} PDFs'
            : 'Comprimir PDF');

    return WillPopScope(
      onWillPop: () async {
        if (_isProcessing) {
          _showInfoDialog('Processamento em Andamento',
              'Por favor, aguarde ou cancele o processo antes de fechar.');
          return false; // Impede o fechamento da janela
        }
        return true; // Permite o fechamento
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: AbsorbPointer(
          absorbing: _isProcessing,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionCard(
                  title: '1. Selecionar Arquivos',
                  children: [
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Selecionar PDF...'),
                          onPressed: _selectFile,
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.folder_open_outlined),
                          label: const Text('Selecionar Pasta...'),
                          onPressed: _selectFolder,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(_selectedFileLabelText,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                _buildSectionCard(
                  title: '2. Definir Opções',
                  children: [
                    _OptionRow(
                      label: 'Qualidade (Preset):',
                      child: DropdownButton<String>(
                        value: _selectedQuality,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(
                              value: 'default',
                              child: Text('Padrão (default)')),
                          DropdownMenuItem(
                              value: 'screen', child: Text('Tela (screen)')),
                          DropdownMenuItem(
                              value: 'ebook', child: Text('E-book (ebook)')),
                          DropdownMenuItem(
                              value: 'printer',
                              child: Text('Impressora (printer)')),
                          DropdownMenuItem(
                              value: 'prepress',
                              child: Text('Gráfica (prepress)')),
                        ],
                        onChanged: (v) => setState(() => _selectedQuality = v!),
                      ),
                    ),
                    _OptionRow(
                      label: 'DPI para Imagens:',
                      child: _NumberTextField(controller: _dpiController),
                    ),
                    _OptionRow(
                      label: 'Núcleos (máx):',
                      child: _NumberTextField(controller: _coresController),
                    ),
                  ],
                ),
                _buildSectionCard(
                  title: '3. Escolher Destino',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(text: _outputDir),
                            readOnly: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Salvar em:',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.create_new_folder_outlined),
                          onPressed: _selectOutputDir,
                          tooltip: 'Escolher pasta de saída',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isProcessing
                        ? Colors.red.shade700
                        : Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: canCompress ? _onCompressButtonPressed : null,
                  child: Text(compressButtonText),
                ),
                if (_isProcessing || _progressMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Column(
                      children: [
                        Text(_progressMessage, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: _progressValue),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

// Widget auxiliar para as linhas de opção
class _OptionRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _OptionRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), child],
      ),
    );
  }
}

// Widget auxiliar para os campos de número
class _NumberTextField extends StatelessWidget {
  final TextEditingController controller;
  const _NumberTextField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration:
            const InputDecoration(border: OutlineInputBorder(), isDense: true),
      ),
    );
  }
}
