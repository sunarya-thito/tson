import 'dart:convert';

import 'package:tson/tson.dart';
import 'raw.dart' as raw;

/// Base interface for all JSON values used by this library.
///
/// The [JsonValue] factory converts common Dart values (String/num/bool,
/// List/Map) into typed wrappers ([JsonString], [JsonNumber], [JsonBoolean],
/// [JsonArray], [JsonObject]) or consults the active [JsonRegistry] to
/// serialize arbitrary objects.
///
/// Usage:
/// ```dart
/// final v1 = JsonValue('hello'); // JsonString
/// final v2 = JsonValue([1, 2, 3]); // JsonArray
/// final s = v2.toJson(); // "[1,2,3]"
/// ```
///
/// See also:
/// - [JsonArray]
/// - [JsonObject]
/// - [JsonRegistry]
abstract interface class JsonValue {
  /// Creates a [JsonValue] wrapper for a Dart value.
  ///
  /// Accepts:
  /// - [String] → [JsonString]
  /// - [num] (int/double) → [JsonNumber]
  /// - [bool] → [JsonBoolean]
  /// - [List] → [JsonArray] (elements wrapped recursively)
  /// - [Map] → [JsonObject] (keys stringified, values wrapped)
  /// - Any other [Object] is passed through [JsonRegistry] to find a matching
  ///   entry; if none is found, throws [ArgumentError].
  ///
  /// Example:
  /// ```dart
  /// final j = JsonValue({'x': 1, 'y': true});
  /// print(j.toJson()); // {"x":1,"y":true}
  /// ```
  factory JsonValue(Object value) => switch (value) {
        JsonValue v => v,
        String s => JsonString(s),
        num n => JsonNumber(n),
        bool b => JsonBoolean(b),
        List l => JsonArray.wrap(l),
        Map m => JsonObject.wrap(m),
        Object other => JsonRegistry.findAndSerialize(other) ??
            (throw ArgumentError(
              'Cannot convert object of type ${other.runtimeType} to JsonValue',
            )),
      };

  /// Creates a [JsonValue] wrapper that does not eagerly convert the input.
  ///
  /// This is the "unsafe"/raw entry point: the returned value preserves the
  /// original Dart structures and defers parsing/conversion until specific
  /// getters are accessed. Use this when you want to inspect or manipulate
  /// data lazily without upfront wrapping.
  ///
  /// Examples:
  /// ```dart
  /// // 1) Booleans (lazy parse from string)
  /// final rawBool = JsonValue.unsafe({'x': 'true'});
  /// final b = rawBool.asObject['x']!.asBoolean; // parsed on demand
  /// print(b.value); // true
  ///
  /// // 2) Numbers (lazy parse from string or accept num directly)
  /// final rawNum1 = JsonValue.unsafe('3.14').asNumber;
  /// print(rawNum1.value); // 3.14
  /// final rawNum2 = JsonValue.unsafe(42).asNumber;
  /// print(rawNum2.intValue); // 42
  ///
  /// // 3) Lists (elements wrapped lazily)
  /// final rawList = JsonValue.unsafe([1, '2', true]).asArray;
  /// print(rawList[1]!.asNumber.value); // 2
  /// print(rawList[2]!.asBoolean.value); // true
  ///
  /// // 4) Maps (non-string keys are stringified; values remain lazy)
  /// final rawMap = JsonValue.unsafe({'a': '1', 2: false}).asObject;
  /// print(rawMap['a']!.asNumber.value); // 1
  /// print(rawMap['2']!.asBoolean.value); // false
  /// ```
  factory JsonValue.unsafe(Object rawValue) => raw.RawJsonValue(rawValue);

  /// Parses a JSON [source] string into a [JsonValue] tree using `jsonDecode`.
  ///
  /// Throws a [FormatException] if the input is not valid JSON.
  ///
  /// Example:
  /// ```dart
  /// final v = JsonValue.parse('{"a": 1, "b": true}');
  /// print(v.asObject['a']!.asNumber.intValue); // 1
  /// ```
  factory JsonValue.parse(String source) {
    final decoded = jsonDecode(source);
    return JsonValue(decoded);
  }

  /// The underlying Dart value represented by this JSON node.
  ///
  /// For containers, this is a `List<JsonValue?>` or `Map<String, JsonValue?>`.
  Object get value;

