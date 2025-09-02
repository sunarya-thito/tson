import 'dart:convert';

import 'package:typeson/src/util.dart';

/// Pretty and compact JSON string builder.
///
/// Given a JSON-encodeable value (maps, lists, primitives), this class can
/// convert it into a human-readable string with indentation or into a compact
/// single-line string, optionally removing `null` values from maps.
///
/// By default, [indent] is `2` (two spaces) and [explicitNulls] is `false`,
/// which means nulls inside maps are removed (see [eliminateNull]) while nulls
/// inside lists are preserved.
///
/// Example:
/// ```dart
/// final value = {
///   'a': 1,
///   'b': null, // removed in default mode
///   'c': [1, null, 2],
/// };
///
/// final pretty = (JsonBuilder(value)..indent = 2).toString();
/// // {
/// //   "a": 1,
/// //   "c": [
/// //     1,
/// //     null,
/// //     2
/// //   ]
/// // }
///
/// final keepNulls = (JsonBuilder(value)
///   ..explicitNulls = true
///   ..indent = null).toString();
/// // {"a":1,"b":null,"c":[1,null,2]}
/// ```
///
/// See also:
/// - [eliminateNull] for the exact null-elimination behavior.
class JsonBuilder {
  /// The JSON-encodeable object to stringify. It may be a `Map`, `List`,
  /// or any primitive supported by `dart:convert`.
  final Object? json;

  /// Controls indentation width in spaces.
  ///
  /// - If `null`, a compact single-line string is produced.
  /// - If a non-negative integer, that many spaces are used per indent level.
  int? indent = 2;

  /// When `true`, keeps `null` values in maps. When `false`, properties whose
  /// value is `null` are removed from maps before encoding. Nulls in lists are
  /// always preserved.
  bool explicitNulls = false;

  /// Creates a [JsonBuilder] for the given [json] value.
  ///
  /// Parameters:
  /// - [json]: Any JSON-encodeable value (`Map`, `List`, primitives, or `null`).
  JsonBuilder(this.json);

  /// Converts the configured [json] into a string according to [indent] and
  /// [explicitNulls].
  @override
  String toString() {
    Object? json = this.json;
    if (!explicitNulls) {
      json = eliminateNull(json);
    }
    int? indent = this.indent;
    JsonEncoder encoder = JsonEncoder.withIndent(
      indent == null ? null : ' ' * indent,
    );
    return encoder.convert(json);
  }
}
