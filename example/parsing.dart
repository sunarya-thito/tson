import 'package:typeson/typeson.dart';

void main() {
  // Parse a JSON string into a JsonValue
  const raw = '{"title":"Example","count":3,"items":[{"id":1},{"id":2}]}';
  final JsonValue value = JsonValue.parse(raw);

  final JsonObject root = value.asObject;
  final title = root['title']!.asString.value;
  final count = root['count']!.asNumber.intValue;
  final firstId = root['items']!.asArray[0]!.asObject['id']!.asNumber.intValue;

  print('title=$title, count=$count, firstId=$firstId');

  // Convert back to compact JSON
  print('compact: ${root.build(indent: null)}');
}
