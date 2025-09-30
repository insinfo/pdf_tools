import 'dart:io';
import 'package:pdf_tools/src/mupdf.dart'; // Importe a API de alto nível

void main() {
  // 1. Defina o caminho do arquivo de entrada
  final inputFile = r'C:\MyDartProjects\pdf_tools\pdfs\input\14_34074_Vol 5.pdf';

  // 2. Verifique se o arquivo existe antes de continuar
  if (!File(inputFile).existsSync()) {
    stderr.writeln('Erro: O arquivo de entrada não foi encontrado: $inputFile');
    exit(1);
  }

  // 3. Declare as variáveis de recurso como anuláveis fora do try
  //    para que possam ser acessadas no bloco finally.
  MuPDFContext? context;
  MuPDFDocument? document;
  
  try {
    // 4. Inicialize o contexto do MuPDF. Isso carrega a DLL/SO.
    context = MuPDFContext.initialize();
    
    // 5. Use o contexto para abrir o documento.
    document = context.openDocument(inputFile);
    
    final stopwatch = Stopwatch()..start();
    
    // 6. Obtenha o número de páginas a partir do objeto do documento.
    final pageCount = document.pageCount;

    stopwatch.stop();
    
    print('\n--- RESULTADO ---');
    print('✅ Sucesso!');
    print('Arquivo: $inputFile');
    print('Número de Páginas: $pageCount');
    print('Tempo de execução: ${stopwatch.elapsedMilliseconds} ms');
    print('-----------------');

  } catch (e) {
    print('\n--- ERRO ---');
    print('❌ Falha ao processar o PDF com MuPDF.');
    print(e);
    print('------------');
    exit(1);
  } finally {
    // 7. SEMPRE libere os recursos na ordem inversa da criação.
    //    Isso é crucial para evitar vazamentos de memória.
    print('\nLimpando recursos...');
    document?.dispose();
    context?.dispose();
    print('Recursos liberados.');
  }
}