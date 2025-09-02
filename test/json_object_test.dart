import 'package:test/test.dart';
import 'package:typeson/typeson.dart';

void main() {
  group('JsonObject', () {
    test('wrap and key normalization', () {
      final obj = {1: 'a', 'b': 2, null: 'ignored'}.json;
      expect(obj.containsKey('1'), isTrue);
      expect(obj['1']!.asString.value, 'a');
      expect(obj['b']!.asNumber.value, 2);
      expect(obj['null'], isNull);
    });

    test('mutations and queries', () {
      final o = JsonObject({});
      o['x'] = 1.json;
      o.putAll({'y': 2.json});
      o.putAllEntries([MapEntry('z', 3.json)]);
      expect(o.keys.toSet(), {'x', 'y', 'z'});
      expect(o.values.map((e) => e!.value), [1, 2, 3]);
      expect(o.putIfAbsent('y', () => 9.json)!.asNumber.value, 2);
      o.update('z', (v) => 4.json);
      o.updateAll((k, v) => v);
      expect(o.remove('x')!.asNumber.value, 1);
      o.removeWhere((k, v) => k == 'y');
      expect(o.containsKey('y'), isFalse);
      expect(o.containsValue(4.json), isTrue);
      o.clear();
      expect(o.entries, isEmpty);
    });

    test('[] non-string key returns null', () {
      final o = JsonObject({});
      expect(o[1], isNull);
    });

    test('toEncodeable without registry', () {
      final o = JsonObject({
        'a': 1.json,
        'b': JsonArray([2.json]),
      });
      expect(o.toEncodeable(), {
        'a': 1,
        'b': [2],
      });
    });
  });
}
