import 'dart:convert';

import 'package:tson/tson.dart';

/// Internal raw wrappers that preserve original Dart structures and parse
/// lazily.
///
/// Usage goes through [JsonValue.unsafe]; everything else here is private and
/// created via the `as*` getters on [RawJsonValue]. Key behaviors:
/// - Top-level value must be non-null; nulls are allowed inside lists/maps and
///   are preserved.
/// - Numbers and booleans parse lazily when their `value` getter is accessed;
///   invalid content throws [FormatException] at that point.
/// - Lists and maps are kept as-is; elements/values are wrapped lazily on
///   access. Mutations store raw values back into the underlying list/map.
/// - [toEncodeable] returns the underlying raw value without deep
///   transformation; [toJson] uses `jsonEncode` on that value.
/// - [asArray]/[asObject] assert the backing type; [asObject] stringifies
///   non-string keys and ignores null keys.
///
/// See also: [JsonValue.unsafe].
class RawJsonValue implements JsonValue {
  /// The underlying raw value (String/num/bool/List/Map or any object).
  @override
  final Object value;

  /// Creates a new raw wrapper for [value]. Must be non-null.
  RawJsonValue(this.value);

  /// Returns this value as a raw array wrapper.
  ///
  /// Asserts if the underlying value is not a [List]. Elements are wrapped
  /// lazily when accessed; nulls are preserved.
  @override
  JsonArray get asArray {
    assert(
        value is List, 'Expected List for asArray, got ${value.runtimeType}');
    return _RawJsonArray((value as List).cast<Object?>());
  }

  /// Returns this value as a boolean wrapper.
  ///
  /// Parsing is lazy and happens when the boolean wrapper's `value` is read.
  @override
  JsonBoolean get asBoolean => _RawJsonBoolean(value);

  /// Returns this value as a number wrapper.
  ///
  /// Accepts numeric values or numeric strings; parsing is lazy and happens
  /// when the number wrapper's `value` is read.
  @override
  JsonNumber get asNumber => _RawJsonNumber(value);

  /// Returns this value as a raw object wrapper.
  ///
  /// Asserts if the underlying value is not a [Map]. Non-string keys are
  /// stringified and null keys are ignored.
  @override
  JsonObject get asObject {
    assert(value is Map, 'Expected Map for asObject, got ${value.runtimeType}');
    final map = (value as Map);
    final coerced = <String, Object?>{};
    for (final entry in map.entries) {
      if (entry.key == null) continue;
      coerced[entry.key.toString()] = entry.value;
    }
    return _RawJsonObject(coerced);
  }

  /// Returns this value as a string wrapper.
  ///
  /// Strings are exposed as-is; other types are viewed via `toString()`.
  @override
  JsonString get asString {
    return _RawJsonString(value);
  }

  /// Converts the raw JSON object to a Dart type [T] via [JsonRegistry].
  ///
  /// Coerces this value to an object view and asks the active registry (or the
  /// provided one) to deserialize. Throws [Exception] if deserialization fails.
  @override
  T asType<T>({JsonRegistry? registry}) {
    // Coerce to a JsonObject-like view then delegate to registry.
    final obj = asObject;
    final result = JsonRegistry.findAndDeserialize(obj, registry: registry);
    if (result is T) return result;
    throw Exception('Cannot convert $this to $T');
  }

  /// Returns the underlying raw object for JSON encoding, without deep copy.
  @override
  Object toEncodeable() => value;

  /// Encodes this value using `jsonEncode`.
  @override
  String toJson() => jsonEncode(toEncodeable());

  @override
  String toString() => value.toString();
}

/// Internal raw variant of [JsonString] that keeps the original string
/// untouched and offers light conversions.
class _RawJsonString extends RawJsonValue implements JsonString {
  /// Creates a raw string wrapper.
  _RawJsonString(super.value);

  /// The string value.
  @override
  String get value => super.value.toString();

  /// Attempts to parse to [JsonBoolean]; returns null if not "true"/"false".
  @override
  JsonBoolean? get maybeAsBoolean {
    final s = value.toLowerCase();
    if (s == 'true') return JsonBoolean(true);
    if (s == 'false') return JsonBoolean(false);
    return null;
  }

