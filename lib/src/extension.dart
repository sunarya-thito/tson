import 'package:typeson/typeson.dart';

/// Convenience methods for building and working with [JsonValue] trees.
///
/// Examples:
/// ```dart
/// final j = {'a': 1, 'b': null}.json;
/// print(j.build()); // pretty, nulls in maps removed by default
/// print(j.build(indent: null, explicitNulls: true)); // compact, keeps nulls
///
/// final length = 'hello'.json.let((v) => v.asString.value.length);
/// print(length); // 5
/// ```
extension JsonValueExtension on JsonValue {
  /// Builds a JSON string from this value.
  ///
  /// Parameters:
  /// - [indent]: Number of spaces per indent level. When `null`, produces a
  ///   compact single-line string.
  /// - [explicitNulls]: When `true`, keeps nulls in maps; otherwise removes
  ///   them. Nulls in lists are always preserved.
  ///
  /// Example:
  /// ```dart
  /// final obj = {'a': 1, 'b': null}.json;
  /// print(obj.build()); // pretty, without "b"
  /// print(obj.build(indent: null, explicitNulls: true)); // compact, keeps b
  /// ```
  String build({int? indent = 2, bool explicitNulls = false}) {
    return (JsonBuilder(toEncodeable())
          ..indent = indent
          ..explicitNulls = explicitNulls)
        .toString();
  }

  /// Applies [func] to this instance and returns its result.
  ///
  /// Useful to keep code fluent:
  /// ```dart
  /// final len = 'hello'.json.let((j) => j.asString.value.length);
  /// ```
  T let<T>(T Function(JsonValue json) func) {
    return func(this);
  }
}

/// Creates a [JsonString] from a Dart [String].
///
/// Example:
/// ```dart
/// final s = 'hello'.json; // JsonString('hello')
/// ```
extension JsonStringExtension on String {
  /// Wraps this string into a [JsonString].
  ///
  /// Example:
  /// ```dart
  /// final j = 'hello'.json; // JsonString('hello')
  /// print(j.value); // hello
  /// ```
  JsonString get json {
    return JsonString(this);
  }
}

/// Creates a [JsonNumber] from a Dart [num].
///
/// Example:
/// ```dart
/// final n = 42.json; // JsonNumber(42)
/// print(n.intValue); // 42
/// ```
extension JsonNumberExtension on num {
  /// Wraps this number into a [JsonNumber].
  ///
  /// Example:
  /// ```dart
  /// final j = 42.json; // JsonNumber(42)
  /// print(j.intValue); // 42
  /// ```
  JsonNumber get json {
    return JsonNumber(this);
  }
}

/// Creates a [JsonBoolean] from a Dart [bool].
///
/// Example:
/// ```dart
/// final b = true.json; // JsonBoolean(true)
/// print((b & JsonBoolean(false)).value); // false
/// ```
extension JsonBooleanExtension on bool {
  /// Wraps this boolean into a [JsonBoolean].
  ///
  /// Example:
  /// ```dart
  /// final j = true.json; // JsonBoolean(true)
  /// print((j & JsonBoolean(false)).value); // false
  /// ```
  JsonBoolean get json {
    return JsonBoolean(this);
  }
}

/// Creates a [JsonArray] from a Dart [List].
///
/// Each non-null element is wrapped into a [JsonValue], `null` stays `null`.
///
/// See also:
/// - [JsonArray]
///
/// Example:
/// ```dart
/// final a = [1, '2', null].json; // JsonArray
/// print(a[0]!.asNumber.intValue); // 1
/// print(a[1]!.asNumber.intValue); // 2
/// print(a[2]); // null
/// ```
extension JsonArrayExtension on List<Object?> {
  /// Wraps this list into a [JsonArray], preserving `null` elements.
  ///
  /// Each non-null element becomes a [JsonValue]; `null` stays `null`.
  ///
  /// Example:
  /// ```dart
  /// final j = [1, '2', null].json; // JsonArray
  /// print(j[1]!.asNumber.intValue); // 2
  /// print(j[2]); // null
  /// ```
  JsonArray get json {
    return JsonArray(map((e) => e == null ? null : JsonValue(e)).toList());
  }
}

/// Creates a [JsonObject] from a Dart [Map].
///
/// - Any key that is `null` is ignored.
/// - Non-null keys are stringified using `toString()`.
/// - Non-null values are wrapped into [JsonValue], `null` stays `null`.
///
/// See also:
/// - [JsonObject]
///
/// Example:
/// ```dart
/// final o = {'a': 1, 2: 'b', null: 3}.json; // JsonObject
/// print(o['a']!.asNumber.intValue); // 1
/// print(o['2']!.asString.value); // b
/// print(o.containsKey('null')); // false (null key ignored)
/// ```
extension JsonObjectExtension on Map<Object?, Object?> {
  /// Wraps this map into a [JsonObject].
  ///
  /// - Ignores entries with a `null` key.
  /// - Stringifies keys using `toString()`.
  /// - Wraps non-null values into [JsonValue]; `null` stays `null`.
  ///
  /// Example:
  /// ```dart
  /// final j = {'a': 1, 2: 'b', null: 3}.json; // JsonObject
  /// print(j['2']!.asString.value); // b
  /// ```
  JsonObject get json {
    return JsonObject.fromEntries(
      entries.where((e) => e.key != null).map(
            (e) => MapEntry(
              e.key.toString(),
              e.value == null ? null : JsonValue(e.value!),
            ),
          ),
    );
  }
}

/// Convenience to wrap any non-null object into a raw [JsonValue] that
/// preserves the underlying structure and parses lazily.
///
/// See: [JsonValue.unsafe].
///
/// Example:
/// ```dart
/// final raw = {'x': 'true'}.rawJson; // JsonValue.unsafe
/// print(raw.asObject['x']!.asBoolean.value); // true
/// ```
///
/// Notes:
/// - Top-level value must be non-null; use containers to hold nulls.
extension RawJsonExtension on Object {
  /// Wraps `this` with [JsonValue.unsafe].
  JsonValue get rawJson {
    return JsonValue.unsafe(this);
  }
}
