import 'package:test/test.dart';
import 'package:tson/tson.dart';

class Name {
  final String v;
  Name(this.v);
}

void main() {
  test('custom parser end-to-end', () {
    final reg = JsonRegistry(
      parser: const FlatTypeParser(),
      entries: [
        JsonRegistryEntry<Name>(
          type: 'Name',
          serializer: (n) => JsonObject.wrap({'v': n.v}),
          deserializer: (json) => Name(json['v']!.asString.value),
        ),
      ],
    );

    final json = reg.serialize(Name('Zed')); // {$type: 'Name', v: 'Zed'}
    final s = json.build();
    expect(s.contains('"\$type"'), isTrue);
    final obj = json.asObject;
    final out = obj.asType<Name>(registry: reg);
    expect(out.v, 'Zed');
  });
}
