import 'package:test/test.dart';
import 'package:tson/tson.dart';

void main() {
  group('JsonString', () {
    test('creation and equality', () {
      final a = JsonString('hi');
      final b = 'hi'.json;
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('split', () {
      final s = JsonString('a,b,c');
      final parts = s.split(',');
      expect(parts.length, 3);
      expect(parts[0]!.asString.value, 'a');
      expect(parts[1]!.asString.value, 'b');
      expect(parts[2]!.asString.value, 'c');
    });

    test('asBoolean valid values', () {
      expect(JsonString('true').asBoolean.value, isTrue);
      expect(JsonString('false').asBoolean.value, isFalse);
    });

    test('maybeAsBoolean invalid returns null', () {
      expect(JsonString('TRUE').maybeAsBoolean, isNull);
      expect(JsonString('nope').maybeAsBoolean, isNull);
    });

    test('asNumber and maybeAsNumber', () {
      expect(JsonString('42').asNumber.value, 42);
      expect(JsonString('3.14').asNumber.value, 3.14);
      expect(JsonString('x').maybeAsNumber, isNull);
      expect(() => JsonString('x').asNumber, throwsFormatException);
    });

    test('toJson', () {
      expect(JsonString('hi').toJson(), '"hi"');
    });
  });

  group('JsonNumber', () {
    test('operators and conversions', () {
      final a = 10.json;
      final b = 3.json;
      expect((a + b).value, 13);
      expect((a - b).value, 7);
      expect((a * b).value, 30);
      expect((a / b).value, closeTo(3.3333, 1e-3));
      expect((a % b).value, 1);
      expect((-a).value, -10);
      expect((a ~/ b).value, 3);

      expect((a > b).value, isTrue);
      expect((a < b).value, isFalse);
      expect((a >= b).value, isTrue);
      expect((a <= b).value, isFalse);

      expect(a.asString.value, '10');
      expect(a.toJson(), '10');
    });

    test('equality scoped to runtimeType', () {
      expect(1.json == JsonString('1'), isFalse);
      expect(1.json, equals(1.json));
    });
  });

  group('JsonBoolean', () {
    test('operators and toString', () {
      final t = true.json;
      final f = false.json;
      expect((t & f).value, isFalse);
      expect((t | f).value, isTrue);
      expect((t ^ f).value, isTrue);
      expect((~t).value, isFalse);
      expect(t.asString.value, 'true');
      expect(t.toJson(), 'true');
    });
  });
}
