// // C:\MyDartProjects\pdf_tools\lib\src\gsx_bridge\gsx_bridge_extension.dart

// import 'dart:async';
// import 'dart:isolate';

// import 'gsx_bridge.dart';
// import 'gsx_bridge_bindings.dart';

// // Mensagens simples via Map<String, dynamic> para evitar tipos transfiráveis complexos.

// class _GsxIsolateInit {
//   final SendPort sendPort; // onde o worker manda progresso/resultado
//   final String inputPath;
//   final String outputPath;
//   final int dpi, jpegQuality, colorMode, firstPage, lastPage;
//   final String? preset;
//   _GsxIsolateInit({
//     required this.sendPort,
//     required this.inputPath,
//     required this.outputPath,
//     required this.dpi,
//     required this.jpegQuality,
//     required this.colorMode,
//     required this.firstPage,
//     required this.lastPage,
//     required this.preset,
//   });
// }

// // Mensagens emitidas pelo worker:
// // { "type":"progress", "page":int, "total":int, "line":String }
// // { "type":"done",     "rc":int }
// // { "type":"error",    "rc":int, "where":String }
// // { "type":"ctl",      "port":SendPort }  // porta de controle p/ cancel

// Future<void> _compressFileWorkerEntry(_GsxIsolateInit init) async {
//   final SendPort out = init.sendPort;

//   // Porta de controle para CANCELAR do main->worker
//   final ctrl = ReceivePort();
//   out.send({"type": "ctl", "port": ctrl.sendPort});

//   final bridge = GsxBridge.open(); // abre a DLL neste isolate
//   final token = GsxCancelToken();

//   // Ouve cancelamento
//   final ctrlSub = ctrl.listen((msg) {
//     if (msg is Map && msg["type"] == "cancel") {
//       token.cancel();
//     }
//   });

//   int rc = -1;
//   try {
//     rc = bridge.compressFileNativeSync(
//       inputPath: init.inputPath,
//       outputPath: init.outputPath,
//       dpi: init.dpi,
//       jpegQuality: init.jpegQuality,
//       preset: init.preset,
//       colorMode: init.colorMode,
//       firstPage: init.firstPage,
//       lastPage: init.lastPage,
//       cancel: token,
//       onProgress: (page, total, line) {
//         // Encaminha progresso ao main
//         out.send(
//             {"type": "progress", "page": page, "total": total, "line": line});
//       },
//     );
//     out.send({"type": "done", "rc": rc});
//   } on GsxException catch (e) {
//     out.send({"type": "error", "rc": e.code, "where": e.where});
//   } catch (e) {
//     out.send({"type": "error", "rc": -1, "where": e.toString()});
//   } finally {
//     await ctrlSub.cancel();
//     bridge.dispose();
//     token.dispose();
//   }
// }

// // ========= API PÚBLICA: "sync" rodando em ISOLATE =========

// class GsxIsolateTask {
//   final Isolate _isolate;
//   final SendPort _ctlPort;
//   GsxIsolateTask(this._isolate, this._ctlPort);

//   void cancel() {
//     _ctlPort.send({"type": "cancel"});
//   }

//   void kill({bool priorityImmediate = true}) {
//     _isolate.kill(
//         priority:
//             priorityImmediate ? Isolate.immediate : Isolate.beforeNextEvent);
//   }
// }

// extension GsxBridgeIsolate on GsxBridge {
//   Future<int> compressFileSyncInIsolate({
//     required String inputPath,
//     required String outputPath,
//     int dpi = 150,
//     int jpegQuality = 65,
//     String? preset,
//     int colorMode = GsxColorMode.color,
//     int firstPage = 0,
//     int lastPage = 0,
//     ProgressCallback? onProgress,
//     GsxCancelToken? cancel,
//   }) async {
//     final recv = ReceivePort();
//     final init = _GsxIsolateInit(
//       sendPort: recv.sendPort,
//       inputPath: inputPath,
//       outputPath: outputPath,
//       dpi: dpi,
//       jpegQuality: jpegQuality,
//       colorMode: colorMode,
//       firstPage: firstPage,
//       lastPage: lastPage,
//       preset: preset,
//     );

//     final isolate = await Isolate.spawn<_GsxIsolateInit>(
//       _compressFileWorkerEntry,
//       init,
//       debugName: 'GSX-Worker',
//     );

//     final ctlPortReady = Completer<SendPort>();
//     final rcCompleter = Completer<int>();

//     StreamSubscription? sub;
//     StreamSubscription? cancelWatch;

//     sub = recv.listen((msg) {
//       if (msg is! Map) return;
//       final type = msg["type"];

//       if (type == "ctl" && msg["port"] is SendPort) {
//         ctlPortReady.complete(msg["port"] as SendPort);
//         return;
//       }

//       if (type == "progress") {
//         if (onProgress != null) {
//           onProgress(
//             (msg["page"] as int?) ?? 0,
//             (msg["total"] as int?) ?? 0,
//             (msg["line"] as String?) ?? '',
//           );
//         }
//         return;
//       }

//       if (type == "done") {
//         if (!rcCompleter.isCompleted) {
//           rcCompleter.complete((msg["rc"] as int?) ?? 0);
//         }
//         return;
//       }

//       if (type == "error") {
//         if (!rcCompleter.isCompleted) {
//           rcCompleter.complete((msg["rc"] as int?) ?? -1);
//         }
//         return;
//       }
//     });

//     // Porta de controle pronta
//     final ctlPort = await ctlPortReady.future;

//     // Repassa cancel pendente (se houver)
//     if (cancel?.isCancelled == true) {
//       ctlPort.send({"type": "cancel"});
//     }

//     // Poll leve de cancelamento (opcional)
//     if (cancel != null) {
//       cancelWatch =
//           Stream.periodic(const Duration(milliseconds: 120)).listen((_) {
//         if (cancel.isCancelled) {
//           ctlPort.send({"type": "cancel"});
//         }
//       });
//     }

//     // Aguarda término sem polling de delay
//     final rc = await rcCompleter.future;

//     // Cleanup
//     await cancelWatch?.cancel();
//     await sub.cancel();
//     recv.close();
//     isolate.kill(priority: Isolate.immediate);

//     return rc;
//   }
// }
