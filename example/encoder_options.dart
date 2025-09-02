import 'package:typeson/typeson.dart';

void main() {
  final JsonObject obj = {
    'id': 7,
    'name': 'Null Demo',
    'note': null,
    'nested': {'keepNull': null, 'value': 1},
  }.json;

  // Default: indent=2, explicitNulls=false (nulls removed)
  print('Default build (nulls removed):');
  print(obj.build());

  // Keep nulls
  print('\nExplicit nulls:');
  print(obj.build(explicitNulls: true));

  // Compact (no indentation)
  print('\nCompact:');
  print(obj.build(indent: null));
}