  /// Converts this node into a standard JSON-encodeable Dart structure.
  ///
  /// - [JsonArray] → `List<Object?>`
  /// - [JsonObject] → `Map<String, Object?>`
  /// - Primitives → the wrapped primitive
  ///
  /// If a [JsonRegistry] is active, custom objects may be deserialized.
  Object toEncodeable();

  /// Casts this value to [JsonString]. Asserts at runtime if not a string.
  JsonString get asString;

  /// Casts this value to [JsonNumber]. Asserts at runtime if not a number.
  JsonNumber get asNumber;

  /// Casts this value to [JsonBoolean]. Asserts at runtime if not a boolean.
  JsonBoolean get asBoolean;

  /// Casts this value to [JsonArray]. Asserts at runtime if not an array.
  JsonArray get asArray;

  /// Casts this value to [JsonObject]. Asserts at runtime if not an object.
  JsonObject get asObject;

  /// Converts this JSON object to a Dart type [T] using a [JsonRegistry].
  ///
  /// Parameters:
  /// - [registry]: Optional registry to use; if omitted, uses the current
  ///   registry on the stack (see [JsonRegistry.currentRegistry]).
  ///
  /// Throws [Exception] if this node cannot be converted to [T].
  ///
  /// Example:
  /// ```dart
  /// // Given a registry that knows how to decode a Person from a JsonObject
  /// final registry = JsonRegistry(entries: [/* your entries */]);
  /// final obj = JsonObject({
  ///   'name': JsonString('Ada'),
  ///   'age': JsonNumber(30),
  /// });
  /// // Using the active (or provided) registry, convert to a domain object:
  /// // final person = obj.asType<Person>(registry: registry);
  /// ```
  T asType<T>({JsonRegistry? registry});

  /// Encodes this value into a compact JSON string using `jsonEncode`.
  ///
  /// For pretty output or null-elimination, see [JsonValueExtension.build].
  ///
  /// Example:
  /// ```dart
  /// final j = JsonValue({'x': 1, 'y': true});
  /// print(j.toJson()); // {"x":1,"y":true}
  /// ```
  String toJson();
}

/// Shared implementation for [JsonValue] variants.
abstract class AbstractJsonValue implements JsonValue {
  const AbstractJsonValue();

  @override
  T asType<T>({JsonRegistry? registry}) {
    throw Exception('Cannot convert $this to $T');
  }

  @override
  JsonString get asString {
    assert(this is JsonString, 'Expected JsonString');
    return this as JsonString;
  }

  @override
  JsonNumber get asNumber {
    assert(this is JsonNumber, 'Expected JsonNumber');
    return this as JsonNumber;
  }

  @override
  JsonBoolean get asBoolean {
    assert(this is JsonBoolean, 'Expected JsonBoolean');
    return this as JsonBoolean;
  }

  @override
  JsonArray get asArray {
    assert(this is JsonArray, 'Expected JsonArray');
    return this as JsonArray;
  }

  @override
  JsonObject get asObject {
    assert(this is JsonObject, 'Expected JsonObject');
    return this as JsonObject;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return value == (other as AbstractJsonValue).value;
  }

  @override
  String toJson() {
    return jsonEncode(toEncodeable());
  }

  @override
  String toString() => value.toString();
}

/// Represents a JSON string value.
///
/// Example:
/// ```dart
/// final s = JsonString('hi');
/// print(s.asNumber.maybeAsNumber); // null
/// print(s.toJson()); // "hi"
/// ```
class JsonString extends AbstractJsonValue {
  /// The wrapped string value.
  @override
  final String value;

  /// Creates a JSON string wrapper for [value].
  ///
  /// Example:
  /// ```dart
  /// const s = JsonString('hello');
  /// print(s.value); // hello
  /// print(s.toJson()); // "hello"
  /// ```
  const JsonString(this.value);

  /// Splits the string by [delimiter] and returns a [JsonArray] of
  /// [JsonString] segments.
  ///
  /// Example:
  /// ```dart
  /// final arr = JsonString('a,b').split(',');
  /// print(arr[0]!.asString.value); // a
  /// print(arr[1]!.asString.value); // b
  /// ```
  ///
  /// Example:
  /// ```dart
  /// JsonString('a,b').split(',') // => JsonArray(['a','b'])
  /// ```
  JsonArray split(Pattern delimiter) {
    final parts = value.split(delimiter);
    return JsonArray(parts.map((part) => JsonString(part)).toList());
  }

