import 'package:test/test.dart';
import 'package:typeson/typeson.dart';

void main() {
  group('JsonArray', () {
    test('wrap and access', () {
      final arr = [1, 'two', null, true].json;
      expect(arr.length, 4);
      expect(arr[0]!.asNumber.value, 1);
      expect(arr[1]!.asString.value, 'two');
      expect(arr[2], isNull);
      expect(arr[3]!.asBoolean.value, isTrue);
    });

    test('mutation ops', () {
      final a = JsonArray([]);
      a.add(1.json);
      a.addAll(['x'.json, null]);
      expect(a.containsElement('x'.json), isTrue);
      expect(a.remove('x'.json), isTrue);
      a.insert(1, 2.json);
      a.insertAll(2, [3.json, 4.json]);
      // Remove the remaining null for a clean asMap assertion
      a.removeWhere((e) => e == null);
      expect(a.asMap(), equals({0: 1.json, 1: 2.json, 2: 3.json, 3: 4.json}));
      expect(a.removeAt(0)!.asNumber.value, 1);
      a.removeRange(0, 1); // remove index 0 only
      a.removeWhere((e) => e?.asNumber.value == 4);
      expect(a.value.map((e) => e?.value).toList(), [3]);
      a.clear();
      expect(a.length, 0);
    });

    test('toEncodeable', () {
      final a = JsonArray([
        1.json,
        null,
        JsonArray([2.json]),
      ]);
      expect(a.toEncodeable(), [
        1,
        null,
        [2],
      ]);
    });
  });
}
