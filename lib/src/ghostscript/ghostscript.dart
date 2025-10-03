// ignore_for_file: non_constant_identifier_names, constant_identifier_names, curly_braces_in_flow_control_structures, unused_element

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show Platform, Process, stderr, stdout;
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:pdf_tools/src/ghostscript/gs_stdio_bridge.dart';
import 'package:pdf_tools/src/win32/win32_api.dart';

import 'ghostscript_bindings.dart';

class GhostscriptException implements Exception {
  GhostscriptException(this.code, [this.message]);
  final int code;
  final String? message;
  @override
  String toString() =>
      'GhostscriptException(code=$code${message == null ? '' : ', msg=$message'})';
}

// Adicione esta classe para passar os dados para o novo isolate
class _GsRunnerArgs {
  final SendPort sendPort;
  final Pointer<Void> instance;
  final int argc;
  final Pointer<Pointer<Int8>> argv;

  _GsRunnerArgs(this.sendPort, this.instance, this.argc, this.argv);
}

// Esta será a função executada no novo isolate
void _ghostscriptRunner(_GsRunnerArgs args) {
  // Carregue os bindings novamente DENTRO do isolate
  final gs = Ghostscript.open();

  // Faça a chamada bloqueante
  final rInit =
      gs._bindings.gsapi_init_with_args(args.instance, args.argc, args.argv);
  final rExit = gs._bindings.gsapi_exit(args.instance);

  // Envie o resultado de volta para o isolate principal
  final result = rInit < 0 ? rInit : (rExit < 0 ? rExit : rInit);
  args.sendPort.send(result);
}

class Ghostscript {
  Ghostscript(this._bindings);

  Future<int> runGsProcess(
      List<String> args, void Function(String) onLine) async {
    // Use gswin64c.exe no Windows; gs no Linux/macOS
    final exe = Platform.isWindows ? 'gswin64c.exe' : 'gs';
    final p = await Process.start(exe, args, runInShell: true);

    // stdout
    p.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(onLine);

    // stderr (Ghostscript muitas vezes imprime em stderr)
    p.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(onLine);

    return await p.exitCode;
  }

