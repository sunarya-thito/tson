<h1 align="center">tson</h1>

Lightweight JSON object model for Dart with a pluggable registry for custom type
(de)serialization.

## Why tson?

- Typed wrappers for JSON primitives and containers (JsonString, JsonNumber,
  JsonBoolean, JsonArray, JsonObject)
- Ergonomic extensions: `.json` to wrap native values, `.build()` for
  pretty/compact output
- Registry-based (de)serialization for your own classes, with customizable
  parsing strategies
- No surprises with nulls: map nulls can be stripped automatically; list nulls
  are preserved

## Install

Add to your `pubspec.yaml`:

```yaml
dependencies:
    tson: ^1.0.0
```

Then run `dart pub get`.

Or add it via the command line:

```bash
dart pub add tson
```

## Quick start

```dart
import 'package:tson/tson.dart';

void main() {
  final obj = {
    'id': 1001,
    'name': 'Widget',
    'tags': ['a', 'b', 'c'],
    'stock': null, // map nulls are stripped by default when building
  }.json;

  print(obj.build());      // pretty, indent=2
  print(obj.toJson()); // compact
}
```

## Examples

Here are focused examples you can copy/paste.

### Primitives and operators

```dart
import 'package:tson/tson.dart';

void main() {
  final s = JsonString('hello');
  final n = JsonNumber(10);
  final b = JsonBoolean(true);

  print(s.toJson()); // "hello"
  print((n + JsonNumber(5)).value); // 15
  print((b & JsonBoolean(false)).value); // false
}
```

### Arrays and objects

```dart
import 'package:tson/tson.dart';

void main() {
  final obj = {
    'id': 1001,
    'name': 'Widget',
    'tags': ['a', 'b', 'c'],
    'stock': null, // map nulls are stripped by default when building
  }.json;

  // Access and mutate
  print(obj['name']!.asString.value); // Widget
  obj['name'] = JsonString('Gadget');
  print(obj.toJson()); // compact
  print(obj.build()); // pretty
}
```

### Parsing JSON

```dart
import 'package:tson/tson.dart';

void main() {
  final v = JsonValue.parse('{"a": 1, "b": true}');
  print(v.asObject['a']!.asNumber.intValue); // 1
  print(v.asObject['b']!.asBoolean.value); // true
}
```

### Encoder options (pretty vs compact)

```dart
import 'package:tson/tson.dart';

void main() {
  final obj = {'a': 1, 'b': null}.json;
  print(obj.toJson()); // {"a":1}
  print(obj.build());
}
```

## Custom types with JsonRegistry

Define how your classes are serialized to and deserialized from `JsonObject`
using `JsonRegistryEntry`s. Use a `JsonObjectParser` to control the wire format.

```dart
final registry = JsonRegistry(entries: [
  JsonRegistryEntry<PersonName>(
    type: 'PersonName',
    serializer: (e) => JsonObject.wrap({
      'firstName': e.firstName,
      'lastName': e.lastName,
    }),
    deserializer: (json) => PersonName(
      json['firstName']!.asString.value,
      json['lastName']!.asString.value,
    ),
  ),
  JsonRegistryEntry<Person>(
    type: 'Person',
    serializer: (e) => JsonObject.wrap({
      'name': JsonRegistry.currentRegistry.serialize(e.name).asObject,
      'age': e.age,
    }),
    deserializer: (json) => Person(
      json['name']!.asType<PersonName>(),
      json['age']!.asNumber.intValue,
    ),
  ),
]);

final value = registry.serialize(Person(PersonName('Alice', 'Smith'), 30));
print(value.build());
final obj = registry.deserialize(value);
```

### Parsers: choose your wire format

Two built-in strategies:

- `DefaultJsonObjectParser` (default): envelope with `__type` and `__data` keys.
- `FlatTypeParser`: flat object with a configurable discriminator (default
  `$type`).

You can also build your own parser. See `example/custom_parser.dart` for a
shape-based parser that stores no type tags and infers types from object shape.

```dart
final flat = JsonRegistry(
  parser: JsonObjectParser.flatTypeParser,
  entries: [...],
);
```

FlatTypeParser example:

```dart
import 'package:tson/tson.dart';

class Person {
  final String name;
  Person(this.name);
}

void main() {
  final registry = JsonRegistry(
  parser: JsonObjectParser.flatTypeParser,
    entries: [
      JsonRegistryEntry<Person>(
        type: 'Person',
        serializer: (p) => JsonObject.wrap({'name': p.name}),
        deserializer: (json) => Person(json['name']!.asString.value),
      ),
    ],
  );

  final json = registry.serialize(Person('Alice'));
  print(json.toJson()); // {"$type":"Person","name":"Alice"}

  final person = registry.deserialize(json) as Person;
  print(person.name); // Alice
}
```

## Raw (unsafe) mode

When you want to preserve the original Dart structures (List/Map/primitives) and
parse lazily only when needed, use `JsonValue.unsafe`. This keeps arrays and
maps as-is and defers parsing booleans/numbers until `.value` is read.

Important:

- Top-level value must be non-null. Nulls inside lists/maps are preserved.
- The raw types are internal; you always go through `JsonValue.unsafe`.

Example:

```dart
import 'package:tson/tson.dart';

void main() {
  final rawBool = JsonValue.unsafe({'ok': 'true'});
  print(rawBool.asObject['ok']!.asBoolean.value); // true

  final rawNum = JsonValue.unsafe('3.14').asNumber;
  print(rawNum.value); // 3.14

  final rawList = JsonValue.unsafe([1, '2', true, null]).asArray;
  print(rawList[1]!.asNumber.intValue); // 2

  final rawMap = JsonValue.unsafe({'a': '1', 2: false}).asObject;
  print(rawMap['a']!.asNumber.value); // 1
  print(rawMap['2']!.asBoolean.value); // false

  // Mutations store raw values back and toJson uses underlying structures
  rawMap['x'] = JsonString('hello');
  print(rawMap.toJson());

  // Errors are thrown lazily on access
  final bad = JsonValue.unsafe('not-a-number').asNumber;
  try {
    print(bad.value);
  } catch (e) {
    print('failed: $e'); // FormatException on access
  }
}
```
