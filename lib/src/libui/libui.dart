// lib/src/libui.dart

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'libui_bindings.dart';

// Global variable to access libui bindings.
late final LibUIBindings _ui;
// Global map to associate native pointers with Dart control objects.
final _controls = <int, Control>{};
final _controlsByAddr = <int, Control>{};
final _controlsByName = <String, Control>{};

/// Main class to initialize, run, and terminate the LibUI application.
class LibUI {
  static bool _running = false;
  static final List<void Function()> _pendingQueue = [];

  /// Initializes the LibUI library.
  static void init({String? libraryPath}) {
    String path;
    if (libraryPath != null) {
      path = libraryPath;
    } else {
      if (Platform.isWindows) {
        path = 'libui.dll';
      } else if (Platform.isLinux) {
        path = 'libui.so';
      } else if (Platform.isMacOS) {
        path = 'libui.dylib';
      } else {
        throw UnsupportedError('Platform not supported.');
      }
    }
    _ui = LibUIBindings(path);

    using((arena) {
      final options = arena<uiInitOptions>();
      options.ref.Size = sizeOf<uiInitOptions>();
      final error = _ui.uiInit(options);
      if (error != nullptr) {
        final errorMessage = error.toDartString();
        _ui.uiFreeInitError(error);
        throw Exception('Error initializing LibUI: $errorMessage');
      }
    });
  }

  /// Starts the main event loop of LibUI.
  static void runSync() {
    _ui.uiMain();
  }

  /// Inicia o loop de eventos cooperativo.
  /// Este método não bloqueia a thread do Dart, permitindo a execução de Futures.
  static Future<void> run() async {
    _running = true;
    while (_running) {
      // Processa um passo do loop de eventos da UI.
      // O argumento '1' significa que ele esperará por um evento.
      _ui.uiMainStep(1);
      // Cede controle para o event loop do Dart para processar microtasks.
      await Future.delayed(Duration.zero);
    }
  }

  /// Sinaliza para o loop de eventos terminar.
  static void quit() {
    _running = false; // Define a flag para sair do nosso loop `run()`
    _ui.uiQuit(); // Pede para a libui também encerrar
  }

  /// Enfileira uma função para ser executada na thread principal da UI.
  static void queueMain(void Function() f) {
    _pendingQueue.add(f);
    _ui.uiQueueMain(_queueMainPtr, nullptr);
  }

  ///  Exibe uma caixa de mensagem de informação.
  static void msgBox(Window parent, String title, String description) {
    using((arena) {
      final cTitle = title.toNativeUtf8(allocator: arena);
      final cDescription = description.toNativeUtf8(allocator: arena);
      _ui.uiMsgBox(parent.handle, cTitle, cDescription);
    });
  }

  ///  Exibe uma caixa de mensagem de erro.
  static void msgBoxError(Window parent, String title, String description) {
    using((arena) {
      final cTitle = title.toNativeUtf8(allocator: arena);
      final cDescription = description.toNativeUtf8(allocator: arena);
      _ui.uiMsgBoxError(parent.handle, cTitle, cDescription);
    });
  }
}

// --- Static Callback Implementation ---


// Agora, o trampolim processa a fila de funções pendentes.
final _queueMainPtr =
    Pointer.fromFunction<Void Function(Pointer<Void>)>(_queueMainTrampoline);

void _queueMainTrampoline(Pointer<Void> data) {
  if (LibUI._pendingQueue.isNotEmpty) {
    final fn = LibUI._pendingQueue.removeAt(0);
    fn();
  }
}

void _controlDestroy(Pointer<Void> handle) {
  final control = _controlsByAddr.remove(handle.address);
  if (control != null) {
    // Also remove from the named map if it exists.
    // This is a safer way to find and remove the entry.
    String? keyToRemove;
    _controlsByName.forEach((key, value) {
      if (value == control) {
        keyToRemove = key;
      }
    });
    if (keyToRemove != null) {
      _controlsByName.remove(keyToRemove);
    }
  }
  _ui.uiControlDestroy(handle);
}

// ignore: unused_element
final _controlFinalizer = NativeFinalizer(
    Pointer.fromFunction<Void Function(Pointer<Void>)>(_controlDestroy).cast());

/// Base class for all UI controls.
abstract class Control implements Finalizable {
  late final Pointer<Void> _handle;
  Pointer<Void> get handle => _handle;