  /// Attempts to parse to [JsonNumber]; returns null if parsing fails.
  @override
  JsonNumber? get maybeAsNumber {
    final n = num.tryParse(value);
    return n == null ? null : JsonNumber(n);
  }

  /// Splits by [delimiter] and returns a [JsonArray] of [JsonString] parts.
  @override
  JsonArray split(Pattern delimiter) {
    final parts = value.split(delimiter);
    return JsonArray(parts.map((e) => JsonString(e)).toList());
  }
}

/// Internal raw variant of [JsonNumber] with lazy parsing.
///
/// Accepts a num or a numeric string; parsing occurs only when `value`
/// is accessed. Operators delegate to `value` to ensure laziness.
class _RawJsonNumber extends RawJsonValue implements JsonNumber {
  num? _parsed;

  /// Accepts a num or numeric string.
  _RawJsonNumber(super.raw);

  static num _parse(Object raw) {
    if (raw is num) return raw;
    final s = raw.toString();
    final n = num.tryParse(s);
    if (n == null) {
      throw FormatException('Cannot parse "$raw" as number');
    }
    return n;
  }

  /// The numeric value, parsed lazily from [super.value] on first access.
  @override
  num get value {
    final cached = _parsed;
    if (cached != null) return cached;
    final parsed = _parse(super.value);
    _parsed = parsed;
    return parsed;
  }

  @override
  double get doubleValue => value.toDouble();

  @override
  int get intValue => value.toInt();

  // Arithmetic operators
  @override
  JsonNumber operator +(JsonNumber other) => JsonNumber(value + other.value);
  @override
  JsonNumber operator -(JsonNumber other) => JsonNumber(value - other.value);
  @override
  JsonNumber operator *(JsonNumber other) => JsonNumber(value * other.value);
  @override
  JsonNumber operator /(JsonNumber other) => JsonNumber(value / other.value);
  @override
  JsonNumber operator %(JsonNumber other) => JsonNumber(value % other.value);
  @override
  JsonNumber operator -() => JsonNumber(-value);
  @override
  JsonNumber operator ~/(JsonNumber other) => JsonNumber(value ~/ other.value);

  // Comparisons
  @override
  JsonBoolean operator <(JsonNumber other) => JsonBoolean(value < other.value);
  @override
  JsonBoolean operator >(JsonNumber other) => JsonBoolean(value > other.value);
  @override
  JsonBoolean operator <=(JsonNumber other) =>
      JsonBoolean(value <= other.value);
  @override
  JsonBoolean operator >=(JsonNumber other) =>
      JsonBoolean(value >= other.value);

  @override
  JsonString get asString => JsonString(value.toString());

  @override
  Object toEncodeable() => value;
}

/// Internal raw variant of [JsonBoolean] with lazy parsing.
///
/// Accepts a bool or a string "true"/"false" (case-insensitive). Parsing
/// occurs only when `value` is accessed. Operators delegate to `value`.
class _RawJsonBoolean extends RawJsonValue implements JsonBoolean {
  bool? _parsed;

  /// Accepts a bool or a string "true"/"false" (case-insensitive).
  _RawJsonBoolean(super.raw);

  static bool _parse(Object raw) {
    if (raw is bool) return raw;
    final s = raw.toString().toLowerCase();
    if (s == 'true') return true;
    if (s == 'false') return false;
    throw FormatException('Cannot parse "$raw" as boolean');
  }

  /// The boolean value, parsed lazily from [super.value] on first access.
  @override
  bool get value {
    final cached = _parsed;
    if (cached != null) return cached;
    final parsed = _parse(super.value);
    _parsed = parsed;
    return parsed;
  }

  @override
  JsonBoolean operator &(JsonBoolean other) => JsonBoolean(value & other.value);
  @override
  JsonBoolean operator |(JsonBoolean other) => JsonBoolean(value | other.value);
  @override
  JsonBoolean operator ^(JsonBoolean other) => JsonBoolean(value ^ other.value);
  @override
  JsonBoolean operator ~() => JsonBoolean(!value);

  @override
  JsonString get asString => JsonString(value.toString());