  /// Returns the raw string for JSON encoding.
  @override
  Object toEncodeable() => value;

  /// Converts this string to [JsonBoolean] if it equals `"true"` or
  /// `"false"`, otherwise asserts.
  ///
  /// Example:
  /// ```dart
  /// print(JsonString('true').asBoolean.value); // true
  /// // JsonString('yes').asBoolean; // assertion error in debug mode
  /// ```
  @override
  JsonBoolean get asBoolean {
    assert(
      value == 'true' || value == 'false',
      'Cannot convert string "$value" to boolean',
    );
    return JsonBoolean(value == 'true');
  }

  /// Parses this string as a number, throwing [FormatException] on failure.
  ///
  /// Example:
  /// ```dart
  /// print(JsonString('42').asNumber.intValue); // 42
  /// // JsonString('NaN').asNumber; // throws FormatException
  /// ```
  @override
  JsonNumber get asNumber {
    final num? parsed = num.tryParse(value);
    if (parsed == null) {
      throw FormatException('Cannot convert string "$value" to number');
    }
    return JsonNumber(parsed);
  }

  /// Attempts to parse this string as a boolean. Returns `null` if not
  /// `"true"` or `"false"`.
  ///
  /// Example:
  /// ```dart
  /// print(JsonString('true').maybeAsBoolean?.value); // true
  /// print(JsonString('no').maybeAsBoolean == null); // true
  /// ```
  JsonBoolean? get maybeAsBoolean {
    if (value == 'true' || value == 'false') {
      return JsonBoolean(value == 'true');
    }
    return null;
  }

  /// Attempts to parse this string as a number, or returns `null`.
  ///
  /// Example:
  /// ```dart
  /// print(JsonString('3.14').maybeAsNumber?.doubleValue); // 3.14
  /// print(JsonString('abc').maybeAsNumber == null); // true
  /// ```
  JsonNumber? get maybeAsNumber {
    final num? parsed = num.tryParse(value);
    if (parsed != null) {
      return JsonNumber(parsed);
    }
    return null;
  }
}

/// Represents a JSON number (int or double) and provides numeric operators.
///
/// Example:
/// ```dart
/// final a = JsonNumber(10);
/// final b = JsonNumber(3);
/// print((a / b).value); // 3.333...
/// ```
class JsonNumber extends AbstractJsonValue {
  /// The wrapped numeric value (int or double).
  @override
  final num value;

  /// Creates a JSON number wrapper for [value].
  ///
  /// Example:
  /// ```dart
  /// const n = JsonNumber(3.5);
  /// print(n.doubleValue); // 3.5
  /// print(n.intValue);    // 3
  /// ```
  const JsonNumber(this.value);

  /// Returns the value as double via `num.toDouble()`.
  ///
  /// Example:
  /// ```dart
  /// print(JsonNumber(2).doubleValue); // 2.0
  /// ```
  double get doubleValue => value.toDouble();

  /// Returns the value as int via `num.toInt()` (truncating if needed).
  ///
  /// Example:
  /// ```dart
  /// print(JsonNumber(2.9).intValue); // 2
  /// ```
  int get intValue => value.toInt();

  /// Adds this number to [other] and returns the sum as [JsonNumber].
  ///
  /// Example:
  /// ```dart
  /// final a = JsonNumber(5);
  /// final b = JsonNumber(2);
  /// final sum = a + b;
  /// print(sum.value); // 7
  /// ```
  JsonNumber operator +(JsonNumber other) => JsonNumber(value + other.value);

  /// Subtracts [other] from this number and returns the difference.
  ///
  /// Example:
  /// ```dart
  /// final a = JsonNumber(5);
  /// final b = JsonNumber(2);
  /// print((a - b).value); // 3
  /// ```
  JsonNumber operator -(JsonNumber other) => JsonNumber(value - other.value);

