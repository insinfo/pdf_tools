// C:\MyDartProjects\pdf_tools\flutter_pdf_tools\lib\main.dart
// ignore_for_file: implementation_imports, deprecated_member_use, curly_braces_in_flow_control_structures

import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_tools/src/compress/compress_logic2.dart' as logic;
import 'package:window_manager/window_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 950), // Altura aumentada para caber as novas opções
    minimumSize: Size(800, 800),
    center: true,
    title: "Octopus PDF",
  );

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
      home: const MyHomePage(title: 'Octopus PDF Tools'),
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
  //  Estado da Aplicação
  final List<String> _filesToProcess = [];
  String _outputDir = '';
  bool _isProcessing = false;
  bool _cancelRequested = false;

  //  Estado das Opções
  String _selectedQuality = 'default';
  String _selectedColorMode = 'color';
  final _dpiController = TextEditingController(text: '120');
  final _jpegQualityController = TextEditingController(text: '75');
  final _firstPageController = TextEditingController();
  final _lastPageController = TextEditingController();
  final _coresController = TextEditingController(text: '1');
  bool _linearizePdf = true;

  //  Estado do Progresso
  String _progressMessage = '';
  double? _progressValue;

  @override
  void dispose() {
    _dpiController.dispose();
    _coresController.dispose();
    _jpegQualityController.dispose();
    _firstPageController.dispose();
    _lastPageController.dispose();
    _logScroll.dispose(); // <-- importante
    super.dispose();
  }

  //  Console de Log (buffer circular)
  static const int _kLogMax = 5000;
  static const int _kTrimChunk = 500; // corta 10% quando ultrapassar
  final List<String> _log = <String>[];
  final ScrollController _logScroll = ScrollController();
  bool _showLog = false; // começa fechado
  bool _autoScrollLog = true;

  void _appendLog(String line) {
    final now = TimeOfDay.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _log.add('[$ts] $line');

    // poda para não estourar o limite
    if (_log.length > _kLogMax) {
      // remove um bloco para evitar custo alto linha a linha
      final cut = (_log.length - _kLogMax + _kTrimChunk).clamp(
        _kTrimChunk,
        _log.length,
      );
      _log.removeRange(0, cut);
    }

    if (mounted) {
      setState(() {}); // atualiza quando visível
      if (_autoScrollLog) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_logScroll.hasClients) {
            _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
          }
        });
      }
    }
  }

  void _clearLog() {
    setState(() => _log.clear());
  }

  Future<void> _copyLog() async {
    if (_log.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _log.join('\n')));
    if (mounted)
      _showInfoDialog('Copiado', 'Log copiado para a área de transferência.');
  }

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
        _firstPageController.clear();
        _lastPageController.clear();
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
        _firstPageController.clear();
        _lastPageController.clear();
        if (pdfs.isNotEmpty) {
          _outputDir = path;
        } else {
          _showInfoDialog(
            'Nenhum PDF encontrado',
            'A pasta selecionada não contém arquivos .pdf.',
          );
        }
      });
    } catch (e) {
      _showErrorDialog(
        'Erro ao Ler Pasta',
        'Não foi possível ler os arquivos da pasta selecionada:\n$e',
      );
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
    _appendLog('Cancelamento solicitado pelo usuário.');
  }

  Future<void> _startCompression() async {
    if (_filesToProcess.isEmpty || _outputDir.isEmpty) return;
    FocusScope.of(context).unfocus();

    // início de execução: limpa e registra contexto
    _clearLog();
    _appendLog('===== NOVA EXECUÇÃO =====');
    _appendLog('Arquivos: ${_filesToProcess.length}');
    _appendLog('Saída: ${_outputDir.isEmpty ? "(não setada)" : _outputDir}');
    _appendLog(
      'Opções => preset=$_selectedQuality, jpeg=${_jpegQualityController.text}, dpi=${_dpiController.text}, cor=$_selectedColorMode, '
      'range=${_firstPageController.text.isEmpty ? "-" : _firstPageController.text}'
      '-${_lastPageController.text.isEmpty ? "-" : _lastPageController.text}, '
      'núcleos=${_coresController.text}',
    );

    setState(() {
      _isProcessing = true;
      _cancelRequested = false;
      _progressMessage = 'Iniciando lote...';
      _progressValue = 0.0;
    });

    final int dpi = int.tryParse(_dpiController.text) ?? 150;
    final int jpegQuality = int.tryParse(_jpegQualityController.text) ?? 75;
    final int firstPage = int.tryParse(_firstPageController.text) ?? 0;
    final int lastPage = int.tryParse(_lastPageController.text) ?? 0;
    final int maxCores = int.tryParse(_coresController.text) ?? 1;

    int successCount = 0;
    final totalFiles = _filesToProcess.length;

    for (int i = 0; i < totalFiles; i++) {
      if (_cancelRequested) break;

      final filePath = _filesToProcess[i];
      final name = p.basename(filePath);
      _appendLog('Iniciando: $name');

      try {
        await logic.compressPdfFile(
          inputPath: filePath,
          dpi: dpi,
          quality: _selectedQuality,
          jpegQuality: jpegQuality,
          colorMode: _selectedColorMode,
          firstPage: firstPage,
          lastPage: lastPage,
          maxIsolatesPerPdf: maxCores,
          outputDir: _outputDir,
          linearize: _linearizePdf,
          isCancelRequested: () => _cancelRequested,
          // 1) Progresso "amigável" (mantém barra e status)
          onProgress: (message, percentage) {
            if (!mounted) return;
            setState(() {
              if (!_cancelRequested) {
                _progressMessage = '[${i + 1}/$totalFiles] $name: $message';
                _progressValue = (percentage != null)
                    ? percentage / 100.0
                    : null;
              }
            });
          },
          // 2) **LOG BRUTO DO GHOSTSCRIPT** (stdout/stderr normalizados por linha)
          onLog: (line) {
            // respeita buffer circular (5000 linhas) e auto-scroll
            _appendLog(line);
          },
        );
        successCount++;
        _appendLog('Concluído: $name');
      } catch (e) {
        _appendLog('ERRO em $name: $e');
        if (mounted) {
          await _showErrorDialog(
            'Erro no Arquivo',
            'Falha ao processar $name:\n$e',
          );
        }
      }
    }

    final String finalMessage = _cancelRequested
        ? 'Processo cancelado pelo usuário.'
        : '$successCount de $totalFiles arquivo(s) processado(s) com sucesso.';

    _appendLog(finalMessage);

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
      try {
        final file = File(_filesToProcess.first);
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
            child: const Text('OK'),
          ),
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
            child: const Text('OK'),
          ),
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
          _showInfoDialog(
            'Processamento em Andamento',
            'Por favor, aguarde ou cancele o processo antes de fechar.',
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Row(
            children: [
              SvgPicture.asset('assets/logo_octopus_pdf.svg', height: 65),
              const SizedBox(width: 10),
              // 2. Coluna com Título e Subtítulo
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title),
                  const Text(
                    'Construído na PMRO',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // - conteúdo rolável (bloqueado enquanto processa) -
            Expanded(
              child: AbsorbPointer(
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
                          Text(
                            _selectedFileLabelText,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
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
                                  child: Text('Padrão'),
                                ),
                                DropdownMenuItem(
                                  value: 'screen',
                                  child: Text('Tela'),
                                ),
                                DropdownMenuItem(
                                  value: 'ebook',
                                  child: Text('E-book'),
                                ),
                                DropdownMenuItem(
                                  value: 'printer',
                                  child: Text('Impressora'),
                                ),
                                DropdownMenuItem(
                                  value: 'prepress',
                                  child: Text('Gráfica'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _selectedQuality = v!),
                            ),
                          ),
                          _OptionRow(
                            label: 'Qualidade JPEG (1-100):',
                            child: _NumberTextField(
                              controller: _jpegQualityController,
                            ),
                          ),
                          _OptionRow(
                            label: 'DPI para Imagens:',
                            child: _NumberTextField(controller: _dpiController),
                          ),
                          _OptionRow(
                            label: 'Modo de Cor:',
                            child: DropdownButton<String>(
                              value: _selectedColorMode,
                              isDense: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'color',
                                  child: Text('Colorido'),
                                ),
                                DropdownMenuItem(
                                  value: 'gray',
                                  child: Text('Tons de Cinza'),
                                ),
                                DropdownMenuItem(
                                  value: 'bilevel',
                                  child: Text('Preto e Branco'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _selectedColorMode = v!),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Intervalo de Páginas (opcional):',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _NumberTextField(
                                  controller: _firstPageController,
                                  hint: 'Início',
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('até'),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _NumberTextField(
                                  controller: _lastPageController,
                                  hint: 'Fim',
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _OptionRow(
                            label: 'Núcleos por PDF (máx):',
                            child: _NumberTextField(
                              controller: _coresController,
                            ),
                          ),
                          SwitchListTile(
                            title: const Text('Otimizar para Web (Linearizar)'),
                            subtitle: const Text(
                              'Permite visualização mais rápida online.',
                            ),
                            value: _linearizePdf,
                            onChanged: (bool value) {
                              setState(() {
                                _linearizePdf = value;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
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
                                  controller: TextEditingController(
                                    text: _outputDir,
                                  ),
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
                                icon: const Icon(
                                  Icons.create_new_folder_outlined,
                                ),
                                onPressed: _selectOutputDir,
                                tooltip: 'Escolher pasta de saída',
                              ),
                            ],
                          ),
                        ],
                      ),

                      // - CONSOLE (opcional) -
                      _buildSectionCard(
                        title: 'Console (opcional)',
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: SwitchListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Mostrar console de log'),
                                  value: _showLog,
                                  onChanged: (v) =>
                                      setState(() => _showLog = v),
                                ),
                              ),
                              Tooltip(
                                message: _autoScrollLog
                                    ? 'Auto-scroll ligado'
                                    : 'Auto-scroll desligado',
                                child: IconButton(
                                  onPressed: () => setState(
                                    () => _autoScrollLog = !_autoScrollLog,
                                  ),
                                  icon: Icon(
                                    _autoScrollLog
                                        ? Icons.south_outlined
                                        : Icons.pause_outlined,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Copiar',
                                onPressed: _log.isEmpty ? null : _copyLog,
                                icon: const Icon(Icons.copy_all_outlined),
                              ),
                              IconButton(
                                tooltip: 'Limpar',
                                onPressed: _log.isEmpty ? null : _clearLog,
                                icon: const Icon(Icons.delete_sweep_outlined),
                              ),
                            ],
                          ),
                          if (_showLog)
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Scrollbar(
                                controller:
                                    _logScroll, // <-- LIGA NO MESMO CONTROLLER
                                thumbVisibility: true,
                                child: ListView.builder(
                                  controller:
                                      _logScroll, // <-- MESMO CONTROLLER
                                  primary:
                                      false, // <-- evita usar PrimaryScrollController
                                  padding: const EdgeInsets.all(8),
                                  itemCount: _log.length,
                                  itemBuilder: (_, i) => Text(
                                    _log[i],
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),

            // - rodapé fixo: progresso + botão (fora do AbsorbPointer) -
            if (_isProcessing || _progressMessage.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Text(_progressMessage, textAlign: TextAlign.center),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: LinearProgressIndicator(value: _progressValue),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isProcessing
                      ? Colors.red.shade700
                      : Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(10),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: (_isProcessing || canCompress)
                    ? _onCompressButtonPressed
                    : null,
                child: Text(compressButtonText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
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
        children: [Text(label), const SizedBox(width: 16), child],
      ),
    );
  }
}

class _NumberTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  const _NumberTextField({required this.controller, this.hint});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          isDense: true,
          hintText: hint,
        ),
      ),
    );
  }
}