  Future<int> runWithProgressViaBridge(
    List<String> args,
    void Function(String line) onLine, {
    bool throwOnError = true,
    void Function(Isolate)? onIsolateSpawned,
  }) async {
    try {
      stdout.writeln('[GS] runWithProgressViaBridge: args=${args.join(' ')}');
    } catch (_) {}

    final fullArgs = ['gs', ...args];
    final argc = fullArgs.length;
    final instancePtr = calloc<Pointer<Void>>();
    Pointer<Void>? instance;
    final userData = calloc<Int8>(1).cast<Void>();
    final argv = calloc<Pointer<Int8>>(argc);
    final allocated = <Pointer<Int8>>[];
    final hReadPtr = calloc<IntPtr>(), hWritePtr = calloc<IntPtr>();
    final bridge = GsStdioBridge.open();
    int hRead = 0, hWrite = 0;
    final buf = calloc<Uint8>(4096);
    final nPtr = calloc<Uint32>();
    final availPtr = calloc<Uint32>();
    final carry = StringBuffer();
    final lastEmit = Stopwatch()..start();
    const partialEmitEveryMs = 250;
    const partialMax = 4096;

    // ---- Funções locais 'emitLines' e 'drainPipeOnce' (sem alterações) ----
    void emitLines(String chunk) {
      carry.write(chunk);
      final s = carry.toString();
      final parts = s.split('\n');
      for (var i = 0; i < parts.length - 1; i++) {
        var line = parts[i];
        if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
        try {
          onLine(line);
        } catch (_) {}
      }
      carry
        ..clear()
        ..write(parts.last);
    }

    Future<void> drainPipeOnce() async {
      if (PeekNamedPipe(hRead, nullptr, 0, nullptr, availPtr, nullptr) == 0) {
        return;
      }
      final available = availPtr.value;
      if (available == 0) {
        if (carry.isNotEmpty &&
            (lastEmit.elapsedMilliseconds >= partialEmitEveryMs ||
                carry.length >= partialMax)) {
          final partial = carry.toString();
          carry.clear();
          try {
            onLine(partial);
          } catch (_) {}
          lastEmit.reset();
        }
        return;
      }
      var remaining = available;
      while (remaining > 0) {
        if (ReadFile(hRead, buf.cast(), 4096, nPtr, 0) == 0) break;
        final n = nPtr.value;
        if (n == 0) break;
        final chunk = utf8.decode(buf.asTypedList(n), allowMalformed: true);
        emitLines(chunk);
        remaining -= n;
        lastEmit.reset();
      }
    }

    try {
      // 1) cria instância
      final rNew = _bindings.gsapi_new_instance(instancePtr, userData);
      stdout.writeln(
          '[GS] gsapi_new_instance -> $rNew  inst=${instancePtr.value.address}');
      if (rNew < 0) return _maybeThrow(rNew, throwOnError);
      instance = instancePtr.value;

      // 2) UTF-8
      final rEnc =
          _bindings.gsapi_set_arg_encoding(instance, GS_ARG_ENCODING_UTF8);
      stdout.writeln('[GS] gsapi_set_arg_encoding(UTF8) -> $rEnc');
      if (rEnc < 0) return _maybeThrow(rEnc, throwOnError);

      // 3) pipe anônimo
      final okPipe = CreatePipe(hReadPtr, hWritePtr, 0, 0);
      hRead = hReadPtr.value;
      hWrite = hWritePtr.value;
      stdout
          .writeln('[GS] CreatePipe -> $okPipe  hRead=$hRead  hWrite=$hWrite');
      if (okPipe == 0) {
        throw Exception('CreatePipe falhou (GLE=${GetLastError()})');
      }

      // 4) conecta stdout/stderr do GS ao pipe (lado de escrita)
      final rAttach = bridge.attach(instance.address, userData.address, hWrite);
      stdout.writeln(
          '[GS] GS_AttachStdIO(inst=${instance.address}, user=${userData.address}, hW=$hWrite) -> $rAttach');
      if (rAttach < 0) throw Exception('GS_AttachStdIO falhou ($rAttach)');

      // 5) argv
      for (var i = 0; i < argc; i++) {
        final p = fullArgs[i].toNativeUtf8();
        final c = p.cast<Int8>();
        allocated.add(c);
        argv[i] = c;
      }
      stdout.writeln('[GS] argv montado (argc=$argc).');

      // ALTERADO: Passos 6 e 7 agora usam um Isolate
      // 6) Inicia GS em um Isolate separado para não bloquear o polling
      final completer = Completer<int>();
      final receivePort = ReceivePort();

      final runnerArgs =
          _GsRunnerArgs(receivePort.sendPort, instance, argc, argv);

      final iso = await Isolate.spawn(_ghostscriptRunner, runnerArgs);

      //  Chama o callback para que o chamador saiba qual isolate foi criado
      onIsolateSpawned?.call(iso);

      receivePort.listen((message) {
        if (message is int) {
          if (!completer.isCompleted) {
            completer.complete(message);
          }
          receivePort.close();
        }
      });

     
      // O loop de polling agora tem uma verificação de cancelamento implícita
      // através do 'completer.future' que pode ser interrompido por uma exceção.
      while (!completer.isCompleted) {
        await drainPipeOnce();
        await Future.delayed(const Duration(milliseconds: 1000));
        print('while (!completer.isCompleted) drainPipeOnce');
      }

      // ---- Passos 8 e 9: Finalização (sem alterações) ----
      // 8) terminou: fecha escrita para encerrar o Read do outro lado
      if (hWrite != 0) {
        CloseHandle(hWrite);
        hWrite = 0;
      }

      // 9) dreno final de qualquer sobra pendente
      await drainPipeOnce();
      if (carry.isNotEmpty) {
        final last = carry.toString();
        carry.clear();
        try {
          onLine(last);
        } catch (_) {}
      }

      // Aguarda o resultado final do isolate
      final code = await completer.future;
      iso.kill(); // Garante que o isolate seja encerrado

      if (code < 0) return _maybeThrow(code, throwOnError);
      return code;
    } catch (e, s) {
      stderr.writeln('[GS][ERRO] $e\n$s');
      rethrow;
    } finally {
      // ---- Bloco finally para limpeza de recursos (sem alterações) ----
      try {
        bridge.detach(userData.address);
      } catch (_) {}
      calloc.free(userData);

      if (hWrite != 0) CloseHandle(hWrite);
      if (hRead != 0) CloseHandle(hRead);
      calloc.free(hReadPtr);
      calloc.free(hWritePtr);

      calloc.free(availPtr);
      calloc.free(buf);
      calloc.free(nPtr);

      for (final p in allocated) calloc.free(p);
      calloc.free(argv);

      final inst = instance;
      if (inst != null) _bindings.gsapi_delete_instance(inst);
      calloc.free(instancePtr);
    }
  }

