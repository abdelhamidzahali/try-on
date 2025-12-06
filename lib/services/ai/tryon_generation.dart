import 'dart:typed_data';

/// Output container for a try-on generation.
/// Exactly one of [url] or [bytes] should be present.
class TryOnGeneration {
  final String? url; // If the Edge Function uploaded to storage, use this
  final Uint8List? bytes; // Fallback when the API returns base64 directly
  /// The actual prompt the backend used to generate the image (if available).
  /// This can differ from any client-provided hint because the Edge Function
  /// may compose or fetch the final prompt from the database.
  final String? usedPrompt;
  /// Optional: a concise clothing description returned by the Edge Function.
  /// If present, we can use this for retail search (e.g., SHEIN).
  final String? clothingDescription;

  const TryOnGeneration({this.url, this.bytes, this.usedPrompt, this.clothingDescription});

  bool get hasUrl => (url != null && url!.isNotEmpty);
  bool get hasBytes => (bytes != null && bytes!.isNotEmpty);
}
