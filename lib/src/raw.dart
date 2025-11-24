import 'package:collection/collection.dart';
import 'package:typeson/typeson.dart';

JsonValue? _wrapNullable(Object? object) {
  return object == null ? null : JsonValue.unsafe(object);
}

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
    return _RawJsonObject(value as Map);
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
  String toJson(
      {JsonEncoderOptions options = JsonEncoderOptions.compactWithNulls}) {
    final encodeable = toEncodeable();
    return (JsonBuilder(encodeable)..options = options).toString();
  }

  @override
  String toString() => value.toString();

  @override
  int get hashCode => value.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! JsonValue) return false;
    return other.value == value;
  }
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
  // assume that there is no JsonValue on this list
  final List<Object?> _value;

  /// Creates a raw array wrapper from a list of objects.
  _RawJsonArray(this._value);

  /// Lazily wrapped view of the underlying list.
  @override
  List<JsonValue?> get value =>
      List<JsonValue?>.unmodifiable(_value.map(_wrapNullable));

  @override
  Iterator<JsonValue?> get iterator => value.iterator;

  @override
  JsonValue? operator [](int index) {
    return _wrapNullable(_value[index]);
  }

  @override
  void operator []=(int index, JsonValue? value) {
    _value[index] = value;
  }

  @override
  void add(JsonValue? element) {
    _value.add(element);
  }

  @override
  void addAll(Iterable<JsonValue?> elements) {
    _value.addAll(elements);
  }

  @override
  bool containsElement(JsonValue? element) {
    for (final e in _value) {
      if (_wrapNullable(e) == element) {
        return true;
      }
    }
    return false;
  }

  @override
  bool remove(JsonValue? element) {
    bool removed = false;
    for (int i = 0; i < _value.length; i++) {
      if (_wrapNullable(_value[i]) == element) {
        _value.removeAt(i);
        removed = true;
        break;
      }
    }
    return removed;
  }

  @override
  Map<int, JsonValue?> asMap() {
    return Map.fromIterables(
      Iterable<int>.generate(_value.length),
      _value.map(_wrapNullable),
    );
  }

  @override
  void clear() => _value.clear();

  @override
  void insert(int index, JsonValue? element) {
    _value.insert(index, element);
  }

  @override
  void insertAll(int index, Iterable<JsonValue?> elements) {
    _value.insertAll(index, elements);
  }

  @override
  bool removeAll(Iterable<JsonValue?> elements) {
    bool removed = false;
    for (int i = _value.length - 1; i >= 0; i--) {
      if (elements.contains(_wrapNullable(_value[i]))) {
        _value.removeAt(i);
        removed = true;
      }
    }
    return removed;
  }

  @override
  JsonValue? removeAt(int index) {
    return _wrapNullable(_value.removeAt(index));
  }

  @override
  JsonValue? removeLast() {
    return _wrapNullable(_value.removeLast());
  }

  @override
  void removeRange(int start, int end) => _value.removeRange(start, end);

  @override
  void removeWhere(bool Function(JsonValue? element) test) {
    _value.removeWhere((e) => test(_wrapNullable(e)));
  }

  @override
  Object toEncodeable() =>
      _value.map((e) => _wrapNullable(e)?.toEncodeable()).toList();

  @override
  String toJson(
      {JsonEncoderOptions options = JsonEncoderOptions.compactWithNulls}) {
    final encodeable = toEncodeable();
    return (JsonBuilder(encodeable)..options = options).toString();
  }

  @override
  int get hashCode => const ListEquality().hash(value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! JsonArray) return false;
    return const ListEquality().equals(value, other.value);
  }
}

