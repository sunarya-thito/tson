import 'package:typeson/typeson.dart';

/// Function that converts an instance of [T] into a [JsonObject].
///
/// Parameters:
/// - [object]: The instance to serialize.
///
/// Returns: A [JsonObject] representing the object's data.
typedef JsonObjectEncoder<T> = JsonObject Function(T object);

/// Function that converts a [JsonObject] into an instance of [T].
///
/// Parameters:
/// - [json]: The JSON object holding the data for [T].
///
/// Returns: A new instance of [T].
typedef JsonObjectDecoder<T> = T Function(JsonObject json);

/// Predicate used by a registry entry to decide if it matches a given object.
///
/// Returns `true` if the entry should handle [object].
typedef JsonEntryPredicate = bool Function(Object? object);

/// Strategy interface for encoding and decoding objects in a [JsonRegistry].
///
/// Implementations determine how custom objects are represented as [JsonObject]
///s and how to recognize them when deserializing.
///
/// See also:
/// - [DefaultJsonObjectParser]
/// - [FlatTypeParser]
abstract interface class JsonObjectParser {
  /// Default envelope-based parser that uses `__type`/`__data`.
  static const JsonObjectParser defaultParser = DefaultJsonObjectParser();

  /// Flat structure parser using a configurable discriminator key (defaults to
  /// "$type"). This mirrors [defaultParser] but uses a flat layout.
  static const JsonObjectParser flatTypeParser = FlatTypeParser();

  /// Shorthand to construct the default parser.
  const factory JsonObjectParser() = DefaultJsonObjectParser;

  /// Converts a [json] object previously produced for [entry] back into
  /// the target Dart object type.
  Object fromJson(JsonObject json, JsonRegistryEntry entry);

  /// Converts a Dart [object] handled by [entry] into its [JsonObject]
  /// representation according to the parser's wire format.
  JsonObject toJson(Object object, JsonRegistryEntry entry);

  /// Returns `true` if this parser recognizes [json] as being encoded for
  /// [entry].
  bool canParse(JsonObject json, JsonRegistryEntry entry);
}

/// Default parser using an envelope with `__type` and `__data` keys.
class DefaultJsonObjectParser implements JsonObjectParser {
  const DefaultJsonObjectParser();
  @override

  /// Recognizes objects with `__type` and `__data`, matching the entry type.
  bool canParse(JsonObject json, JsonRegistryEntry entry) {
    return json.containsKey('__type') &&
        json.containsKey('__data') &&
        json['__type']!.asString.value == entry.type;
  }

  @override

  /// Extracts `__data` and delegates to the entry's deserializer.
  Object fromJson(JsonObject json, JsonRegistryEntry entry) {
    return entry.deserialize(json['__data']!.asObject);
  }

  @override

  /// Produces an envelope: {"__type": T, "__data": {...}}.
  JsonObject toJson(Object object, JsonRegistryEntry entry) {
    return JsonObject({
      '__type': entry.type.json,
      '__data': entry.serialize(object),
    });
  }
}

/// A JsonObjectParser that encodes objects using a flat structure with a
/// configurable type discriminator key instead of the default
/// {"__type": T, "__data": {...}} envelope.
///
/// Result shape: { "<typeKey>": "TypeName", ...dataFields }
class FlatTypeParser implements JsonObjectParser {
  /// The discriminator key that stores the entry's type identifier.
  final String typeKey;

  /// Creates a [FlatTypeParser].
  ///
  /// Parameters:
  /// - [typeKey]: The metadata key used to store the type name. Defaults to
  ///   `$type`.
  const FlatTypeParser({this.typeKey = r'$type'});

  @override

  /// Recognizes objects when [typeKey] equals the entry type.
  bool canParse(JsonObject json, JsonRegistryEntry entry) {
    final t = json[typeKey]?.asString.value;
    return t == entry.type;
  }

  @override

  /// Strips the [typeKey] and delegates to the entry deserializer.
  Object fromJson(JsonObject json, JsonRegistryEntry entry) {
    // Remove the type discriminator and pass the rest to the entry deserializer
    final filtered = Map<String, JsonValue?>.fromEntries(
      json.entries.where((e) => e.key != typeKey),
    );
    return entry.deserialize(JsonObject(filtered));
  }

  @override

  /// Inlines the entry payload along with [typeKey]:
  /// { [typeKey]: T, ...data }.
  JsonObject toJson(Object object, JsonRegistryEntry entry) {
    final data = entry.serialize(object as dynamic);
    return JsonObject({typeKey: entry.type.json, ...data.value});
  }
}

/// Describes how to (de)serialize and identify a particular custom Dart type.
abstract interface class JsonRegistryEntry<T> {
  /// Matches only when the runtime type is exactly [T].
  static bool exactType<T>(Object? object) {
    return object.runtimeType == T;
  }

  /// Matches when [object] is assignable to [T] (i.e. `object is T`).
  static bool assignableType<T>(Object? object) {
    return object is T;
  }

  const factory JsonRegistryEntry({
    required String type,
    required JsonObjectEncoder<T> serializer,
    required JsonObjectDecoder<T> deserializer,
    JsonEntryPredicate? check,
    JsonObjectParser? parser,
  }) = SimpleJsonRegistryEntry<T>;

  /// The logical type identifier used in wire formats.
  String get type;

  /// Whether this entry matches a given [object] for serialization.
  bool matches(Object object);

  /// Serializes [object] to a [JsonObject].
  JsonObject serialize(T object);

  /// Deserializes [json] back into [T].
  T deserialize(JsonObject json);

