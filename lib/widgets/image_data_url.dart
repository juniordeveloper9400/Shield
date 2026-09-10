import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Shrinks a picked photo to a small JPEG `data:` URI — small enough to sit
/// in a Neon `text` column (`app.prescription.image`, `app.order_receipt.image`,
/// `app.wallet_card.receipt_image`, `app."order".bill_image`, …) and travel
/// over Neon's HTTP endpoint, and to render straight from an `<img src>` in
/// the app, the admin console, and the customer's own order detail screen.
///
/// A photo only has to be *readable*, not archival, so it is capped at
/// [maxEdge] px on its long side and re-encoded at [quality]. A phone photo
/// that lands at 3-5 MB comes down to roughly 100-250 KB.
///
/// Returns null when the bytes are not a decodable image. Runs the decode /
/// resize / encode on a background isolate so a large photo does not jank
/// whichever screen is uploading it.
Future<String?> compressImageDataUrl(
  Uint8List bytes, {
  int maxEdge = 1200,
  int quality = 62,
}) {
  return compute(
    _encode,
    _EncodeRequest(bytes: bytes, maxEdge: maxEdge, quality: quality),
  );
}

class _EncodeRequest {
  final Uint8List bytes;
  final int maxEdge;
  final int quality;

  const _EncodeRequest({
    required this.bytes,
    required this.maxEdge,
    required this.quality,
  });
}

String? _encode(_EncodeRequest req) {
  final decoded = img.decodeImage(req.bytes);
  if (decoded == null) {
    return null;
  }
  final longest =
      decoded.width >= decoded.height ? decoded.width : decoded.height;
  final img.Image resized = longest > req.maxEdge
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? req.maxEdge : null,
          height: decoded.height > decoded.width ? req.maxEdge : null,
        )
      : decoded;
  final jpg = img.encodeJpg(resized, quality: req.quality);
  return 'data:image/jpeg;base64,${base64Encode(jpg)}';
}
