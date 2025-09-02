/// Recursively removes null values from JSON-like structures.
///
/// This function traverses a value that is expected to be composed of
/// primitives (`String`, `num`, `bool`, `null`), `List`, and `Map`, and
/// eliminates properties whose value is `null` from maps, while preserving
/// `null` elements inside lists.
///
/// - If [value] is a `Map`, keys with `null` values are dropped from the
///   returned map. Nested lists/maps are processed recursively.
/// - If [value] is a `List`, elements are processed recursively, but existing
///   `null` list elements are retained in their positions.
/// - For any other type, the value is returned unchanged.
///
/// Examples:
/// ```dart
/// final input = {
///   'a': 1,
///   'b': null,            // removed
///   'c': [1, null, {'x': null, 'y': 2}], // list null kept; map null removed
/// };
/// final out = eliminateNull(input) as Map<Object?, Object?>;
/// // out == {'a': 1, 'c': [1, null, {'y': 2}]}
/// ```
///
/// Returns a new structure; the input [value] is not mutated.
Object? eliminateNull(Object? value) {
  if (value is List) {
    return eliminateNullInList(value);
  } else if (value is Map) {
    return eliminateNullInMap(value);
  } else {
    return value;
  }
}

/// Maps each element of [list] using [eliminateNull].
///
/// - `null` elements in the list remain `null`.
/// - Non-collection values are returned as-is.
/// - Nested lists/maps are processed recursively.
///
/// The original [list] is not modified; a new list is returned.
List<Object?> eliminateNullInList(List<Object?> list) {
  return list.map(eliminateNull).toList();
}

/// Returns a new map with entries whose value is `null` removed.
///
/// Type parameter [U] is preserved from the input map's key type. Keys are
/// copied as-is; values are recursively processed with [eliminateNull].
///
/// Example:
/// ```dart
/// final result = eliminateNullInMap({'x': null, 'y': 1, 'z': {'a': null}});
/// // result == {'y': 1, 'z': {}}
/// ```
///
/// The original [map] is not modified; a new map is returned.
Map<U, Object?> eliminateNullInMap<U>(Map<U, Object?> map) {
  final result = <U, Object?>{};
  map.forEach((key, value) {
    final newValue = eliminateNull(value);
    if (newValue != null) {
      result[key] = newValue;
    }
  });
  return result;
}