  /// Optional parser override for this entry; if null, the registry/parser
  /// defaults are used.
  JsonObjectParser? get parser;
}

/// Simple [JsonRegistryEntry] implementation with pluggable serializer,
/// deserializer, optional predicate [check] and optional [parser] override.
class SimpleJsonRegistryEntry<T> implements JsonRegistryEntry<T> {
  @override
  final String type;

  /// Function that produces the JSON object for [T].
  final JsonObjectEncoder<T> serializer;

  /// Function that reconstructs [T] from a JSON object.
  final JsonObjectDecoder<T> deserializer;

  /// Optional match predicate; if not provided, [exactType] is used.
  final JsonEntryPredicate? check;
  @override

  /// Optional entry-level parser override.
  final JsonObjectParser? parser;

  const SimpleJsonRegistryEntry({
    required this.type,
    required this.serializer,
    required this.deserializer,
    this.check,
    this.parser,
  });

  @override
  bool matches(Object object) {
    if (check != null) {
      return check!(object);
    }
    return JsonRegistryEntry.exactType<T>(object);
  }

  @override
  JsonObject serialize(T object) {
    return serializer(object);
  }

  @override
  T deserialize(JsonObject json) {
    return deserializer(json);
  }
}

class _RegistryStack {
  final List<JsonRegistry> _stack = [];

  void push(JsonRegistry registry) {
    _stack.add(registry);
  }

  JsonRegistry pop() {
    return _stack.removeLast();
  }

  JsonRegistry get current {
    assert(_stack.isNotEmpty, 'No JsonRegistry in the current Zone.');
    return _stack.last;
  }

  JsonRegistry? get maybeCurrent {
    if (_stack.isEmpty) return null;
    return _stack.last;
  }
}

/// A registry for custom object (de)serialization.
///
/// A [JsonRegistry] holds a set of [JsonRegistryEntry] definitions and a
/// default [JsonObjectParser]. When [serialize] is called, the registry finds
/// a matching entry and delegates to the parser to produce a [JsonValue].
/// Conversely, [deserialize] converts a [JsonValue] back to native Dart types
/// by letting the parser choose the appropriate entry.
///
/// Typical usage:
/// ```dart
/// final reg = JsonRegistry(entries: [
///   JsonRegistryEntry<MyType>(
///     type: 'MyType',
///     serializer: (t) => JsonObject.wrap({'x': t.x}),
///     deserializer: (j) => MyType(j['x']!.asNumber.intValue),
///   ),
/// ]);
/// final json = reg.serialize(MyType(1));
/// final obj = reg.deserialize(json);
/// ```
///
/// See also:
/// - [JsonRegistryEntry]
/// - [JsonObjectParser]
class JsonRegistry {
  static final _RegistryStack _stack = _RegistryStack();

  /// The current active registry on the internal stack.
  static JsonRegistry get currentRegistry {
    return _stack.current;
  }

  /// The current registry or `null` if none was pushed.
  static JsonRegistry? get maybeCurrentRegistry {
    return _stack.maybeCurrent;
  }

  /// Attempts to serialize [object] using [registry] (or the current one).
  /// Returns a [JsonValue] on success or `null` if no entry matches.
  static JsonValue? findAndSerialize(Object object, {JsonRegistry? registry}) {
    registry ??= maybeCurrentRegistry;
    if (registry == null) return null;
    for (final entry in registry.entries) {
      final parser =
          entry.parser ?? registry.parser ?? JsonObjectParser.defaultParser;
      if (entry.matches(object)) {
        return parser.toJson(object, entry);
      }
    }
    return null;
  }

  /// Attempts to deserialize [json] using [registry] (or the current one).
  /// Returns a Dart object on success or `null` if no entry can parse it.
  static Object? findAndDeserialize(
    JsonObject? json, {
    JsonRegistry? registry,
  }) {
    if (json == null) return null;
    registry ??= maybeCurrentRegistry;
    if (registry == null) return null;
    for (final entry in registry.entries) {
      final parser =
          entry.parser ?? registry.parser ?? JsonObjectParser.defaultParser;
      if (parser.canParse(json, entry)) {
        return parser.fromJson(json, entry);
      }
    }
    return null;
  }

  void _pushToStack() {
    _stack.push(this);
  }

  void _popFromStack() {
    final popped = _stack.pop();
    assert(identical(popped, this), 'JsonRegistry stack is corrupted.');
  }

  /// Optional parent registry for composition or lookup (reserved for future
  /// use).
  final JsonRegistry? parent;

  /// The default parser used when entries don't provide one.
  final JsonObjectParser? parser;

  /// Registered entries that drive (de)serialization.
  final List<JsonRegistryEntry<Object?>> entries;

  const JsonRegistry({this.parent, this.entries = const [], this.parser});

  /// Serializes a Dart [object] into a [JsonValue] using this registry.
  ///
  /// Implementation detail: temporarily pushes this registry to an internal
  /// stack so that nested custom types can also resolve against it.
  JsonValue serialize(Object object) {
    _pushToStack();
    JsonValue jsonValue = JsonValue(object);
    _popFromStack();

    return jsonValue;
  }

  /// Deserializes a [json] value back into a Dart object using this registry.
  ///
  /// Implementation detail: temporarily pushes this registry to an internal
  /// stack so that nested custom types can also resolve against it.
  Object deserialize(JsonValue json) {
    _pushToStack();
    Object deserialized = json.toEncodeable();
    _popFromStack();

    return deserialized;
  }
}