  /// Multiplies this number by [other] and returns the product.
  ///
  /// Example:
  /// ```dart
  /// final a = JsonNumber(5);
  /// final b = JsonNumber(2);
  /// print((a * b).value); // 10
  /// ```
  JsonNumber operator *(JsonNumber other) => JsonNumber(value * other.value);

  /// Divides this number by [other] and returns a [JsonNumber] wrapping a double.
  ///
  /// Example:
  /// ```dart
  /// final a = JsonNumber(5);
  /// final b = JsonNumber(2);
  /// print((a / b).value); // 2.5
  /// ```
  JsonNumber operator /(JsonNumber other) => JsonNumber(value / other.value);

  /// Returns the remainder of dividing this number by [other].
  ///
  /// Example:
  /// ```dart
  /// final a = JsonNumber(5);
  /// final b = JsonNumber(2);
  /// print((a % b).value); // 1
  /// ```
  JsonNumber operator %(JsonNumber other) => JsonNumber(value % other.value);

  /// Unary negation: returns the negative of this number.
  ///
  /// Example:
  /// ```dart
  /// final a = JsonNumber(5);
  /// print((-a).value); // -5
  /// ```
  JsonNumber operator -() => JsonNumber(-value);

  /// Truncating integer division of this number by [other].
  ///
  /// Example:
  /// ```dart
  /// final a = JsonNumber(5);
  /// final b = JsonNumber(2);
  /// print((a ~/ b).value); // 2
  /// ```
  JsonNumber operator ~/(JsonNumber other) => JsonNumber(value ~/ other.value);

  /// Less-than comparison; returns [JsonBoolean].
  ///
  /// Example:
  /// ```dart
  /// final a = JsonNumber(5);
  /// final b = JsonNumber(2);
  /// print((b < a).value); // true
  /// ```
  JsonBoolean operator <(JsonNumber other) => JsonBoolean(value < other.value);

  /// Greater-than comparison; returns [JsonBoolean].
  ///
  /// Example:
  /// ```dart
  /// final a = JsonNumber(5);
  /// final b = JsonNumber(2);
  /// print((a > b).value); // true
  /// ```
  JsonBoolean operator >(JsonNumber other) => JsonBoolean(value > other.value);

  /// Less-than-or-equal comparison; returns [JsonBoolean].
  ///
  /// Example:
  /// ```dart
  /// final a = JsonNumber(5);
  /// final b = JsonNumber(5);
  /// print((a <= b).value); // true
  /// ```
  JsonBoolean operator <=(JsonNumber other) =>
      JsonBoolean(value <= other.value);

  /// Greater-than-or-equal comparison; returns [JsonBoolean].
  ///
  /// Example:
  /// ```dart
  /// final a = JsonNumber(5);
  /// final b = JsonNumber(2);
  /// print((a >= b).value); // true
  /// ```
  JsonBoolean operator >=(JsonNumber other) =>
      JsonBoolean(value >= other.value);

  /// Converts this number to a [JsonString].
  @override
  JsonString get asString => JsonString(value.toString());

  /// Returns the raw numeric value for JSON encoding.
  ///
  /// Example:
  /// ```dart
  /// print(JsonNumber(7).toEncodeable()); // 7
  /// ```
  @override
  Object toEncodeable() => value;
}

/// Represents a JSON boolean and provides boolean operators.
class JsonBoolean extends AbstractJsonValue {
  /// The wrapped boolean value.
  @override
  final bool value;

  /// Creates a JSON boolean wrapper for [value].
  ///
  /// Example:
  /// ```dart
  /// const t = JsonBoolean(true);
  /// print(t.value); // true
  /// print(t.toEncodeable()); // true
  /// ```
  const JsonBoolean(this.value);

  /// Logical AND with [other]; returns [JsonBoolean].
  ///
  /// Example:
  /// ```dart
  /// final t = JsonBoolean(true);
  /// final f = JsonBoolean(false);
  /// print((t & f).value); // false
  /// ```
  JsonBoolean operator &(JsonBoolean other) => JsonBoolean(value & other.value);

  /// Logical OR with [other]; returns [JsonBoolean].
  ///
  /// Example:
  /// ```dart
  /// final t = JsonBoolean(true);
  /// final f = JsonBoolean(false);
  /// print((t | f).value); // true
  /// ```
  JsonBoolean operator |(JsonBoolean other) => JsonBoolean(value | other.value);