  /// Carrega a biblioteca Ghostscript para a plataforma atual.
  ///
  /// Opcionalmente, um caminho [libraryPath] pode ser fornecido para carregar
  /// uma biblioteca de um local específico.
  factory Ghostscript.open([String? libraryPath]) {
    final path = libraryPath ?? _getLibraryPath();
    return Ghostscript(GhostscriptBindings.open(path));
  }

  /// Retorna o nome do arquivo da biblioteca Ghostscript para o SO atual.
  static String _getLibraryPath() {
    if (Platform.isWindows) {
      return 'gsdll64.dll';
    } else if (Platform.isLinux) {
      return 'libgs.so';
    } else if (Platform.isMacOS) {
      // Bônus: adicionando suporte para macOS também
      return 'libgs.dylib';
    } else {
      throw UnsupportedError(
          'Sistema operacional não suportado: ${Platform.operatingSystem}');
    }
  }

  final GhostscriptBindings _bindings;

  int run(List<String> args, {bool throwOnError = true}) {
    final fullArgs = ['gs', ...args];
    final argc = fullArgs.length;

    final instancePtr = calloc<Pointer<Void>>();
    Pointer<Void>? instance;

    final argv = calloc<Pointer<Int8>>(argc);

    final allocated = <Pointer<Int8>>[];

    try {
      final rNew = _bindings.gsapi_new_instance(instancePtr, nullptr);
      if (rNew < 0) return _maybeThrow(rNew, throwOnError);
      instance = instancePtr.value;

      final rEnc =
          _bindings.gsapi_set_arg_encoding(instance, GS_ARG_ENCODING_UTF8);
      if (rEnc < 0) return _maybeThrow(rEnc, throwOnError);

      for (var i = 0; i < argc; i++) {
        final p = fullArgs[i].toNativeUtf8();
        final c = p.cast<Int8>();
        allocated.add(c);
        argv[i] = c;
      }

      final rInit = _bindings.gsapi_init_with_args(instance, argc, argv);
      final rExit = _bindings.gsapi_exit(instance);

      if (rInit < 0) return _maybeThrow(rInit, throwOnError);
      if (rExit < 0) return _maybeThrow(rExit, throwOnError);
      return rInit;
    } finally {
      for (final p in allocated) {
        calloc.free(p);
      }
      calloc.free(argv);
      final inst = instance;
      if (inst != null) _bindings.gsapi_delete_instance(inst);
      calloc.free(instancePtr);
    }
  }

  
  static final Map<int, _LineEmitter> _emitters = {};

  static int _stdinCB(Pointer<Void> handle, Pointer<Int8> buf, int size) {
    return 0;
  }

  static int _stdoutCB(Pointer<Void> handle, Pointer<Int8> data, int len) {
    if (len <= 0) return 0;
    // final em = _emitters[handle.address];
    // if (em != null) {
    //   final bytes = data.cast<Uint8>().asTypedList(len);
    //   final chunk = utf8.decode(bytes, allowMalformed: true);
    //   em.add(chunk);
    // }
    return len;
  }

