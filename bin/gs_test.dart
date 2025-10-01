// bin/main.dart
import 'dart:io';
import 'package:pdf_tools/src/ghostscript.dart';

void main() async {
  // 1) caminho da DLL (ajuste se estiver em outra pasta/versão)
  final gs = Ghostscript.open();

  // 2) caminhos de entrada/saída (use raw strings para UNC no Windows)
  const input = r'C:\MyDartProjects\pdf_tools\pdfs\input\14_34074_Vol 5.pdf';
  const outCompressed =
      r'C:\MyDartProjects\pdf_tools\pdfs\output\14_34074_Vol 5_limpo_compressed.pdf';

  print('Iniciando Ghostscript...');
  final rc = exportarIntervalo(gs,
      input: input, output: outCompressed, firstPage: 1, lastPage: 10);
  print('Ghostscript finalizado. rc=$rc');

  // Convenção: rc >= 0 sucesso; rc < 0 erro
  if (rc < 0) {
    stderr.writeln('Falha ao processar PDF (código $rc).');
    exitCode = 1;
    return;
  }

  print('PDF gerado com sucesso: $outCompressed');
}

int exportarIntervalo(
  Ghostscript gs, {
  required String input,
  required String output,
  int? firstPage,
  int? lastPage,
}) {
  final args = <String>[
    '-dSAFER',
    '-dBATCH',
    '-dNOPAUSE',
    '-sDEVICE=pdfwrite',
    '-o', output,
    if (firstPage != null) '-dFirstPage=$firstPage',
    if (lastPage != null) '-dLastPage=$lastPage',
    // suas flags de compressão
    '-dCompatibilityLevel=1.5',
    '-dDetectDuplicateImages=true',
    '-dCompressFonts=true',
    '-dSubsetFonts=true',
    '-dDownsampleColorImages=true',
    '-dColorImageDownsampleType=/Average',
    '-dColorImageResolution=150',
    '-dDownsampleGrayImages=true',
    '-dGrayImageDownsampleType=/Average',
    '-dGrayImageResolution=150',
    '-dDownsampleMonoImages=true',
    '-dMonoImageDownsampleType=/Subsample',
    '-dMonoImageResolution=300',
    '-dEncodeColorImages=true',
    '-dEncodeGrayImages=true',
    '-dEncodeMonoImages=true',
    '-dAutoRotatePages=/None',
    input,
  ];
  return gs.run(args);
}
