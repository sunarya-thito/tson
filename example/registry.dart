import 'package:tson/tson.dart';

void main() {
  // Define registry entries for custom types
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

  // Serialize a nested object graph using the registry
  final input = [
    Person(PersonName('Alice', 'Smith'), 30),
    {'Bob': Person(PersonName('Bob', 'Brown'), 25)},
  ];

  final JsonValue encoded = registry.serialize(input);
  print('Encoded (pretty):\n${encoded.build()}');

  // Deserialize back to native types
  final decoded = registry.deserialize(encoded);
  print('Decoded runtime type: ${decoded.runtimeType}');
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