  @override
  Object toEncodeable() => value;
}

/// Internal raw variant of [JsonArray] backed by a `List<Object?>`.
///
/// Indexing and iteration wrap elements lazily (preserving nulls). Mutations
/// store back raw values. [toEncodeable] returns the underlying list.
class _RawJsonArray extends AbstractJsonValue
    with Iterable<JsonValue?>
    implements JsonArray {
  final List<Object?> _value;

  /// Creates a raw array wrapper from a list of objects.
  _RawJsonArray(this._value);

  /// Lazily wrapped view of the underlying list.
  @override
  List<JsonValue?> get value => List<JsonValue?>.unmodifiable(
        _value.map(
            (e) => e is JsonValue ? e : (e == null ? null : RawJsonValue(e))),
      );

  @override
  Iterator<JsonValue?> get iterator => value.iterator;

  @override
  JsonValue? operator [](int index) {
    final v = _value[index];
    return v is JsonValue ? v : (v == null ? null : RawJsonValue(v));
  }

  @override
  void operator []=(int index, JsonValue? value) {
    _value[index] = value is RawJsonValue ? value.value : value?.toEncodeable();
  }

  @override
  void add(JsonValue? element) {
    _value
        .add(element is RawJsonValue ? element.value : element?.toEncodeable());
  }

  @override
  void addAll(Iterable<JsonValue?> elements) {
    _value.addAll(
        elements.map((e) => e is RawJsonValue ? e.value : e?.toEncodeable()));
  }

  @override
  bool containsElement(JsonValue? element) {
    final probe =
        element is RawJsonValue ? element.value : element?.toEncodeable();
    return _value.contains(probe);
  }

  @override
  bool remove(JsonValue? element) {
    final probe =
        element is RawJsonValue ? element.value : element?.toEncodeable();
    return _value.remove(probe);
  }

  @override
  Map<int, JsonValue?> asMap() {
    return Map.fromIterables(
      Iterable<int>.generate(_value.length),
      _value.map(
          (e) => e is JsonValue ? e : (e == null ? null : RawJsonValue(e))),
    );
  }

  @override
  void clear() => _value.clear();

  @override
  void insert(int index, JsonValue? element) {
    _value.insert(index,
        element is RawJsonValue ? element.value : element?.toEncodeable());
  }

  @override
  void insertAll(int index, Iterable<JsonValue?> elements) {
    _value.insertAll(index,
        elements.map((e) => e is RawJsonValue ? e.value : e?.toEncodeable()));
  }

  @override
  bool removeAll(Iterable<JsonValue?> elements) {
    bool removed = false;
    for (final e in elements) {
      final probe = e is RawJsonValue ? e.value : e?.toEncodeable();
      removed = _value.remove(probe) || removed;
    }
    return removed;
  }

  @override
  JsonValue? removeAt(int index) {
    final v = _value.removeAt(index);
    return v is JsonValue ? v : (v == null ? null : RawJsonValue(v));
  }

  @override
  JsonValue? removeLast() {
    final v = _value.removeLast();
    return v is JsonValue ? v : (v == null ? null : RawJsonValue(v));
  }

  @override
  void removeRange(int start, int end) => _value.removeRange(start, end);

  @override
  void removeWhere(bool Function(JsonValue? element) test) {
    _value.removeWhere(
        (e) => test(e is JsonValue ? e : (e == null ? null : RawJsonValue(e))));
  }

  @override
  Object toEncodeable() => _value;

  @override
  String toJson() => jsonEncode(toEncodeable());
}

