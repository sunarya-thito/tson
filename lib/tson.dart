/// A lightweight JSON object model with registry-based (de)serialization.
///
/// This library provides:
/// - Typed wrappers around JSON values ([JsonString], [JsonNumber],
///   [JsonBoolean], [JsonArray], [JsonObject]).
/// - Extensions for ergonomic construction and pretty building.
/// - A pluggable [JsonRegistry] with [JsonObjectParser] strategies for custom
///   types.
library;

export 'src/object.dart';
export 'src/extension.dart';
export 'src/encoder.dart';
export 'src/registry.dart';
// raw.dart is intentionally not exported; use JsonValue.unsafe(...) instead.
