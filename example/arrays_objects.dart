import 'package:typeson/typeson.dart';

void main() {
  // Build a JsonArray from a Dart List using the .json extension
  final JsonArray arr = [1, 'two', true, null].json;
  print('Array: ${arr.toJson()}'); // => [1,"two",true]

  // Build a JsonObject from a Dart Map using the .json extension
  final JsonObject obj = {
    'id': 1001,
    'name': 'Widget',
    'tags': ['a', 'b', 'c'],
    'stock': null, // gets dropped by default when building
  }.json;

  // Pretty build with default indent=2 and explicitNulls=false
  print('Object build default:\n${obj.build()}');

  // Access fields safely
  print('name: ${obj['name']!.asString.value}');
  print('first tag: ${obj['tags']!.asArray[0]!.asString.value}');

  // Mutate
  obj['price'] = 9.99.json;
  obj.updateAll((k, v) => v);
  print('Updated: ${obj.build()}');
}
