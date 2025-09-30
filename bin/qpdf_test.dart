// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:io';

import 'package:pdf_tools/src/qpdf.dart';

void _printUsage() {
  stderr.writeln('''
Uso:
  dart run bin/qpdf_test.dart --input=<arquivo.pdf> [--out=<saida.pdf>] [--dll=<qpdfXX.dll>] [--linearize]

Exemplos:
  dart run bin/qpdf_test.dart --input=test.pdf
  dart run bin/qpdf_test.dart --input=test.pdf --out=out.pdf --linearize
  dart run bin/qpdf_test.dart --input=test.pdf --dll=qpdf.dll
''');
}

Future<int> main(List<String> args) async {
  String? input;
  String? out;
  String dll = 'qpdf.dll';
  bool doLinearize = false;

  for (final a in args) {
    if (a.startsWith('--input=')) {
      input = a.substring(8);
    } else if (a.startsWith('--out='))
      out = a.substring(6);
    else if (a.startsWith('--dll='))
      dll = a.substring(6);
    else if (a == '--linearize') doLinearize = true;
  }

  if (input == null) {
    _printUsage();
    return 64; // EX_USAGE
  }

  try {
    stdout.writeln('> Carregando DLL: $dll');
    final q = Qpdf.open(dll);

    stdout.writeln('> getNumPages("$input") …');
    final pages = q.getNumPages(input);
    stdout.writeln('OK: páginas = $pages');

    if (doLinearize) {
      final output = out ?? _defaultOutName(input);
      stdout.writeln('> linearize("$input" → "$output") …');
      final rc = q.linearize(input, output, enable: true);
      stdout.writeln('OK: rc=$rc (arquivo gerado: $output)');
    } else {
      stdout.writeln('(pulei linearize — passe --linearize para testar)');
    }

    stdout.writeln('Tudo certo ✅');
    return 0;
  } on ArgumentError catch (e) {
    // Tipicamente falha ao abrir DLL ou símbolo ausente (127)
    _explainDllError(e, dll);
    return 127;
  } on QpdfException catch (e) {
    stderr.writeln('QpdfException: $e');
    return 1;
  } catch (e, st) {
    stderr.writeln('Falha inesperada: $e\n$st');
    return 1;
  }
}

String _defaultOutName(String input) {
  final dot = input.lastIndexOf('.');
  if (dot <= 0) return '${input}_linearized.pdf';
  return '${input.substring(0, dot)}_linearized${input.substring(dot)}';
}

void _explainDllError(Object e, String dll) {
  final msg = e.toString();
  stderr.writeln('Erro ao carregar "$dll" ou símbolos: $msg\n');

  // Ajuda rápida para Windows
  if (Platform.isWindows) {
    stderr.writeln('Dicas no Windows:');
    stderr.writeln(
        '  • Código 126: DLL não encontrada (ou dependência ausente).');
    stderr.writeln(
        '    - Coloque $dll e TODAS as dependências (zlib, libjpeg, libpng, liblzma, openssl etc.)');
    stderr.writeln(
        '      na mesma pasta do executável (ou adicione a pasta ao PATH).');
    stderr.writeln('  • Código 127: procedimento/símbolo não encontrado.');
    stderr.writeln(
        '    - Mismatch entre a versão da DLL e os headers usados no binding.');
    stderr.writeln(
        '    - Gere os bindings com a MESMA versão do qpdf-c.h da DLL que você está usando.');
  }
}