  /// Logical XOR with [other]; returns [JsonBoolean].
  ///
  /// Example:
  /// ```dart
  /// final t = JsonBoolean(true);
  /// final f = JsonBoolean(false);
  /// print((t ^ f).value); // true
  /// ```
  JsonBoolean operator ^(JsonBoolean other) => JsonBoolean(value ^ other.value);

  /// Logical NOT of this boolean.
  ///
  /// Example:
  /// ```dart
  /// final t = JsonBoolean(true);
  /// print((~t).value); // false
  /// ```
  JsonBoolean operator ~() => JsonBoolean(!value);

  /// Converts this boolean to a [JsonString].
  @override
  JsonString get asString => JsonString(value.toString());

  /// Returns the raw boolean for JSON encoding.
  ///
  /// Example:
  /// ```dart
  /// print(JsonBoolean(false).toEncodeable()); // false
  /// ```
  @override
  Object toEncodeable() => value;
}

/// Represents a JSON array of optional [JsonValue] elements.
///
/// The underlying list may contain `null` entries to mirror JSON semantics.
/// Implements [Iterable] so you can iterate over elements directly.
///
/// Example:
/// ```dart
/// final arr = JsonArray([1.json, null, 'x'.json]);
/// print(arr[0]!.asNumber.value); // 1
/// print(arr.toEncodeable()); // [1, null, "x"]
/// ```
class JsonArray extends AbstractJsonValue with Iterable<JsonValue?> {
  /// The wrapped list of optional JSON values.
  @override
  final List<JsonValue?> value;

  /// Creates a JSON array wrapper for [value].
  ///
  /// Example:
  /// ```dart
  /// final a = JsonArray([1.json, 2.json, null]);
  /// print(a.length); // 3
  /// ```
  const JsonArray(this.value);

  /// Copies elements from another [JsonArray].
  ///
  /// Example:
  /// ```dart
  /// final a = JsonArray([1.json]);
  /// final b = JsonArray.of(a);
  /// print(b[0]!.asNumber.value); // 1
  /// ```
  JsonArray.of(JsonArray other) : value = List.of(other.value);

  /// Wraps a Dart [elements] iterable into a [JsonArray], converting
  /// non-null elements to [JsonValue] recursively.
  ///
  /// Example:
  /// ```dart
  /// final a = JsonArray.wrap([1, null, 'x']);
  /// print(a[2]!.asString.value); // x
  /// ```
  JsonArray.wrap(Iterable<Object?> elements)
      : value = elements.map((e) => e == null ? null : JsonValue(e)).toList();

  /// Appends [element] to the array (may be `null`).
  ///
  /// Example:
  /// ```dart
  /// final a = JsonArray([]);
  /// a.add(1.json);
  /// print(a.length); // 1
  /// ```
  void add(JsonValue? element) {
    value.add(element);
  }

  /// Appends all [elements] to the array.
  ///
  /// Example:
  /// ```dart
  /// final a = JsonArray([]);
  /// a.addAll([1.json, null, 'x'.json]);
  /// print(a.length); // 3
  /// ```
  void addAll(Iterable<JsonValue?> elements) {
    value.addAll(elements);
  }

  /// Whether this array contains [element] (including `null`).
  ///
  /// Example:
  /// ```dart
  /// final a = JsonArray([1.json, null]);
  /// print(a.containsElement(null)); // true
  /// ```
  bool containsElement(JsonValue? element) {
    return value.contains(element);
  }

  /// Returns an iterator over elements.
  @override
  Iterator<JsonValue?> get iterator => value.iterator;

  /// Removes the first occurrence of [element]. Returns `true` if removed.
  ///
  /// Example:
  /// ```dart
  /// final a = JsonArray([1.json, 2.json, 1.json]);
  /// print(a.remove(1.json)); // true
  /// print(a.length); // 2
  /// ```
  bool remove(JsonValue? element) {
    return value.remove(element);
  }

  /// Returns the element at [index] (may be `null`).
  ///
  /// Example:
  /// ```dart
  /// final a = JsonArray([null, 'x'.json]);
  /// print(a[1]!.asString.value); // x
  /// ```
  JsonValue? operator [](int index) {
    return value[index];
  }