// Returns raw objects
/// Internal raw variant of [JsonObject] backed by a `Map<String, Object?>`.
///
/// Keys are strings (coerced in [RawJsonValue.asObject]); values are wrapped
/// lazily and mutations store raw values. [toEncodeable] returns the map.
class _RawJsonObject extends AbstractJsonValue
    with Iterable<MapEntry<String, JsonValue?>>
    implements JsonObject {
  // assume that there is no JsonValue on this map
  final Map<Object?, Object?> _rawMap;

  /// Accepts any Map; keys are coerced lazily when value is accessed.
  _RawJsonObject(this._rawMap);

  @override
  Map<String, JsonValue?> get value {
    // Lazily coerce keys to String and ignore null keys.
    return Map<String, JsonValue?>.fromEntries(
      _rawMap.entries.where((e) => e.key != null).map((e) => MapEntry(
            e.key.toString(),
            _wrapNullable(e.value),
          )),
    );
  }

  @override
  Iterator<MapEntry<String, JsonValue?>> get iterator => value.entries.iterator;

  @override
  JsonValue? operator [](Object? key) {
    if (key is! String) return null;
    for (final entry in _rawMap.entries) {
      if (entry.key.toString() == key) {
        return _wrapNullable(entry.value);
      }
    }
    return null;
  }

  @override
  void operator []=(String key, JsonValue? value) {
    _rawMap[key] = value;
  }

  @override
  void clear() => _rawMap.clear();

  @override
  Iterable<MapEntry<String, JsonValue?>> get entries => value.entries;

  @override
  Iterable<String> get keys =>
      _rawMap.keys.where((k) => k != null).map((k) => k.toString());

  @override
  void putAll(Map<String, JsonValue?> other) {
    for (final entry in other.entries) {
      final k = entry.key;
      final v = entry.value;
      _rawMap[k] = v;
    }
  }

  @override
  void putAllEntries(Iterable<MapEntry<String, JsonValue?>> other) {
    for (final e in other) {
      final k = e.key;
      final v = e.value;
      _rawMap[k] = v;
    }
  }

  @override
  JsonValue? remove(String key) {
    JsonValue? removed;
    _rawMap.removeWhere((k, v) {
      if (k.toString() == key) {
        removed = _wrapNullable(v);
        return true;
      }
      return false;
    });
    return removed;
  }

  @override
  void removeWhere(bool Function(String key, JsonValue? value) test) {
    _rawMap.removeWhere((k, v) {
      final wrapped = _wrapNullable(v);
      return test(k.toString(), wrapped);
    });
  }

  @override
  Iterable<JsonValue?> get values =>
      _rawMap.values.map((v) => _wrapNullable(v));

  @override
  JsonValue? putIfAbsent(String key, JsonValue? Function() ifAbsent) {
    JsonValue? existing;
    _rawMap.forEach((k, v) {
      if (k.toString() == key) {
        existing = _wrapNullable(v);
      }
    });
    if (existing != null) return existing;

    final v = ifAbsent();
    _rawMap[key] = v;
    return v;
  }

  @override
  JsonValue? update(
    String key,
    JsonValue? Function(JsonValue? value) update, {
    JsonValue? Function()? ifAbsent,
  }) {
    JsonValue? existing;
    _rawMap.forEach((k, v) {
      if (k.toString() == key) {
        existing = _wrapNullable(v);
      }
    });
    if (existing != null) {
      final newVal = update(existing);
      _rawMap[key] = newVal;
      return newVal;
    }
    if (ifAbsent != null) {
      final v = ifAbsent();
      _rawMap[key] = v;
      return v;
    }
    throw ArgumentError('Key not found: $key');
  }

  @override
  void updateAll(JsonValue? Function(String key, JsonValue? value) update) {
    _rawMap.forEach((k, v) {
      final newVal = update(k.toString(), _wrapNullable(v));
      _rawMap[k] = newVal;
    });
  }

  @override
  bool containsKey(Object? key) {
    for (final k in _rawMap.keys) {
      if (k.toString() == key) return true;
    }
    return false;
  }

  @override
  bool containsValue(Object? value) {
    for (final v in _rawMap.values) {
      if (_wrapNullable(v) == value) {
        return true;
      }
    }
    return false;
  }

  @override
  Object toEncodeable() => Map<String, Object?>.fromEntries(
        _rawMap.entries.where((e) => e.key != null).map((e) => MapEntry(
              e.key.toString(),
              _wrapNullable(e.value)?.toEncodeable(),
            )),
      );

  @override
  String toJson(
      {JsonEncoderOptions options = JsonEncoderOptions.compactWithNulls}) {
    final encodeable = toEncodeable();
    return (JsonBuilder(encodeable)..options = options).toString();
  }

  @override
  T asType<T>({JsonRegistry? registry}) {
    final result = JsonRegistry.findAndDeserialize(this, registry: registry);
    if (result is T) return result;
    throw Exception('Cannot convert $this to $T');
  }

  @override
  int get hashCode => const MapEquality().hash(value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! JsonObject) return false;
    return const MapEquality().equals(value, other.value);
  }
}
