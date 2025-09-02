import 'package:typeson/typeson.dart';

void main() {
  // Create primitive JsonValues using extensions
  final JsonString s = 'hello'.json;
  final JsonNumber n = 42.json;
  final JsonBoolean b = true.json;

  // Serialize primitives to JSON strings
  print('String toJson: ${s.toJson()}'); // => "hello"
  print('Number toJson: ${n.toJson()}'); // => 42
  print('Boolean toJson: ${b.toJson()}'); // => true

  // Conversions
  print('Number as string: ${n.asString.value}'); // => "42"
  final maybeNum = '123'.json.maybeAsNumber?.value;
  final maybeBool = 'true'.json.maybeAsBoolean?.value;
  print('String maybeAsNumber: $maybeNum'); // => 123
  print('String maybeAsBoolean: $maybeBool'); // => true

  // Arithmetic and comparisons on JsonNumber
  final JsonNumber a = 10.json;
  final JsonNumber c = 5.json;
  final JsonNumber sum = a + c;
  print('10 + 5 = ${sum.value}'); // => 15
  print('10 > 5 = ${(a > c).value}'); // => true
}