  /// Replaces the element at [index] with [value] (may be `null`).
  ///
  /// Example:
  /// ```dart
  /// final a = JsonArray(['x'.json]);
  /// a[0] = 'y'.json;
  /// print(a[0]!.asString.value); // y
  /// ```
  void operator []=(int index, JsonValue? value) {
    this.value[index] = value;
  }

  /// Returns a map view of indices to elements.
  ///
  /// Example:
  /// ```dart
  /// final a = JsonArray(['x'.json]);
  /// print(a.asMap()); // {0: JsonString("x")}
  /// ```
  Map<int, JsonValue?> asMap() {
    return Map.fromIterables(Iterable<int>.generate(value.length), value);
  }

  /// Removes all elements from the array.
  ///
  /// Example:
  /// ```dart
  /// final a = JsonArray(['x'.json]);
  /// a.clear();
  /// print(a.length); // 0
  /// ```
  void clear() {
    value.clear();
  }

  /// Inserts [element] at [index].
  ///
  /// Example:
  /// ```dart
  /// final a = JsonArray(['b'.json]);
  /// a.insert(0, 'a'.json);
  /// print(a[0]!.asString.value); // a
  /// ```
  void insert(int index, JsonValue? element) {
    value.insert(index, element);
  }

  /// Inserts all [elements] starting at [index].
  ///
  /// Example:
  /// ```dart
  /// final a = JsonArray(['a'.json]);
  /// a.insertAll(1, ['b'.json, 'c'.json]);
  /// print(a.length); // 3
  /// ```
  void insertAll(int index, Iterable<JsonValue?> elements) {
    value.insertAll(index, elements);
  }

  /// Removes all occurrences of any element in [elements]. Returns whether
  /// at least one removal happened.
  ///
  /// Example:
  /// ```dart
  /// final a = JsonArray(['x'.json, 'y'.json, 'x'.json]);
  /// print(a.removeAll(['x'.json])); // true
  /// print(a.length); // 1
  /// ```
  bool removeAll(Iterable<JsonValue?> elements) {
    bool removed = false;
    for (var element in elements) {
      removed = value.remove(element) || removed;
    }
    return removed;
  }

  /// Removes and returns the element at [index].
  ///
  /// Example:
  /// ```dart
  /// final a = JsonArray(['x'.json]);
  /// print(a.removeAt(0)!.asString.value); // x
  /// ```
  JsonValue? removeAt(int index) {
    return value.removeAt(index);
  }

  /// Removes a range of elements `[start, end)`.
  ///
  /// Example:
  /// ```dart
  /// final a = JsonArray(['a'.json, 'b'.json, 'c'.json]);
  /// a.removeRange(0, 2);
  /// print(a.length); // 1
  /// ```
  void removeRange(int start, int end) {
    value.removeRange(start, end);
  }

  /// Removes all elements matching [test].
  ///
  /// Example:
  /// ```dart
  /// final a = JsonArray([1.json, 2.json, 3.json]);
  /// a.removeWhere((e) => e!.asNumber.intValue.isOdd);
  /// print(a.length); // 1
  /// ```
  void removeWhere(bool Function(JsonValue? element) test) {
    value.removeWhere(test);
  }

  /// Removes and returns the last element.
  ///
  /// Example:
  /// ```dart
  /// final a = JsonArray(['x'.json, 'y'.json]);
  /// print(a.removeLast()!.asString.value); // y
  /// ```
  JsonValue? removeLast() {
    return value.removeLast();
  }

  /// Converts to a JSON-encodeable list by unwrapping elements.
  @override
  Object toEncodeable() => value.map((e) => e?.toEncodeable()).toList();

  @override
  String toString() => value.toString();
}