  static int _stderrCB(Pointer<Void> handle, Pointer<Int8> data, int len) {
    return _stdoutCB(handle, data, len);
  }

  int runWithProgress(
    List<String> args,
    void Function(String line) onLine, {
    bool throwOnError = true,
  }) {
    final fullArgs = ['gs', ...args];
    final argc = fullArgs.length;

    final instancePtr = calloc<Pointer<Void>>();
    Pointer<Void>? instance;
    final argv = calloc<Pointer<Int8>>(argc);
    final allocated = <Pointer<Int8>>[];

    // handle que passamos como user_data para identificar o emissor
    final handle = calloc<Int8>(1).cast<Void>();
    var rInit = 0;
    try {
      // cria instância
      final rNew = _bindings.gsapi_new_instance(instancePtr, handle);
      if (rNew < 0) return _maybeThrow(rNew, throwOnError);
      instance = instancePtr.value;

      // codificação UTF-8
      final rEnc =
          _bindings.gsapi_set_arg_encoding(instance, GS_ARG_ENCODING_UTF8);
      if (rEnc < 0) return _maybeThrow(rEnc, throwOnError);

      // if(args.contains('-dNumRenderingThreads=1') == false){
      //   throw Exception('No dart é obrigartorio se single Thread por conta do callback');
      // }

      // TODO registra callbacks usando Pointer.fromFunction se for chamado de outra Thread vai dar erro
      // usar -dNumRenderingThreads=1
      //NOTE: o segundo argumento é POSICIONAL (exceptionalReturn)

      //final nc1 =NativeCallable<gs_stdin_cb_native>.listener(_stdinCB);

      // final rStdio = _bindings.gsapi_set_stdio(
      //   instance,
      //   Pointer.fromFunction<gs_stdin_cb_native>(_stdinCB, 0),
      //   Pointer.fromFunction<gs_stdout_cb_native>(_stdoutCB, 0),
      //   Pointer.fromFunction<gs_stderr_cb_native>(_stderrCB, 0),
      // );
      // if (rStdio < 0) return _maybeThrow(rStdio, throwOnError);

      // emissor para este handle
      _emitters[handle.address] = _LineEmitter(onLine);

      // argv
      for (var i = 0; i < argc; i++) {
        final p = fullArgs[i].toNativeUtf8();
        final c = p.cast<Int8>();
        allocated.add(c);
        argv[i] = c;
      }

      // executa
      rInit = _bindings.gsapi_init_with_args(instance, argc, argv);
      final rExit = _bindings.gsapi_exit(instance);

      // flush final
      _emitters[handle.address]?.close();

      if (rInit < 0) return _maybeThrow(rInit, throwOnError);
      if (rExit < 0) return _maybeThrow(rExit, throwOnError);
      return rInit;
    } catch (e, s) {
      print('runWithProgress $e | s $s');
      return rInit;
    } finally {
      _emitters.remove(handle.address);
      calloc.free(handle.cast<Int8>());

      for (final p in allocated) calloc.free(p);
      calloc.free(argv);

      final inst = instance;
      if (inst != null) _bindings.gsapi_delete_instance(inst);
      calloc.free(instancePtr);
    }
  }

  int _maybeThrow(int code, bool throwOnError) {
    if (throwOnError && code < 0) throw GhostscriptException(code);
    return code;
  }
}

class _LineEmitter {
  _LineEmitter(this.onLine);
  final void Function(String) onLine;
  String _buf = '';
  void add(String chunk) {
    _buf += chunk;
    while (true) {
      final i = _buf.indexOf('\n');
      if (i < 0) break;
      var line = _buf.substring(0, i);
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      onLine(line);
      _buf = _buf.substring(i + 1);
    }
  }

  void close() {
    if (_buf.isNotEmpty) {
      onLine(_buf);
      _buf = '';
    }
  }
}
