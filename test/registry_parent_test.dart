import 'package:test/test.dart';
import 'package:typeson/typeson.dart';

class Foo {
  final int x;
  Foo(this.x);
}

void main() {
  group('JsonRegistry with parent', () {
    JsonRegistryEntry<Foo> parentEntry() => JsonRegistryEntry<Foo>(
          type: 'Foo',
          serializer: (f) => JsonObject({'x': f.x.json}),
          deserializer: (j) => Foo(j['x']!.asNumber.intValue),
        );

    test('serialize uses parent when child has no entry (default envelope)',
        () {
      final parent = JsonRegistry(entries: [parentEntry()]);
      final child = JsonRegistry(parent: parent);

      final jv = child.serialize(Foo(7));
      final obj = jv.asObject;
      expect(obj['__type']!.asString.value, 'Foo');
      expect(obj['__data']!.asObject['x']!.asNumber.intValue, 7);
    });

    test('deserialize uses parent when child has no entry (default envelope)',
        () {
      final parent = JsonRegistry(entries: [parentEntry()]);
      final child = JsonRegistry(parent: parent);

      // Build an envelope like DefaultJsonObjectParser would
      final envelope = JsonObject({
        '__type': 'Foo'.json,
        '__data': JsonObject({'x': 9.json}),
      });

      final result = child.deserialize(envelope);
      expect(result, isA<Foo>());
      expect((result as Foo).x, 9);
    });

    test('serialize falls back and uses parent parser (flat)', () {
      final parent = JsonRegistry(
        entries: [parentEntry()],
        parser: JsonObjectParser.flatTypeParser,
      );
      final child = JsonRegistry(parent: parent);

      final jv = child.serialize(Foo(5));
      final obj = jv.asObject;
      // Flat should place $type discriminator and inline fields
      expect(obj[r'$type']!.asString.value, 'Foo');
      expect(obj['x']!.asNumber.intValue, 5);
      // and not contain __data
      expect(obj['__data'], isNull);
    });

    test('deserialize falls back and uses parent parser (flat)', () {
      final parent = JsonRegistry(
        entries: [parentEntry()],
        parser: JsonObjectParser.flatTypeParser,
      );
      final child = JsonRegistry(parent: parent);

      final flat = JsonObject({
        r'$type': 'Foo'.json,
        'x': 11.json,
      });

      final result = child.deserialize(flat);
      expect(result, isA<Foo>());
      expect((result as Foo).x, 11);
    });

    test('child overrides parent for serialize and deserialize', () {
      final parent = JsonRegistry(entries: [
        // parent version encodes as is
        parentEntry(),
      ]);

      // child version modifies values so we can detect it was chosen
      final childEntry = JsonRegistryEntry<Foo>(
        type: 'Foo',
        serializer: (f) => JsonObject({'x': (f.x + 100).json}),
        deserializer: (j) => Foo(j['x']!.asNumber.intValue - 100),
      );

      final child = JsonRegistry(parent: parent, entries: [childEntry]);

      // Serialize chooses child entry
      final jv = child.serialize(Foo(1));
      final obj = jv.asObject;
      expect(obj['__data']!.asObject['x']!.asNumber.intValue, 101);

      // Deserialize chooses child entry
      final envelope = JsonObject({
        '__type': 'Foo'.json,
        '__data': JsonObject({'x': 150.json}),
      });
      final result = child.deserialize(envelope) as Foo;
      expect(result.x, 50); // 150 - 100 = 50 if child deserializer used
    });
  });
}
