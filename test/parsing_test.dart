import 'package:test/test.dart';
import 'package:typeson/typeson.dart';

void main() {
  test('JsonValue.parse', () {
    final v = JsonValue.parse('{"x":1,"y":[2,3],"b":true,"s":"t"}');
    final o = v.asObject;
    expect(o['x']!.asNumber.intValue, 1);
    expect(o['y']!.asArray[1]!.asNumber.intValue, 3);
    expect(o['b']!.asBoolean.value, isTrue);
    expect(o['s']!.asString.value, 't');
    expect(v.toJson(), '{"x":1,"y":[2,3],"b":true,"s":"t"}');
  });
}
