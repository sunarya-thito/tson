## typeson — Typed JSON values and pluggable (de)serialization for Dart

Typed wrappers for JSON values, ergonomic builders, and a flexible registry for
custom (de)serialization. Works great for transforming JSON with type-safe
helpers and encoding/decoding your own domain objects.

- Typed JSON nodes: JsonString, JsonNumber, JsonBoolean, JsonArray, JsonObject
- Fluent extensions: .json on primitives, lists, and maps; .build for
  pretty/compact output; .let for inline transforms
- Registry-based (de)serialization for custom types with pluggable parsers
  (envelope, flat type key, or your own)
- Raw/unsafe mode for lazy parsing and zero-copy wrapping of existing structures

## Install

Add to your pubspec.yaml:

```yaml
dependencies:
    tson:
        git: https://github.com/sunarya-thito/tson.git
```

Requires Dart SDK >= 3.0.0.

## Quick start

### Primitives

```dart
import 'package:typeson/tson.dart';

void main() {
	final JsonString s = 'hello'.json;
	final JsonNumber n = 42.json;
	final JsonBoolean b = true.json;

	print(s.toJson()); // "hello"
	print(n.toJson()); // 42
	print(b.toJson()); // true

	print(n.asString.value); // 42
	print('123'.json.maybeAsNumber?.value); // 123
	print('true'.json.maybeAsBoolean?.value); // true

	final JsonNumber a = 10.json;
	final JsonNumber c = 5.json;
	print((a + c).value); // 15
	print((a > c).value); // true
}
```

### Arrays and objects

```dart
import 'package:typeson/typeson.dart';

void main() {
	// Array preserves nulls
	final JsonArray arr = [1, 'two', true, null].json;
	print(arr.toJson()); // [1,"two",true,null]

	// Object: keys stringified, null values kept in the node, but build() can drop nulls from maps (see below)
	final JsonObject obj = {
		'id': 1001,
		'name': 'Widget',
		'tags': ['a', 'b', 'c'],
		'stock': null,
	}.json;

	// Access
	print(obj['name']!.asString.value); // Widget
	print(obj['tags']!.asArray[0]!.asString.value); // a

	// Mutate
	obj['price'] = 9.99.json;
	print(obj['price']!.asNumber.doubleValue); // 9.99
}
```

### Pretty/compact building and null elimination

The .build extension uses JsonBuilder with:

- indent: spaces per level, null for compact
- explicitNulls: when false (default), null map entries are removed; list nulls
  are preserved

```dart
import 'package:typeson/typeson.dart';

void main() {
	final JsonObject obj = {
		'id': 7,
		'name': 'Null Demo',
		'note': null, // removed by default
		'nested': {'keepNull': null, 'value': 1},
	}.json;

	// Default: indent=2, explicitNulls=false
	print(obj.build());
	// {
	//   "id": 7,
	//   "name": "Null Demo",
	//   "nested": {
	//     "value": 1
	//   }
	// }

	// Keep nulls
	print(obj.build(explicitNulls: true));
	// {
	//   "id": 7,
	//   "name": "Null Demo",
	//   "note": null,
	//   "nested": {
	//     "keepNull": null,
	//     "value": 1
	//   }
	// }

	// Compact
	print(obj.build(indent: null));
	// {"id":7,"name":"Null Demo","nested":{"value":1}}
}
```

### Parse JSON string to typed nodes

```dart
import 'package:typeson/typeson.dart';

void main() {
	const raw = '{"title":"Example","count":3,"items":[{"id":1},{"id":2}]}'
			;
	final JsonValue value = JsonValue.parse(raw);

	final JsonObject root = value.asObject;
	final title = root['title']!.asString.value;
	final count = root['count']!.asNumber.intValue;
	final firstId = root['items']!.asArray[0]!.asObject['id']!.asNumber.intValue;

	print('title=$title, count=$count, firstId=$firstId');
	// title=Example, count=3, firstId=1

	print(root.build(indent: null));
	// {"title":"Example","count":3,"items":[{"id":1},{"id":2}]}
}
```

## Raw/unsafe mode (lazy parsing, zero-copy)

Use JsonValue.unsafe(...) or the .rawJson extension to wrap existing structures
without eagerly converting elements. Booleans and numbers are parsed only when
.value is accessed; lists and maps are preserved and lazily wrapped.

```dart
import 'package:typeson/typeson.dart';

void main() {
	final rawBool = JsonValue.unsafe({'ok': 'true'});
	final ok = rawBool.asObject['ok']!.asBoolean; // not parsed yet
	print(ok.value); // true

	final rawNum = JsonValue.unsafe('3.14').asNumber; // not parsed yet
	print(rawNum.value); // 3.14

	final rawList = JsonValue.unsafe([1, '2', true, null]).asArray;
	print(rawList[1]!.asNumber.intValue); // 2

	final rawMap = JsonValue.unsafe({'a': '1', 2: false}).asObject;
	print(rawMap['a']!.asNumber.value); // 1
	print(rawMap['2']!.asBoolean.value); // false

	// Mutations store raw values back
	rawMap['x'] = JsonString('hello');
	print(rawMap.toJson()); // {"a":"1","2":false,"x":"hello"}
}
```

## Registry-based custom (de)serialization

Define entries that tell the registry how to encode/decode your types. By
default, the registry uses an envelope format: {"__type": "TypeName", "__data":
{...}}.

Key pieces:

- JsonRegistryEntry<T>: type identifier, serializer, deserializer, optional
  check predicate and optional parser override
