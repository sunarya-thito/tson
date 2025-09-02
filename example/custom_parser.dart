import 'package:typeson/typeson.dart';

/// A custom parser that stores no type-discriminator at all.
/// It picks the matching entry purely by the JSON object's shape.
///
/// For example, a PersonName JSON is expected to have keys
/// { 'firstName': string, 'lastName': string }, while a Person JSON
/// is expected to have { 'name': object, 'age': number }.
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
    // No envelope to unwrap; pass the JSON straight to the entry deserializer.
    return entry.deserialize(json);
  }

  @override
  JsonObject toJson(Object object, JsonRegistryEntry entry) {
    // No envelope; return the entry's serialized data as-is.
    return entry.serialize(object);
  }
}

void main() {
  // Registry with a custom, shape-based parser (no type tags in JSON)
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
          // Ensure nested custom types are serialized via the registry
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

class PersonName {
  final String firstName;
  final String lastName;
  PersonName(this.firstName, this.lastName);
  @override
  String toString() => 'PersonName(firstName: $firstName, lastName: $lastName)';
}

class Person {
  final PersonName name;
  final int age;
  Person(this.name, this.age);
  @override
  String toString() => 'Person(name: $name, age: $age)';
}
