import 'dart:convert';

import 'package:typeson/src/util.dart';

/// Options for json encoding behavior.
class JsonEncoderOptions {
  /// Serialize in compact form without indentation and newlines and eliminate
  /// nulls from maps.
  static const compact = JsonEncoderOptions(indent: null, explicitNulls: false);

  /// Serialize in pretty form with indentation and newlines, eliminating
  /// nulls from maps.
  static const pretty = JsonEncoderOptions(indent: 2, explicitNulls: false);

  /// Serialize in pretty form with indentation and newlines, keeping nulls
  /// in maps.
  static const prettyWithNulls =
      JsonEncoderOptions(indent: 2, explicitNulls: true);

  /// Serialize in compact form without indentation and newlines, keeping
  /// nulls in maps.
  static const compactWithNulls =
      JsonEncoderOptions(indent: null, explicitNulls: true);

  /// Controls indentation width in spaces.
  ///
  /// - If `null`, a compact single-line string is produced.
  /// - If a non-negative integer, that many spaces are used per indent level.
  final int? indent;

  /// When `true`, keeps `null` values in maps. When `false`, properties whose
  /// value is `null` are removed from maps before encoding. Nulls in lists are
  /// always preserved.
  final bool explicitNulls;
  const JsonEncoderOptions({
    required this.indent,
    required this.explicitNulls,
  });

  static const _indentSentinel = -1;

  /// Returns a copy of this options object with the given fields replaced.
  JsonEncoderOptions copyWith({
    int? indent = _indentSentinel,
    bool? explicitNulls,
  }) {
    return JsonEncoderOptions(
      indent: indent == _indentSentinel ? this.indent : indent,
      explicitNulls: explicitNulls ?? this.explicitNulls,
    );
  }
}

/// Pretty and compact JSON string builder.
///
/// Given a JSON-encodeable value (maps, lists, primitives), this class can
/// convert it into a human-readable string with indentation or into a compact
/// single-line string, optionally removing `null` values from maps.
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
  @Deprecated('Use options instead')
  int? indent;

  /// When `true`, keeps `null` values in maps. When `false`, properties whose
  /// value is `null` are removed from maps before encoding. Nulls in lists are
  /// always preserved.
  @Deprecated('Use options instead')
  bool explicitNulls = false;

  /// Options for JSON encoding.
  JsonEncoderOptions options = JsonEncoderOptions.compactWithNulls;

  /// Creates a [JsonBuilder] for the given [json] value.
  ///
  /// Parameters:
  /// - [json]: Any JSON-encodeable value (`Map`, `List`, primitives, or `null`).
  JsonBuilder(this.json);

  /// Converts the configured [json] into a string according to [options].
  @override
  String toString() {
    Object? json = this.json;
    // ignore: deprecated_member_use_from_same_package
    if (!explicitNulls || !options.explicitNulls) {
      json = eliminateNull(json);
    }
    // ignore: deprecated_member_use_from_same_package
    int? indent = this.indent ?? options.indent;
    JsonEncoder encoder = JsonEncoder.withIndent(
      indent == null ? null : ' ' * indent,
    );
    return encoder.convert(json);
  }
}
