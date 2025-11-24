## 1.0.2

- Deprecated `explicitNulls` in `JsonBuilder` in favor of using
  `JsonEncoderOptions`.
- Deprecated `indent` in `JsonBuilder` in favor of using `JsonEncoderOptions`.
- Added `options` parameter to `build` extension method to allow passing
  `JsonEncoderOptions`.
- Added `JsonEncoderOptions` to configure JSON encoding options in a more
  structured way.
- Added `options` parameter to `toJson` methods to allow passing
  `JsonEncoderOptions`.
- No longer eliminate null in JsonArray if `explicitNulls` is true.

## 1.0.1

- Added extension to serialize object as json

## 1.0.0

- Initial version.
