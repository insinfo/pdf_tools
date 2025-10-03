// bin/mini_test.dart
import 'package:pdf_tools/src/nuklear/nuklear_mini.dart';

void main() async {
  final app = NuklearMini(title: 'Mini Nuklear Test');
  await app.run();
}