// Returns raw objects
/// Internal raw variant of [JsonObject] backed by a `Map<String, Object?>`.
///
/// Keys are strings (coerced in [RawJsonValue.asObject]); values are wrapped
/// lazily and mutations store raw values. [toEncodeable] returns the map.
class _RawJsonObject extends AbstractJsonValue
    with Iterable<MapEntry<String, JsonValue?>>
    implements JsonObject {
  final Map<String, Object?> _value;

  /// Creates a raw object wrapper from a string-keyed map.
  _RawJsonObject(this._value);

  @override
  Map<String, JsonValue?> get value => Map<String, JsonValue?>.fromEntries(
        _value.entries.map((e) => MapEntry(
              e.key,
              e.value is JsonValue
                  ? e.value as JsonValue
                  : (e.value == null ? null : RawJsonValue(e.value!)),
            )),
      );

  @override
  Iterator<MapEntry<String, JsonValue?>> get iterator => value.entries.iterator;

  @override
  JsonValue? operator [](Object? key) {
    if (key is! String) return null;
    final v = _value[key];
    return v is JsonValue ? v : (v == null ? null : RawJsonValue(v));
  }

  @override
  void operator []=(String key, JsonValue? value) {
    _value[key] = value is RawJsonValue ? value.value : value?.toEncodeable();
  }

  @override
  void clear() => _value.clear();

  @override
  Iterable<MapEntry<String, JsonValue?>> get entries => value.entries;

  @override
  Iterable<String> get keys => _value.keys;

  @override
  void putAll(Map<String, JsonValue?> other) {
    _value.addAll(other.map((k, v) =>
        MapEntry(k, v is RawJsonValue ? v.value : v?.toEncodeable())));
  }

  @override
  void putAllEntries(Iterable<MapEntry<String, JsonValue?>> other) {
    for (final e in other) {
      final v = e.value;
      _value[e.key] = v is RawJsonValue ? v.value : v?.toEncodeable();
    }
  }

  @override
  JsonValue? remove(String key) {
    final v = _value.remove(key);
    return v is JsonValue ? v : (v == null ? null : RawJsonValue(v));
  }

  @override
  void removeWhere(bool Function(String key, JsonValue? value) test) {
    final toRemove = <String>[];
    _value.forEach((k, v) {
      final wrapped = v is JsonValue ? v : (v == null ? null : RawJsonValue(v));
      if (test(k, wrapped)) toRemove.add(k);
    });
    for (final k in toRemove) {
      _value.remove(k);
    }
  }

  @override
  Iterable<JsonValue?> get values => _value.values
      .map((v) => v is JsonValue ? v : (v == null ? null : RawJsonValue(v)));

  @override
  JsonValue? putIfAbsent(String key, JsonValue? Function() ifAbsent) {
    final existing = _value[key];
    if (existing != null || _value.containsKey(key)) {
      return existing is JsonValue
          ? existing
          : (existing == null ? null : RawJsonValue(existing));
    }
    final v = ifAbsent();
    _value[key] = v is RawJsonValue ? v.value : v?.toEncodeable();
    return v;
  }

  @override
  JsonValue? update(
    String key,
    JsonValue? Function(JsonValue? value) update, {
    JsonValue? Function()? ifAbsent,
  }) {
    if (_value.containsKey(key)) {
      final current = _value[key];
      final newVal = update(current is JsonValue
          ? current
          : (current == null ? null : RawJsonValue(current)));
      _value[key] =
          newVal is RawJsonValue ? newVal.value : newVal?.toEncodeable();
      return newVal;
    }
    if (ifAbsent != null) {
      final v = ifAbsent();
      _value[key] = v is RawJsonValue ? v.value : v?.toEncodeable();
      return v;
    }
    throw ArgumentError('Key not found: $key');
  }

  @override
  void updateAll(JsonValue? Function(String key, JsonValue? value) update) {
    _value.updateAll((k, v) {
      final updated =
          update(k, v is JsonValue ? v : (v == null ? null : RawJsonValue(v)));
      return updated is RawJsonValue ? updated.value : updated?.toEncodeable();
    });
  }

  @override
  bool containsKey(Object? key) => key is String && _value.containsKey(key);

  @override
  bool containsValue(Object? value) {
    // Accept either a JsonValue (unwrap) or a raw value for comparison.
    final probe = value is RawJsonValue
        ? value.value
        : value is JsonValue
            ? value.toEncodeable()
            : value;
    return _value.containsValue(probe);
  }

  @override
  Object toEncodeable() => _value;

  @override
  String toJson() => jsonEncode(toEncodeable());

  @override
  T asType<T>({JsonRegistry? registry}) {
    final result = JsonRegistry.findAndDeserialize(this, registry: registry);
    if (result is T) return result;
    throw Exception('Cannot convert $this to $T');
  }
}
