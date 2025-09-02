import 'package:test/test.dart';
import 'package:tson/tson.dart';

void main() {
  group('Extensions and build', () {
    test('List/Map .json and build formatting', () {
      final obj = {
        'a': 1,
        'b': null,
        'c': [true, null, 'x'],
      }.json;

      final pretty = obj.build();
      expect(pretty.contains('\n  '), isTrue); // indented
      expect(pretty.contains('"b"'), isFalse); // null stripped

      final keepingNulls = obj.build(explicitNulls: true);
      expect(keepingNulls.contains('"b"'), isTrue);

      final compact = obj.build(indent: null);
      expect(compact.contains('\n'), isFalse);
    });

    test('JsonValue.let', () {
      final r = 5.json.let((j) => j.asNumber.value * 2);
      expect(r, 10);
    });
  });
}