/// Represents a JSON object keyed by strings with optional [JsonValue] values.
///
/// Provides various convenience methods for mutation and querying, and can
/// leverage [JsonRegistry] to (de)serialize custom object graphs via
/// [toEncodeable] and [asType].
///
/// Example:
/// ```dart
/// final obj = JsonObject({'a': 1.json, 'b': null});
/// print(obj['a']!.asNumber.value); // 1
/// ```
class JsonObject extends AbstractJsonValue
    with Iterable<MapEntry<String, JsonValue?>> {
  /// The wrapped string-keyed map of optional JSON values.
  @override
  final Map<String, JsonValue?> value;

  /// Creates a JSON object wrapper for [value].
  ///
  /// Example:
  /// ```dart
  /// final o = JsonObject({'a': 1.json});
  /// print(o['a']!.asNumber.value); // 1
  /// ```
  const JsonObject(this.value);

  /// Creates a [JsonObject] from [entries].
  ///
  /// Example:
  /// ```dart
  /// final o = JsonObject.fromEntries([
  ///   MapEntry('a', 1.json),
  ///   MapEntry('b', null),
  /// ]);
  /// print(o.keys.length); // 2
  /// ```
  JsonObject.fromEntries(Iterable<MapEntry<String, JsonValue?>> entries)
      : value = Map.fromEntries(entries);

  /// Copies entries from another [JsonObject].
  ///
  /// Example:
  /// ```dart
  /// final a = JsonObject({'x': 'y'.json});
  /// final b = JsonObject.of(a);
  /// print(b['x']!.asString.value); // y
  /// ```
  JsonObject.of(JsonObject other) : value = Map.of(other.value);

  /// Wraps a Dart map into a [JsonObject]. Null keys are ignored; keys are
  /// stringified with `toString()`, and non-null values are wrapped.
  ///
  /// Example:
  /// ```dart
  /// final o = JsonObject.wrap({1: 'a', 'b': null});
  /// print(o['1']!.asString.value); // a
  /// print(o['b'] == null); // true
  /// ```
  JsonObject.wrap(Map<Object?, Object?> map)
      : value = Map.fromEntries(
          map.entries.where((e) => e.key != null).map(
                (e) => MapEntry(
                  e.key.toString(),
                  e.value == null ? null : JsonValue(e.value!),
                ),
              ),
        );

  /// Wraps a sequence of entries into a [JsonObject], stringifying keys and
  /// wrapping values.
  ///
  /// Example:
  /// ```dart
  /// final o = JsonObject.wrapFromEntries([
  ///   MapEntry(1, 'a'),
  ///   MapEntry('b', null),
  /// ]);
  /// print(o['1']!.asString.value); // a
  /// print(o['b'] == null); // true
  /// ```
  JsonObject.wrapFromEntries(Iterable<MapEntry<Object?, Object?>> entries)
      : value = Map.fromEntries(
          entries.where((e) => e.key != null).map(
                (e) => MapEntry(
                  e.key.toString(),
                  e.value == null ? null : JsonValue(e.value!),
                ),
              ),
        );

  /// Returns an iterator over key/value pairs.
  @override
  Iterator<MapEntry<String, JsonValue?>> get iterator => value.entries.iterator;

  /// Gets a value by [key] if it’s a [String]; returns `null` otherwise.
  ///
  /// Example:
  /// ```dart
  /// final o = JsonObject({'a': 'b'.json});
  /// print(o['a']!.asString.value); // b
  /// print(o[1] == null); // true
  /// ```
  JsonValue? operator [](Object? key) {
    if (key is String) {
      return value[key];
    }
    return null;
  }

  /// Sets [key] to [value] (may be `null`).
  ///
  /// Example:
  /// ```dart
  /// final o = JsonObject({});
  /// o['a'] = 1.json;
  /// print(o['a']!.asNumber.value); // 1
  /// ```
  void operator []=(String key, JsonValue? value) {
    this.value[key] = value;
  }

  /// Removes all entries.
  ///
  /// Example:
  /// ```dart
  /// final o = JsonObject({'a': 1.json});
  /// o.clear();
  /// print(o.keys.isEmpty); // true
  /// ```
  void clear() {
    value.clear();
  }

  /// An iterable view of entries.
  Iterable<MapEntry<String, JsonValue?>> get entries => value.entries;

  /// An iterable view of keys.
  Iterable<String> get keys => value.keys;

  /// Adds all entries from [other].
  ///
  /// Example:
  /// ```dart
  /// final o = JsonObject({'a': 1.json});
  /// o.putAll({'b': 2.json});
  /// print(o['b']!.asNumber.value); // 2
  /// ```
  void putAll(Map<String, JsonValue?> other) {
    value.addAll(other);
  }

  /// Adds all entries from [other].
  ///
  /// Example:
  /// ```dart
  /// final o = JsonObject({});
  /// o.putAllEntries([
  ///   MapEntry('a', 1.json),
  ///   MapEntry('b', null),
  /// ]);
  /// print(o.keys.length); // 2
  /// ```
  void putAllEntries(Iterable<MapEntry<String, JsonValue?>> other) {
    for (var entry in other) {
      value[entry.key] = entry.value;
    }
  }

  /// Removes [key] and returns the previous value (which may be `null`).
  ///
  /// Example:
  /// ```dart
  /// final o = JsonObject({'a': 'x'.json});
  /// print(o.remove('a')!.asString.value); // x
  /// print(o.containsKey('a')); // false
  /// ```
  JsonValue? remove(String key) {
    return value.remove(key);
  }

  /// Removes all entries for which [test] returns `true`.
  ///
  /// Example:
  /// ```dart
  /// final o = JsonObject({'a': 1.json, 'b': 2.json});
  /// o.removeWhere((k, v) => k == 'a');
  /// print(o.containsKey('a')); // false
  /// ```
  void removeWhere(bool Function(String key, JsonValue? value) test) {
    value.removeWhere(test);
  }

  /// An iterable view of values.
  Iterable<JsonValue?> get values => value.values;

  /// Inserts a value computed by [ifAbsent] if [key] is not present.
  ///
  /// Example:
  /// ```dart
  /// final o = JsonObject({});
  /// o.putIfAbsent('a', () => 1.json);
  /// print(o['a']!.asNumber.value); // 1
  /// ```
  JsonValue? putIfAbsent(String key, JsonValue? Function() ifAbsent) {
    return value.putIfAbsent(key, ifAbsent);
  }

  /// Updates the value at [key] using [update], or inserts [ifAbsent] if
  /// provided and the key is missing.
  ///
  /// Example:
  /// ```dart
  /// final o = JsonObject({'a': 1.json});
  /// o.update('a', (v) => 2.json);
  /// print(o['a']!.asNumber.value); // 2
  /// ```
  JsonValue? update(
    String key,
    JsonValue? Function(JsonValue? value) update, {
    JsonValue? Function()? ifAbsent,
  }) {
    return value.update(key, update, ifAbsent: ifAbsent);
  }

  /// Updates all entries using [update].
  ///
  /// Example:
  /// ```dart
  /// final o = JsonObject({'a': 1.json, 'b': 2.json});
  /// o.updateAll((k, v) => 0.json);
  /// print(o.values.whereType<JsonValue>().length); // 2
  /// ```
  void updateAll(JsonValue? Function(String key, JsonValue? value) update) {
    value.updateAll(update);
  }

  /// Whether this object contains [key].
  ///
  /// Example:
  /// ```dart
  /// final o = JsonObject({'a': null});
  /// print(o.containsKey('a')); // true
  /// ```
  bool containsKey(Object? key) {
    return value.containsKey(key);
  }

  /// Whether this object contains [value] among its values.
  ///
  /// Example:
  /// ```dart
  /// final o = JsonObject({'a': 'x'.json});
  /// print(o.containsValue('x'.json)); // true
  /// ```
  bool containsValue(Object? value) {
    return this.value.containsValue(value);
  }

  /// Converts to an encodeable map. If a [JsonRegistry] is able to deserialize
  /// this object into a custom Dart type, that value is returned instead.
  ///
  /// Example:
  /// ```dart
  /// final o = JsonObject({'a': 1.json});
  /// print(o.toEncodeable()); // {a: 1}
  /// ```
  @override
  Object toEncodeable() {
    Object? result = JsonRegistry.findAndDeserialize(this);
    return result ?? value.map((k, v) => MapEntry(k, v?.toEncodeable()));
  }

  /// Converts this JSON object to a Dart type [T] using [registry] (or the
  /// current registry on the stack). Throws [Exception] if conversion fails.
  ///
  /// See also: [JsonValue.asType]
  @override
  T asType<T>({JsonRegistry? registry}) {
    Object? result = JsonRegistry.findAndDeserialize(this, registry: registry);
    if (result is T) {
      return result;
    }
    throw Exception('Cannot convert $this to $T');
  }

  @override
  String toString() {
    return value.toString();
  }
}