  Control.fromHandle(this._handle) {
    _controls[_handle.address] = this;
    // Comentado para evitar conflito de desligamento.
    // descobriu um conflito sutil entre o NativeFinalizer do Dart e o desligamento da biblioteca nativa, às vezes,
    // é melhor confiar na própria biblioteca para gerenciar a limpeza final dos seus recursos.
    //_controlFinalizer.attach(this, _handle, detach: this);
  }

  void dispose() {
    //_controlFinalizer.detach(this);
    _ui.uiControlDestroy(_handle);
    _controls.remove(_handle.address);
  }

  void show() => _ui.uiControlShow(_handle);
  void hide() => _ui.uiControlHide(_handle);
  void enable() => _ui.uiControlEnable(_handle);
  void disable() => _ui.uiControlDisable(_handle);
  bool get enabled => _ui.uiControlEnabled(_handle) == 1;

  set enabled(bool value) {
    if (value) {
      enable();
    } else {
      disable();
    }
  }

  void register(String name) {
    _controlsByName[name] = this;
  }

  static T? find<T extends Control>(int address) {
    return _controls[address] as T?;
  }
}

// --- Static "Trampoline" Functions for Event Callbacks ---

// Trampoline for Window.onClosing
int _onClosingTrampoline(Pointer<Void> sender, Pointer<Void> data) {
  final window = _controls[data.address] as Window?;
  return window?._onClosingCallback?.call() ?? true ? 1 : 0;
}

// Trampoline for Button.onClicked
void _onClickedTrampoline(Pointer<Void> sender, Pointer<Void> data) {
  final button = _controls[data.address] as Button?;
  button?._onClickedCallback?.call();
}

/// Represents a main window.
class Window extends Control {
  // ignore: unused_field
  Control? _child;
  bool Function()? _onClosingCallback;

  Window(String title, int width, int height, {bool hasMenubar = false})
      : super.fromHandle(using((arena) {
          final cTitle = title.toNativeUtf8(allocator: arena);
          return _ui.uiNewWindow(cTitle, width, height, hasMenubar ? 1 : 0);
        }));

  String get title => _ui.uiWindowTitle(_handle).toDartString();
  set title(String value) => using((arena) {
        final cTitle = value.toNativeUtf8(allocator: arena);
        _ui.uiWindowSetTitle(_handle, cTitle);
      });

  set child(Control child) {
    _child = child;
    _ui.uiWindowSetChild(_handle, child._handle);
  }

  bool get margined => _ui.uiWindowMargined(_handle) == 1;
  set margined(bool value) => _ui.uiWindowSetMargined(_handle, value ? 1 : 0);

  set onClosing(bool Function() callback) {
    _onClosingCallback = callback;
    _ui.uiWindowOnClosing(
        _handle,
        Pointer.fromFunction<uiWindowOnClosing_callback>(
            _onClosingTrampoline, 0), // **CORRECTION APPLIED HERE**
        _handle // We pass the handle itself as 'data'
        );
  }

  ///  Abre um diálogo de seleção de arquivo.
  String? openFile() {
    final pathPtr = _ui.uiOpenFile(handle);
    if (pathPtr == nullptr) {
      return null;
    }
    final path = pathPtr.toDartString();
    _ui.uiFreeText(pathPtr);
    return path;
  }

  /// Abre um diálogo de seleção de pasta.
  String? openFolder() {
    final pathPtr = _ui.uiOpenFolder(handle);
    if (pathPtr == nullptr) {
      return null;
    }
    final path = pathPtr.toDartString();
    _ui.uiFreeText(pathPtr);
    return path;
  }
}

/// A clickable button control.
class Button extends Control {
  void Function()? _onClickedCallback;

  Button(String text)
      : super.fromHandle(using((arena) {
          final cText = text.toNativeUtf8(allocator: arena);
          return _ui.uiNewButton(cText);
        }));

  String get text => _ui.uiButtonText(_handle).toDartString();
  set text(String value) => using((arena) {
        final cText = value.toNativeUtf8(allocator: arena);
        _ui.uiButtonSetText(_handle, cText);
      });

  set onClicked(void Function() callback) {
    _onClickedCallback = callback;
    _ui.uiButtonOnClicked(
        _handle,
        Pointer.fromFunction<uiButtonOnClicked_callback>(_onClickedTrampoline),
        _handle // We pass the handle itself as 'data'
        );
  }
}

/// A text input field.
class Entry extends Control {
  Entry() : super.fromHandle(_ui.uiNewEntry());

