import 'package:typeson/typeson.dart';

// --- Example 1: Arrays and Objects ---
void arraysObjectsExample() {
  final JsonArray arr = [1, 'two', true, null].json;
  print('Array: \\${arr.toJson()}');

  final JsonObject obj = {
    'id': 1001,
    'name': 'Widget',
    'tags': ['a', 'b', 'c'],
    'stock': null,
  }.json;
  print('Object build default:\n\\${obj.build()}');
  print('name: \\${obj['name']!.asString.value}');
  print('first tag: \\${obj['tags']!.asArray[0]!.asString.value}');
  obj['price'] = 9.99.json;
  obj.updateAll((k, v) => v);
  print('Updated: \\${obj.build()}');
}

// --- Example 2: Custom Parser ---
class ShapeParser implements JsonObjectParser {
  final Map<String, bool Function(JsonObject)> matchers;
  const ShapeParser(this.matchers);
  @override
  bool canParse(JsonObject json, JsonRegistryEntry entry) {
    final m = matchers[entry.type];
    return m == null ? false : m(json);
  }

  @override
  Object fromJson(JsonObject json, JsonRegistryEntry entry) {
    return entry.deserialize(json);
  }

  @override
  JsonObject toJson(Object object, JsonRegistryEntry entry) {
    return entry.serialize(object);
  }
}

void customParserExample() {
  final registry = JsonRegistry(
    parser: ShapeParser({
      'PersonName': (json) {
        final a = json['firstName'];
        final b = json['lastName'];
        return a is JsonString && b is JsonString;
      },
      'Person': (json) {
        final name = json['name'];
        final age = json['age'];
        return name is JsonObject && age is JsonNumber;
      },
    }),
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
    Person(PersonName('Dana', 'White'), 33),
    Person(PersonName('Evan', 'Stone'), 41),
  ];

  final encoded = registry.serialize(input);
  print('Encoded with FlatTypeParser (pretty):');
  print(encoded.build());

  final decoded = registry.deserialize(encoded);
  print('\nDecoded back to native types:');
  print(decoded);
}

// --- Example 3: Encoder Options ---
void encoderOptionsExample() {
  final JsonObject obj = {
    'id': 7,
    'name': 'Null Demo',
    'note': null,
    'nested': {'keepNull': null, 'value': 1},
  }.json;
  print('Default build (nulls removed):');
  print(obj.build());
  print('\nExplicit nulls:');
  print(obj.build(explicitNulls: true));
  print('\nCompact:');
  print(obj.build(indent: null));
}

// --- Example 4: Parsing ---
void parsingExample() {
  const raw = '{"title":"Example","count":3,"items":[{"id":1},{"id":2}]}';
  final JsonValue value = JsonValue.parse(raw);
  final JsonObject root = value.asObject;
  final title = root['title']!.asString.value;
  final count = root['count']!.asNumber.intValue;
  final firstId = root['items']!.asArray[0]!.asObject['id']!.asNumber.intValue;
  print('title=\\$title, count=\\$count, firstId=\\$firstId');
  print('compact: \\${root.build(indent: null)}');
}

// --- Example 5: Primitives ---
void primitivesExample() {
  final JsonString s = 'hello'.json;
  final JsonNumber n = 42.json;
  final JsonBoolean b = true.json;
  print('String toJson: \\${s.toJson()}');
  print('Number toJson: \\${n.toJson()}');
  print('Boolean toJson: \\${b.toJson()}');
  print('Number as string: \\${n.asString.value}');
  final maybeNum = '123'.json.maybeAsNumber?.value;
  final maybeBool = 'true'.json.maybeAsBoolean?.value;
  print('String maybeAsNumber: \\$maybeNum');
  print('String maybeAsBoolean: \\$maybeBool');
  final JsonNumber a = 10.json;
  final JsonNumber c = 5.json;
  final JsonNumber sum = a + c;
  print('10 + 5 = \\${sum.value}');
  print('10 > 5 = \\${(a > c).value}');
}

// --- Example 6: Raw Unsafe ---
void rawUnsafeExample() {
  final rawBool = JsonValue.unsafe({'ok': 'true'});
  final ok = rawBool.asObject['ok']!.asBoolean;
  print('ok = \\${ok.value}');
  final rawNum = JsonValue.unsafe('3.14').asNumber;
  print('num = \\${rawNum.value}');
  final rawList = JsonValue.unsafe([1, '2', true, null]).asArray;
  print('list[1] as int = \\${rawList[1]!.asNumber.intValue}');
  final rawMap = JsonValue.unsafe({'a': '1', 2: false}).asObject;
  print('map["a"] as num = \\${rawMap['a']!.asNumber.value}');
  print('map["2"] as bool = \\${rawMap['2']!.asBoolean.value}');
  rawMap['x'] = JsonString('hello');
  print(rawMap.toJson());
}

// --- Example 7: Registry ---
void registryExample() {
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
  print('Encoded (pretty):\n\\${encoded.build()}');
  final decoded = registry.deserialize(encoded);
  print('Decoded runtime type: \\${decoded.runtimeType}');
  print(decoded);
}

// --- Shared Classes ---
class PersonName {
  final String firstName;
  final String lastName;
  PersonName(this.firstName, this.lastName);
  @override
  String toString() =>
      'PersonName(firstName: \\$firstName, lastName: \\$lastName)';
}

class Person {
  final PersonName name;
  final int age;
  Person(this.name, this.age);
  @override
  String toString() => 'Person(name: \\$name, age: \\$age)';
}

// --- Main Entrypoint ---
void main() {
  print('--- Arrays and Objects Example ---');
  arraysObjectsExample();
  print('\n--- Custom Parser Example ---');
  customParserExample();
  print('\n--- Encoder Options Example ---');
  encoderOptionsExample();
  print('\n--- Parsing Example ---');
  parsingExample();
  print('\n--- Primitives Example ---');
  primitivesExample();
  print('\n--- Raw Unsafe Example ---');
  rawUnsafeExample();
  print('\n--- Registry Example ---');
  registryExample();
}
