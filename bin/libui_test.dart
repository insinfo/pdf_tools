// example/main.dart



import 'package:pdf_tools/src/libui/libui.dart';

void main() {
  // 1. Inicializa a biblioteca
  LibUI.init();

  // 2. Cria os controles
  final window = Window('Olá, LibUI!', 400, 200);
  final box = VerticalBox();
  final greetingLabel = Label('Por favor, digite seu nome abaixo.');
  final nameEntry = Entry();
  final actionButton = Button('Dizer Olá');
  final resultLabel = Label('');

  // 3. Define o comportamento
  window.onClosing = () {
    LibUI.quit();
    return true;
  };

  actionButton.onClicked = () {
    final name = nameEntry.text;
    if (name.trim().isEmpty) {
      resultLabel.text = 'Por favor, insira um nome!';
    } else {
      resultLabel.text = 'Olá, $name!';
    }
  };

  // 4. Monta a árvore de controles
  box.padded = true;
  box.add(greetingLabel);
  box.add(nameEntry);
  box.add(actionButton);
  box.add(resultLabel);

  window.child = box;
  window.show();

  // 5. Inicia o loop de eventos
  LibUI.run();
}