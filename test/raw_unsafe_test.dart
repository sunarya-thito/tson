import 'package:test/test.dart';
import 'package:typeson/typeson.dart';

void main() {
  group('JsonValue.unsafe (raw)', () {
    test('lazy parsing for numbers and booleans', () {
      final n = JsonValue.unsafe('10').asNumber; // no parse yet
      expect(n.value, 10);

      final b = JsonValue.unsafe('false').asBoolean; // no parse yet
      expect(b.value, isFalse);

      final badNum = JsonValue.unsafe('abc').asNumber;
      expect(() => badNum.value, throwsFormatException);

      final badBool = JsonValue.unsafe('notbool').asBoolean;
      expect(() => badBool.value, throwsFormatException);
    });

    test('raw array wraps lazily and preserves nulls', () {
      final arr = JsonValue.unsafe([1, '2', true, null]).asArray;
      expect(arr[0]!.asNumber.intValue, 1);
      expect(arr[1]!.asNumber.intValue, 2);
      expect(arr[2]!.asBoolean.value, isTrue);
      expect(arr[3], isNull);

      // Mutations store raw types back
      arr.add(JsonString('5'));
      expect(arr[4]!.asString.value, '5');

      // containsElement unwraps JsonValue to raw for comparison
      expect(arr.containsElement(JsonNumber(1)), isTrue);
      expect(arr.containsElement(JsonString('missing')), isFalse);
    });

    test('raw object stringifies keys and lazy-wraps values', () {
      final obj = JsonValue.unsafe({'a': '1', 2: false, 'n': 'abc'}).asObject;

      // Non-string key 2 becomes '2'
      expect(obj.containsKey('2'), isTrue);
      expect(obj['a']!.asNumber.value, 1);
      expect(obj['2']!.asBoolean.value, isFalse);

      // putIfAbsent stores raw value
      obj.putIfAbsent('x', () => JsonBoolean(true));
      expect(obj['x']!.asBoolean.value, isTrue);

      // update existing with transformation
      obj.update('a', (v) => JsonNumber(v!.asNumber.value + 1));
      expect(obj['a']!.asNumber.value, 2);

      // toJson uses raw encodeable structures
      final json = obj.toJson();
      expect(json, contains('"2":false'));
      expect(json, contains('"a":2'));
      expect(json, contains('"x":true'));

      // Accessing invalid numeric value triggers parse failure
      expect(() => obj['n']!.asNumber.value, throwsFormatException);
    });

    test('failing parse via access and equality triggers', () {
      // Direct access triggers failure
      final badNum = JsonValue.unsafe('abc').asNumber;
      expect(() => badNum.value, throwsFormatException);

      final badBool = JsonValue.unsafe('notbool').asBoolean;
      expect(() => badBool.value, throwsFormatException);

      // Equality should also trigger lazy parsing and thus throw
      expect(() => (JsonValue.unsafe('abc').asNumber == 0.json),
          throwsFormatException);
      expect(() => (JsonValue.unsafe('notbool').asBoolean == false.json),
          throwsFormatException);

      // In arrays: invalid element fails when accessed
      final arrBad = JsonValue.unsafe(['2x']).asArray;
      expect(() => arrBad[0]!.asNumber.value, throwsFormatException);
    });
  });
}
