import 'package:envisionfit/services/ai/tryon_ai_provider.dart';
import 'package:envisionfit/services/ai/gemini_supabase_provider.dart';

/// Central place to select the active AI provider.
/// Now using Gemini 2.5 Flash Image via Supabase Edge Function.
class AiProviders {
  static TryOnAiProvider current = GeminiSupabaseTryOnProvider();
}
