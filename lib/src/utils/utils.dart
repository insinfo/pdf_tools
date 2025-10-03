import 'dart:ffi';

/// helper function to convert a C-style array to a Dart string
String convertCArrayToString(Array<Char> cArray, int len) {
  final dartString = <int>[];
  for (var i = 0; i < len; i++) {
    final char = cArray[i];
    if (char == 0) break;
    dartString.add(char);
  }
  return String.fromCharCodes(dartString);
}
