// dart run bin/binarize_pdf_test.dart --in="C:\MyDartProjects\pdf_tools\pdfs\input\14_34074_Vol 5.pdf"  --outdir="C:\MyDartProjects\pdf_tools\pdfs\output\binarize_test"  --dpi=150 --range=1-10 --pngmono --repack

//
// Teste isolado de binarização (raster) + geração de PDF 1-bpp direto do PDF.
// Evita curingão *.tif (Windows) e evita "repack" com TIFF (GS não aceita TIFF como entrada do pdfwrite).

// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pdf_tools/src/gs_stdio_/ghostscript.dart';

void main(List<String> args) async {
  final o = _parseArgs(args);

  if (o.input == null) {
    stderr.writeln('Uso: dart run bin/binarize_pdf_test.dart '
        '--in=<arquivo.pdf> [--outdir=<pasta>] [--dpi=300] [--range=A-B] '
        '[--pngmono] [--pdf1bpp]');
    exit(64);
  }

  final input = o.input!;
  final outDir = Directory(o.outDir ?? p.join(Directory.current.path, 'out'));
  final dpi = o.dpi ?? 300;
  final (firstS, lastS) = _parseRange(o.range);
  final first = firstS == null ? null : int.parse(firstS);
  final last = lastS == null ? null : int.parse(lastS);

  if (!File(input).existsSync()) {
    stderr.writeln('Arquivo de entrada não encontrado: $input');
    exit(1);
  }
  outDir.createSync(recursive: true);

  final gs = Ghostscript.open();

  // ---------------------------------------------------------------------------
  // 1) Raster binário de referência (TIFF G4) — 1-bpp CCITT Group 4
  //    Dicas: usar DPI 200–300; adicionar downscale antes do threshold reduz moiré.
  // ---------------------------------------------------------------------------
  final tiffPattern = p.join(outDir.path, 'page_%03d.tif');
  final argsTiff = <String>[
    '-dSAFER', '-dBATCH', '-dNOPAUSE',
    '-sDEVICE=tiffg4',
    '-r$dpi',
    // Ajuda contra moiré/retícula quando existe: downscale prévio
    // (nem toda versão expõe DownScaleFactor para todos devices; se ignorar, OK)
    '-dDownScaleFactor=2',
    // Em alguns builds recentes, MinFeatureSize ajuda a “matar” pontinhos isolados
    // (se for desconhecida, GS ignora)
    '-dMinFeatureSize=2',
    '-o', tiffPattern,
    if (first != null) '-dFirstPage=$first',
    if (last != null) '-dLastPage=$last',
    input,
  ];
  _printArgs('gs (tiffg4)', argsTiff);

  final rcTiff =
      gs.runWithProgress(argsTiff, (ln) => stdout.writeln('GS> $ln'));
  if (rcTiff < 0) {
    stderr.writeln('Falha no tiffg4 (rc=$rcTiff).');
    exit(1);
  }
  print('OK: TIFF G4 gerados em ${outDir.path}');

  // PNG mono (opcional, só pra visual comparativa)
  if (o.pngmono) {
    final pngPattern = p.join(outDir.path, 'page_%03d.png');
    final argsPng = <String>[
      '-dSAFER', '-dBATCH', '-dNOPAUSE',
      '-sDEVICE=pngmono',
      '-r$dpi',
      // mesmas heurísticas anti-moiré
      '-dDownScaleFactor=2',
      '-dMinFeatureSize=2',
      '-o', pngPattern,
      if (first != null) '-dFirstPage=$first',
      if (last != null) '-dLastPage=$last',
      input,
    ];
    _printArgs('gs (pngmono)', argsPng);
    final rcPng =
        gs.runWithProgress(argsPng, (ln) => stdout.writeln('GS> $ln'));
    if (rcPng < 0) {
      stderr.writeln('Aviso: falha no pngmono (rc=$rcPng).');
    } else {
      print('OK: PNGs 1-bpp gerados em ${outDir.path}');
    }
  }

  // ---------------------------------------------------------------------------
  // 2) PDF 1-bpp direto (sem “repack” via TIFF) — esse é o jeito certo com GS.
  //    Força conversão de imagens para 1-bpp CCITT G4 dentro do PDF final.
  // ---------------------------------------------------------------------------
  if (o.pdf1bpp) {
    final outPdf = p.join(outDir.path, _pdfName(input, firstS, lastS));
    final argsPdf1bpp = <String>[
      '-dSAFER', '-dBATCH', '-dNOPAUSE',
      '-sDEVICE=pdfwrite',
      '-o', outPdf,

      // Não rotaciona automaticamente
      '-dAutoRotatePages=/None',

      // Mantém o espaço de cor simples (evita pegadinhas de ICC)
      '-sProcessColorModel=DeviceGray',
      '-sColorConversionStrategy=Gray',
      '-dOverrideICC=true',

      // Downsample das imagens (antes do threshold)
      '-dDownsampleColorImages=true',
      '-dColorImageDownsampleType=/Average',
      '-dColorImageResolution=$dpi',
      '-dDownsampleGrayImages=true',
      '-dGrayImageDownsampleType=/Average',
      '-dGrayImageResolution=$dpi',
      // mono costuma ficar 2x o DPI alvo para manter traço
      '-dDownsampleMonoImages=true',
      '-dMonoImageDownsampleType=/Subsample',
      '-dMonoImageResolution=${dpi * 2}',

      // Converte imagens para 1-bpp e usa CCITT G4 (muito compacto)
      '-dConvertImagesTo1bpp=true',
      '-dEncodeMonoImages=true',
      '-sMonoImageFilter=/CCITTFaxEncode',

      // Heurísticas anti-moiré / sujeirinha
      '-dDownScaleFactor=2',
      '-dMinFeatureSize=2',

      if (first != null) '-dFirstPage=$first',
      if (last != null) '-dLastPage=$last',
      input,
    ];

    _printArgs('gs (pdfwrite → PDF 1-bpp)', argsPdf1bpp);
    final rcPdf =
        gs.runWithProgress(argsPdf1bpp, (ln) => stdout.writeln('GS> $ln'));
    if (rcPdf < 0) {
      stderr.writeln('Falha ao gerar PDF 1-bpp (rc=$rcPdf).');
    } else {
      final inSize = File(input).lengthSync();
      final outSize = File(outPdf).lengthSync();
      final reducao = inSize > 0 ? (1 - outSize / inSize) * 100 : 0;
      print('OK: PDF 1-bpp gerado: $outPdf');
      print('Original: ${(inSize / 1024 / 1024).toStringAsFixed(2)} MB  |  '
          'Novo: ${(outSize / 1024 / 1024).toStringAsFixed(2)} MB  |  '
          'Redução: ${reducao.toStringAsFixed(1)}%');
    }
  }

  print('\nConcluído ✅');
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

void _printArgs(String title, List<String> a) {
  print('[$title] ${a.join(' ')}');
}

(String?, String?) _parseRange(String? s) {
  if (s == null || s.trim().isEmpty) return (null, null);
  final m = RegExp(r'^\s*(\d+)\s*-\s*(\d+)\s*$').firstMatch(s);
  if (m == null) return (null, null);
  return (m.group(1), m.group(2));
}

String _pdfName(String input, String? f, String? l) {
  final base = p.basenameWithoutExtension(input);
  final tail =
      (f != null || l != null) ? '_bilevel_${f ?? ""}-${l ?? ""}' : '_bilevel';
  return '$base$tail.pdf';
}

class _Opts {
  String? input, outDir, range;
  int? dpi;
  bool pngmono = false, pdf1bpp = false;
}

_Opts _parseArgs(List<String> a) {
  final o = _Opts();
  for (final s in a) {
    if (s.startsWith('--in=')) {
      o.input = s.substring(5);
    } else if (s.startsWith('--outdir='))
      o.outDir = s.substring(9);
    else if (s.startsWith('--dpi='))
      o.dpi = int.tryParse(s.substring(6));
    else if (s.startsWith('--range='))
      o.range = s.substring(8);
    else if (s == '--pngmono')
      o.pngmono = true;
    else if (s == '--pdf1bpp') o.pdf1bpp = true;
  }
  return o;
}