  String get text => _ui.uiEntryText(_handle).toDartString();
  set text(String value) => using((arena) {
        final cText = value.toNativeUtf8(allocator: arena);
        _ui.uiEntrySetText(_handle, cText);
      });

  bool get readOnly => _ui.uiEntryReadOnly(_handle) == 1;
  set readOnly(bool value) => _ui.uiEntrySetReadOnly(_handle, value ? 1 : 0);
}

/// A static text label.
class Label extends Control {
  Label(String text)
      : super.fromHandle(using((arena) {
          final cText = text.toNativeUtf8(allocator: arena);
          return _ui.uiNewLabel(cText);
        }));

  String get text => _ui.uiLabelText(_handle).toDartString();
  set text(String value) => using((arena) {
        final cText = value.toNativeUtf8(allocator: arena);
        _ui.uiLabelSetText(_handle, cText);
      });
}

/// A container that organizes children.
abstract class Box extends Control {
  // ignore: unused_field
  final List<Control> _children = [];

  Box.fromHandle(super.handle) : super.fromHandle();

  void add(Control child, {bool stretchy = false}) {
    _children.add(child);
    _ui.uiBoxAppend(_handle, child._handle, stretchy ? 1 : 0);
  }

  bool get padded => _ui.uiBoxPadded(_handle) == 1;
  set padded(bool value) => _ui.uiBoxSetPadded(_handle, value ? 1 : 0);
}

/// A container that organizes children horizontally.
class HorizontalBox extends Box {
  HorizontalBox() : super.fromHandle(_ui.uiNewHorizontalBox());
}

/// A container that organizes children vertically.
class VerticalBox extends Box {
  VerticalBox() : super.fromHandle(_ui.uiNewVerticalBox());
}

/// Um widget de entrada numérica com botões de incremento/decremento.
class Spinbox extends Control {
  Spinbox(int min, int max) : super.fromHandle(_ui.uiNewSpinbox(min, max));

  int get value => _ui.uiSpinboxValue(handle);
  set value(int v) => _ui.uiSpinboxSetValue(handle, v);
}

/// Uma barra de progresso.
class ProgressBar extends Control {
  ProgressBar() : super.fromHandle(_ui.uiNewProgressBar());

  /// O valor da barra.
  /// De 0 a 100 para progresso normal.
  /// -1 para modo indeterminado (mostra uma animação).
  int get value => _ui.uiProgressBarValue(handle);
  set value(int v) => _ui.uiProgressBarSetValue(handle, v);
}

/// Um menu dropdown.
class Combobox extends Control {
  void Function()? _onSelectedCallback;

  Combobox() : super.fromHandle(_ui.uiNewCombobox());

  void append(String text) => using((arena) {
        _ui.uiComboboxAppend(handle, text.toNativeUtf8(allocator: arena));
      });

  int get selected => _ui.uiComboboxSelected(handle);
  set selected(int index) => _ui.uiComboboxSetSelected(handle, index);

  set onSelected(void Function() callback) {
    _onSelectedCallback = callback;
    _ui.uiComboboxOnSelected(
        handle,
        Pointer.fromFunction<Void Function(Pointer<Void>, Pointer<Void>)>(
            _onComboboxSelectedTrampoline),
        handle);
  }
}

// Adicione este trampolim estático junto com os outros
void _onComboboxSelectedTrampoline(Pointer<Void> sender, Pointer<Void> data) {
  final combo = _controls[data.address] as Combobox?;
  combo?._onSelectedCallback?.call();
}

/// Um container que organiza os filhos em uma grade.
class Grid extends Control {
  // ignore: unused_field
  final List<Control> _children = [];

  Grid() : super.fromHandle(_ui.uiNewGrid());

  bool get padded => _ui.uiGridPadded(handle) != 0; // CORREÇÃO AQUI
  set padded(bool value) =>
      _ui.uiGridSetPadded(handle, value ? 1 : 0); // CORREÇÃO AQUI

  void add(Control child, int left, int top, int xspan, int yspan, bool hexpand,
      Align halign, bool vexpand, Align valign) {
    _children.add(child);
    _ui.uiGridAppend(handle, child.handle, left, top, xspan, yspan,
        hexpand ? 1 : 0, halign.index, vexpand ? 1 : 0, valign.index);
  }
}

/// Enum para alinhamento em um Grid.
enum Align { Fill, Start, Center, End }
