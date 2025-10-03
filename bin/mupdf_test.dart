import 'dart:io';
import 'package:pdf_tools/src/gs_stdio_/ghostscript.dart'; // Importe o novo wrapper do Ghostscript
import 'package:pdf_tools/src/mupdf.dart';

void main() {
  final inputFile = r'C:\MyDartProjects\pdf_tools\pdfs\input\14_34074_Vol 5.pdf';
  final repairedFile = r'C:\MyDartProjects\pdf_tools\pdfs\output\14_34074_Vol 5_repaired.pdf';
  final outputFile = r'C:\MyDartProjects\pdf_tools\pdfs\output\14_34074_Vol 5_compressed.pdf';

  if (!File(inputFile).existsSync()) {
    stderr.writeln('Erro: O arquivo de entrada não foi encontrado: $inputFile');
    exit(1);
  }

  Directory(r'C:\MyDartProjects\pdf_tools\pdfs\output').createSync(recursive: true);

  try {
    final stopwatch = Stopwatch()..start();

    // --- PASSO 1: REPARAR O ARQUIVO USANDO A API DO GHOSTSCRIPT ---
    print('--- Passo 1: Reparando o PDF usando a API do Ghostscript ---');
    
    // Inicializa a classe Ghostscript, que carrega a gsdll64.dll
    final gs = Ghostscript.open(); 

    // Prepara os argumentos, exatamente como na linha de comando
    final gsArgs = [
      '-o',
      repairedFile,
      '-sDEVICE=pdfwrite',
      '-dPDFSETTINGS=/default',
      inputFile,
    ];

    print('Executando o Ghostscript via FFI...');
    // Usa runWithProgress para ver a saída do Ghostscript em tempo real
    gs.runWithProgress(gsArgs, (line) {
      print('GS > $line'); // Adiciona um prefixo para identificar a saída
    });

    print('Reparo com Ghostscript concluído com sucesso.');
    print('-----------------------------------------------------\n');

    // --- PASSO 2: OTIMIZAR O ARQUIVO REPARADO COM MUPDF ---
    print('--- Passo 2: Otimizando o PDF Reparado com MuPDF ---');
    MuPDFContext? context;
    try {
      context = MuPDFContext.initialize();
      print('Iniciando a otimização do PDF...');
      print('  -> Entrada: $repairedFile');
      print('  -> Saída:   $outputFile');
      
      context.cleanAndOptimize(
        inputFile: repairedFile,
        outputFile: outputFile,
        colorImageDPI: 150,
        grayImageDPI: 150,
        monoImageDPI: 300,
      );
    } finally {
      // Garante que o contexto do MuPDF seja liberado, mesmo se ocorrer um erro.
      context?.dispose();
    }
    
    stopwatch.stop();

    final originalSize = File(inputFile).lengthSync();
    final newSize = File(outputFile).lengthSync();
    final reduction = ((originalSize - newSize) / originalSize * 100).toStringAsFixed(2);
    
    print('\n--- RESULTADO FINAL ---');
    print('✅ Sucesso! O PDF foi reparado e otimizado.');
    print('Arquivo de Saída: $outputFile');
    print('Tamanho Original: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');
    print('Tamanho Novo:     ${(newSize / 1024 / 1024).toStringAsFixed(2)} MB');
    print('Redução:          $reduction %');
    print('Tempo de execução total: ${stopwatch.elapsedMilliseconds} ms');
    print('-----------------------');

  } catch (e) {
    print('\n--- ERRO ---');
    print('❌ Falha ao processar o PDF.');
    print(e);
    print('------------');
    exit(1);
  }
}