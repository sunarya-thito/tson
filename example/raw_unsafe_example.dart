import 'package:tson/tson.dart';

void main() {
  // Booleans and numbers parse lazily when .value is accessed
  final rawBool = JsonValue.unsafe({'ok': 'true'});
  final ok = rawBool.asObject['ok']!.asBoolean; // not parsed yet
  print('ok = ${ok.value}'); // true

  final rawNum = JsonValue.unsafe('3.14').asNumber; // not parsed yet
  print('num = ${rawNum.value}'); // 3.14

  // Lists/Maps preserved; elements lazily wrapped
  final rawList = JsonValue.unsafe([1, '2', true, null]).asArray;
  print('list[1] as int = ${rawList[1]!.asNumber.intValue}');

  final rawMap = JsonValue.unsafe({'a': '1', 2: false}).asObject;
  print('map["a"] as num = ${rawMap['a']!.asNumber.value}');
  print('map["2"] as bool = ${rawMap['2']!.asBoolean.value}');

  // Mutations store raw values back
  rawMap['x'] = JsonString('hello');
  print(rawMap.toJson());
}
