import 'package:test/test.dart';
import 'package:typeson/src/util.dart';

void main() {
  test('eliminateNull recursive', () {
    final input = {
      'a': 1,
      'b': null,
      'c': [
        1,
        null,
        {'x': null, 'y': 2},
      ],
    };

    final out = eliminateNull(input) as Map<Object?, Object?>;
    expect(out.containsKey('b'), isFalse);
    expect(out['c'], isA<List>());
    final list = out['c'] as List<Object?>;
    expect(list[1], isNull);
    expect(list[2], isA<Map>());
    final nested = list[2] as Map<Object?, Object?>;
    expect(nested['x'], isNull);
    expect(nested['y'], 2);
  });
}