- JsonRegistry: holds entries and an optional default parser
- JsonObjectParser: strategy for how objects are represented; built-ins include
  DefaultJsonObjectParser (envelope) and FlatTypeParser (inline with a $type
  key)
- JsonRegistryEntry.exactType and .assignableType helpers for matching

```dart
import 'package:typeson/typeson.dart';

class PersonName {
	final String firstName;
	final String lastName;
	PersonName(this.firstName, this.lastName);
}

class Person {
	final PersonName name;
	final int age;
	Person(this.name, this.age);
}

void main() {
	final registry = JsonRegistry(
		entries: [
			JsonRegistryEntry<PersonName>(
				type: 'PersonName',
				serializer: (e) =>
						JsonObject.wrap({'firstName': e.firstName, 'lastName': e.lastName}),
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
		],
	);

	final input = [
		Person(PersonName('Alice', 'Smith'), 30),
		{'Bob': Person(PersonName('Bob', 'Brown'), 25)},
	];

	final JsonValue encoded = registry.serialize(input);
	print(encoded.build());
	// [
	//   {
	//     "__type": "Person",
	//     "__data": {
	//       "name": {
	//         "__type": "PersonName",
	//         "__data": {"firstName": "Alice", "lastName": "Smith"}
	//       },
	//       "age": 30
	//     }
	//   },
	//   {
	//     "Bob": {
	//       "__type": "Person",
	//       "__data": {
	//         "name": {
	//           "__type": "PersonName",
	//           "__data": {"firstName": "Bob", "lastName": "Brown"}
	//         },
	//         "age": 25
	//       }
	//     }
	//   }
	// ]

	final decoded = registry.deserialize(encoded);
	print(decoded is List); // true
}
```

### Flat type parser ($type discriminator)

Use FlatTypeParser to inline a type discriminator instead of the envelope:

```dart
import 'package:typeson/typeson.dart';

class Name { final String v; Name(this.v); }

void main() {
	final reg = JsonRegistry(
		parser: const FlatTypeParser(), // defaults to discriminator key "$type"
		entries: [
			JsonRegistryEntry<Name>(
				type: 'Name',
				serializer: (n) => JsonObject.wrap({'v': n.v}),
				deserializer: (json) => Name(json['v']!.asString.value),
			),
		],
	);

	final json = reg.serialize(Name('Zed'));
	print(json.build());
	// {
	//   "$type": "Name",
	//   "v": "Zed"
	// }

	final out = json.asObject.asType<Name>(registry: reg);
	print(out.v); // Zed
}
```

### Matching strategy with predicates

Entries can match by exact runtime type (default) or via a predicate like
assignableType:

```dart
import 'package:typeson/typeson.dart';

abstract class Animal {}
class Dog implements Animal { final String name; Dog(this.name); }

void main() {
	final reg = JsonRegistry(
		entries: [
			JsonRegistryEntry<Animal>(
				type: 'Animal',
				serializer: (a) => JsonObject.wrap({'name': (a as Dog).name}),
				deserializer: (json) => Dog(json['name']!.asString.value),
				check: JsonRegistryEntry.assignableType<Animal>,
			),
		],
	);

	final roundTrip = reg.deserialize(reg.serialize(Dog('Rex')));
	print((roundTrip as Dog).name); // Rex
}
```

## API highlights

- JsonValue
  - factory JsonValue(Object): wrap String/num/bool/List/Map or custom objects
    via active registry
  - factory JsonValue.parse(String): decode from JSON text
  - factory JsonValue.unsafe(Object): raw wrapper with lazy parsing and
    zero-copy views
  - toJson(), toEncodeable(), asString/asNumber/asBoolean/asArray/asObject,
    asType<T>({registry})
- JsonString
  - value, split, asBoolean ("true"/"false"), asNumber, maybeAsBoolean,
    maybeAsNumber
- JsonNumber
  - value, intValue, doubleValue, arithmetic and comparisons, asString
- JsonBoolean
  - value, &, |, ^, ~, asString
- JsonArray
  - value: List<JsonValue?>, iterable, index access/mutation, add/insert/remove
    variants, containsElement, asMap(), toEncodeable()
- JsonObject
  - value: Map<String, JsonValue?>, iterable, key access/mutation,
    put/update/remove variants, containsKey/containsValue, toEncodeable(),
    asType<T>()
- Extensions
  - on String/num/bool/List/Map: .json → corresponding JsonValue wrappers
  - on JsonValue: .build({int? indent = 2, bool explicitNulls = false}),
    .let(...)
  - on Object: .rawJson → JsonValue.unsafe(this)
- JsonBuilder
  - indent, explicitNulls; eliminate nulls in maps by default; preserves nulls
    in lists
- JsonRegistry / JsonRegistryEntry / JsonObjectParser
  - Envelope ("__type"/"__data") by default; FlatTypeParser with "$type"; custom
    parsers supported

## Notes

- raw.dart is internal; use JsonValue.unsafe(...) or .rawJson instead of
  importing src directly.
- .build’s null-elimination only removes nulls from maps; it preserves nulls in
  lists.
- When writing serializers for nested custom types, use
  JsonRegistry.currentRegistry to ensure nested entries get serialized with the
  active registry.

## Run examples/tests (optional)

You can copy any snippet above into a small Dart app. To run the repo tests
locally:

```sh
dart pub get
dart test
```

That’s it—enjoy typed JSON with flexible (de)serialization.
