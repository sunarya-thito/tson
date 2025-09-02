import 'package:test/test.dart';
import 'package:tson/tson.dart';

class PersonName {
  final String firstName;
  final String lastName;
  PersonName(this.firstName, this.lastName);
  @override
  String toString() => 'PersonName($firstName $lastName)';
}

class Person {
  final PersonName name;
  final int age;
  Person(this.name, this.age);
  @override
  String toString() => 'Person($name, $age)';
}

// Types for predicate test
abstract class Animal {}

class Dog implements Animal {
  final String name;
  Dog(this.name);
}

void main() {
  group('JsonRegistry with default parser', () {
    late JsonRegistry registry;

    setUp(() {
      registry = JsonRegistry(
        entries: [
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
        ],
      );
    });

    test('serialize and deserialize nested objects', () {
      final input = [
        Person(PersonName('Alice', 'Smith'), 30),
        {'Bob': Person(PersonName('Bob', 'Brown'), 25)},
      ];
      final json = registry.serialize(input);
      final s = json.build();
      expect(s.contains('"__type"'), isTrue);
      expect(s.contains('"__data"'), isTrue);

      final out = registry.deserialize(json);
      expect(out, isA<List>());
      final list = out as List<Object?>;
      expect(list.first, isA<Person>());
      expect((list.first as Person).name.firstName, 'Alice');
      expect((list[1] as Map)['Bob'], isA<Person>());
    });

    test('asType using registry param', () {
      final encoded = registry.serialize(Person(PersonName('Al', 'S'), 1));
      // encoded is the Person wrapper JsonObject, pick the nested name object
      final nestedName = encoded.asObject['__data']!.asObject['name']!.asObject;
      final name = nestedName.asType<PersonName>(registry: registry);
      expect(name.firstName, 'Al');
    });

    test('entry predicate (assignableType)', () {
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

      final out = reg.deserialize(reg.serialize(Dog('Rex')));
      expect(out, isA<Dog>());
      expect((out as Dog).name, 'Rex');
    });
  });
}
