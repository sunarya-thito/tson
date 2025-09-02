import 'package:test/test.dart';
import 'package:typeson/typeson.dart';

void main() {
  group('Equality: primitives', () {
    test('JsonString', () {
      expect(JsonString('hi'), equals('hi'.json));
      expect(JsonString('hi'), isNot(equals(JsonString('HI'))));
      // Cross-type not equal
      expect(JsonString('1') == 1.json, isFalse);
      // Reflexive
      final s = JsonString('x');
      expect(s == s, isTrue);
    });

    test('RawJsonString vs JsonString (asymmetric)', () {
      final r = JsonValue.unsafe('hi').asString; // _RawJsonString
      final j = JsonString('hi');
      // Raw compares by underlying value against any JsonValue
      expect(r == j, isTrue);
      // Non-raw compares by runtimeType first (so not symmetric)
      expect(j == r, isFalse);
      // Reflexive
      expect(r == r, isTrue);
    });

    test('JsonBoolean', () {
      expect(JsonBoolean(true), equals(true.json));
      expect(JsonBoolean(false), isNot(equals(true.json)));
      // Reflexive
      final b = JsonBoolean(true);
      expect(b == b, isTrue);
    });

    test('RawJsonBoolean vs JsonBoolean (asymmetric and invalid parse)', () {
      final rTrue = JsonValue.unsafe('true').asBoolean; // _RawJsonBoolean
      final jTrue = JsonBoolean(true);
      expect(rTrue == jTrue, isTrue);
      expect(jTrue == rTrue, isFalse);
      // Invalid raw boolean triggers parse on equality
      final rBad = JsonValue.unsafe('notbool').asBoolean;
      expect(() => (rBad == JsonBoolean(false)), throwsFormatException);
    });

    test('JsonNumber (int/double)', () {
      expect(JsonNumber(1), equals(1.json));
      expect(JsonNumber(1), equals(JsonNumber(1.0))); // 1 == 1.0 in Dart
      expect(JsonNumber(2), isNot(equals(JsonNumber(3))));
      // Reflexive
      final n = JsonNumber(42);
      expect(n == n, isTrue);
    });

    test('RawJsonNumber vs JsonNumber (asymmetric and invalid parse)', () {
      // numeric string equals numeric value when raw is on LHS
      final r = JsonValue.unsafe('1').asNumber; // _RawJsonNumber
      final j = JsonNumber(1);
      expect(r == j, isTrue);
      expect(j == r, isFalse);

      // Raw underlying number also equals
      final rNum = JsonValue.unsafe(2).asNumber;
      expect(rNum == JsonNumber(2), isTrue);
      expect(JsonNumber(2) == rNum, isFalse);

      // Invalid numeric string: equality triggers parse and throws
      final rBad = JsonValue.unsafe('abc').asNumber;
      expect(() => (rBad == JsonNumber(0)), throwsFormatException);
    });
  });

  group('Equality: arrays', () {
    test('JsonArray equality/deep-equality and inequality', () {
      final a1 = JsonArray([
        1.json,
        'x'.json,
        null,
        JsonArray([true.json])
      ]);
      final a2 = JsonArray([
        1.json,
        'x'.json,
        null,
        JsonArray([true.json])
      ]);
      final a3 = JsonArray([
        1.json,
        'x'.json,
        JsonArray([true.json]),
        null
      ]);
      expect(a1, equals(a2));
      expect(a1 == a3, isFalse); // order matters
      // Nested difference
      final a4 = JsonArray([
        1.json,
        'x'.json,
        null,
        JsonArray([false.json])
      ]);
      expect(a1 == a4, isFalse);
      // Reflexive
      expect(a1 == a1, isTrue);
    });

    test('RawJsonArray vs JsonArray (asymmetric)', () {
      final r = JsonValue.unsafe([1, 'x', null, true]).asArray; // _RawJsonArray
      final j = JsonArray([1.json, 'x'.json, null, true.json]);
      // Raw side equals non-raw (elements compare raw->json by value)
      expect(r == j, isTrue);
      // But not symmetric (non-raw enforces runtimeType equality per element)
      expect(j == r, isFalse);
    });

    test('RawJsonArray with different element raw types vs JsonArray', () {
      // Underlying raw array has a string '1' instead of number 1
      final r = JsonValue.unsafe(['1']).asArray;
      final j = JsonArray([1.json]);
      expect(r == j, isFalse); // '1' != 1 when compared by value
      expect(j == r, isFalse);
    });
  });

  group('Equality: objects', () {
    test('JsonObject deep-equality, order-insensitive keys', () {
      final o1 = JsonObject({
        'a': 1.json,
        'b': JsonArray([true.json]),
        'c': null,
      });
      final o2 = JsonObject({
        'b': JsonArray([true.json]),
        'a': 1.json,
        'c': null,
      });
      final o3 = JsonObject({
        'a': 1.json,
        'b': JsonArray([false.json]),
        'c': null,
      });
      expect(o1, equals(o2));
      expect(o1 == o3, isFalse);
      // Reflexive
      expect(o1 == o1, isTrue);
    });

    test('RawJsonObject vs JsonObject (asymmetric, key stringification)', () {
      // Non-string key 1 should compare equal to key '1' on raw->json direction
      final r = JsonValue.unsafe({1: 'a', 'b': 2}).asObject; // _RawJsonObject
      final j = JsonObject({'1': 'a'.json, 'b': 2.json});
      expect(r == j, isTrue);
      // But not symmetric due to element runtimeType enforcement
      expect(j == r, isFalse);
    });

    test('RawJsonObject value type mismatch vs JsonObject', () {
      // Raw contains string '1' while json contains numeric 1
      final r = JsonValue.unsafe({'x': '1'}).asObject;
      final j = JsonObject({'x': 1.json});
      expect(r == j, isFalse);
      expect(j == r, isFalse);
    });
  });

  group('Equality: Raw wrapper via JsonValue.unsafe', () {
    test('RawJsonValue vs Json primitives (asymmetric)', () {
      expect(JsonValue.unsafe(1) == 1.json, isTrue);
      expect(1.json == JsonValue.unsafe(1), isFalse);
      expect(JsonValue.unsafe('x') == JsonString('x'), isTrue);
      expect(JsonString('x') == JsonValue.unsafe('x'), isFalse);
    });

    test('RawJsonValue vs container types (not deep-equal)', () {
      // RawJsonValue keeps raw List/Map; == compares identity/== on raw
      final rawList = JsonValue.unsafe([1, 2]);
      final jsonList = JsonArray([1.json, 2.json]);
      expect(rawList == jsonList, isFalse);

      final rawMap = JsonValue.unsafe({'a': 1});
      final jsonMap = JsonObject({'a': 1.json});
      expect(rawMap == jsonMap, isFalse);
    });
  });
}
