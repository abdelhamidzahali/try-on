# EnvisionFit Architecture

## Overview
**EnvisionFit** is a Flutter app (package `envisionfit`) for AI virtual outfit try-on. A user signs in, picks a gender, saves a selfie and a full-body photo, then uploads a photo of a garment. The app describes the garment, checks it matches the user's gender, and generates an image of the user wearing it.

All AI work runs on the backend: the app calls **Supabase Edge Functions**, which call **Google Gemini** (the try-on provider is labelled Gemini 2.5 Flash Image in `lib/services/ai/ai_providers.dart`). The Edge Function source is not in this repository; this document covers the client side and the contracts it relies on.

```
Flutter app ──► Supabase Auth (Google OAuth)
            ──► Supabase Postgres (`users` table)
            ──► Supabase Edge Functions ──► Gemini
                  ├─ profile_photo_validation
                  ├─ Describ_Garment
                  ├─ tryon-upload-urls  ──► Supabase Storage (signed URLs)
                  └─ tryon
            ──► SharedPreferences (local history, galleries, favorites, profile)
```

## User flow
1. **Welcome** (`onboarding_welcome_screen.dart`): Google sign-in through `SupabaseConfig.auth.signInWithOAuth(OAuthProvider.google)`, redirecting back to `Uri.base.origin`. On sign-in the app upserts `{id, name, email}` into the `users` table. A "Continue as Guest" option skips sign-in.
2. **Gender selection** (`gender_selection_screen.dart`): Gentleman or Lady.
3. **Selfie** (`onboarding_photos_screen.dart`) and **full-body photo** (`onboarding_fullbody_screen.dart`): each photo is checked by the `profile_photo_validation` Edge Function, which rejects bad photos and detects gender so the app can block a mismatch with the selected gender. When the remote check returns nothing (for example for guests or offline), the app falls back to `LocalPhotoValidator` (on-device resolution checks). Photos go into local galleries.
4. **Registration** (`UserRegistrationService.completeRegistration`): stores the profile in SharedPreferences and, when signed in, updates the `users` row.
5. **Main tabs** (`navigation/root_tabs.dart`): Home (Try-On), Favorites, Settings. Each tab has its own nested `Navigator`; `AppNavigator` holds the global navigator key and a `tabIndex` notifier.
6. **Try-On** (`tryon_screen.dart`): user uploads a garment photo (camera or gallery). `ClothingDescriptionService` calls `Describ_Garment`, parses category, name and gender, and blocks the try-on if the garment's gender doesn't match the user's.
7. **Results** (`results_screen.dart`): creates and processes a `TryOnSession`, shows the generated image, and lets the user save/download it, favorite it, or try another outfit.
8. **Settings** (`settings_screen.dart`): replace the selfie or full-body photo (re-validated the same way), and sign out.

Note: `main.dart` currently has `_previewOnboarding = true`, so the app always starts on the Welcome screen. Set it to `false` to resume at the main tabs once onboarding is complete.

## Supabase backend

### Configuration
`lib/supabase/supabase_config.dart` holds the project URL and anon key and initialises the client in `main()`. It also defines a generic `SupabaseService` CRUD helper and table helpers (`SupabaseUserService`, `SupabaseClothingService`, `SupabaseTryOnService`, `SupabaseGeneratedImageService`). Only `SupabaseUserService` is used today.

### Edge Functions (called with `client.functions.invoke`)
| Function | Caller | Request | Response used by the app |
|---|---|---|---|
| `profile_photo_validation` | `PhotoValidationService.validateBytes` | `imageBase64`, `photoType` (`selfie` / `fullbody`) | `{gender, status: "OK" \| "NOT OK", reason}`, possibly nested under `result`/`data`/`output` or as a JSON string |
| `Describ_Garment` | `ClothingDescriptionService.describeClothing` | `clothing_image_base64`, `mime_type` | `{description}` (or plain text) whose first three lines are category, name, and gender (Gentleman / Lady) |
| `tryon-upload-urls` | `StorageService.uploadTryOnInputsAndGetUrls` | `user_id`, `timestamp` | `model_upload_url`, `cloth_upload_url`, `model_read_url`, `cloth_read_url` (signed Storage URLs) |
| `tryon` | `GeminiSupabaseTryOnProvider.generateComposite` | model and garment images (as URLs or base64), `clothing_category`, `clothing_name`, `clothing_gender`, `mode: "virtual_tryon"`, `prompt` | a result image URL (`result_image_url`, `image_url`, ...) or base64 image, plus optional `clothing_description` and the prompt the backend used |

### Try-on generation path
`GeminiSupabaseTryOnProvider` (`lib/services/ai/gemini_supabase_provider.dart`):
1. **URL path (preferred):** get signed upload URLs from `tryon-upload-urls`, `PUT` both JPEGs straight to Supabase Storage, then call `tryon` with the signed read URLs.
2. **Base64 fallback:** if the upload or URL call fails, call `tryon` again with both images base64-encoded.
3. **Response parsing:** accepts a result URL first, then base64 in common keys, nested `result`/`data`/`output`, or any data-URL-like string. Returns a `TryOnGeneration` with either `url` or `bytes`, plus `usedPrompt` and `clothingDescription`.

The provider sits behind the `TryOnAiProvider` interface (`analyzeStyle`, `generateComposite`), and `AiProviders.current` picks the active one. The Gemini provider returns `null` from `analyzeStyle`, so there is no separate style-analysis step.

### Database
Schema and RLS policies are in `lib/supabase/supabase_tables.sql` and `supabase_policies.sql` (generated types in `database.types.ts`). Tables: `users`, `clothing_items`, `generated_images`, `tryon_sessions`, each with RLS limited to `auth.uid()`.

In practice the app only reads and writes `users`. It also writes `gender`, `selfieImagePath`, `fullBodyImagePath`, `createdAt` and `updatedAt`, which are not in the checked-in SQL. Those columns either exist only in the live project or the writes fail; `UserRegistrationService` retries with a minimal payload when that happens. The checked-in SQL should be synced with the live schema.

## Local storage (SharedPreferences)
Try-on history and photos stay on the device:

| Service | Key | Contents |
|---|---|---|
| `OnboardingService` | `onboarding_completed_v1`, `profile_*_v1` | completion flag, name, email, gender, selfie and full-body paths |
| `ModelGalleryService` | `model_images_v1` | selfie gallery with a default image |
| `FullBodyGalleryService` | `fullbody_images_v1` | full-body gallery with a default image |
| `TryOnService` | `tryon_sessions` | try-on sessions, capped at the 8 most recent |
| `TryOnFavoritesService` | `favorite_tryon_ids` | favorited session ids |
| `ClothingService` | `clothing_items` | sample clothing catalog (not used by the current UI) |

When `tryon` returns a URL the session stores it. When it returns bytes, `ImageService.saveBytesToImageFile` saves them locally (data URLs on web). `DownloadSaver` uses `image_gallery_saver` on mobile and a browser download on web.

## Code layout
- `lib/models/`: `User`, `TryOnSession` (status: pending, processing, completed, failed, plus clothing metadata), `GeneratedImage`, `ClothingItem`, `ModelImage`.
- `lib/services/`: the services above, plus `ImageService` (camera, gallery, permissions, bytes and file helpers) and `ai/` (provider interface, Gemini provider, `TryOnGeneration`).
- `lib/supabase/`: client config, Storage upload helper, SQL schema, policies, sample data, types.
- `lib/screens/`, `lib/widgets/`: UI. Main widgets: `PhotoCaptureCard`, `AnimatedPreparing`, `ResultCard`, `OutfitCard`, `TitleText`.
- `lib/theme.dart`: light and dark themes using Inter for body text and Playfair Display for headings.

## Legacy and unused code
- `lib/openai/openai_config.dart`: the original OpenAI implementation (`OpenAIService`, `OpenAiTryOnProvider`, GPT-4o and gpt-image-1 through a Dreamflow proxy). It is no longer wired in.
- `HomePage`, `HistoryScreen`, `RetailSearchService` (SHEIN search links), `ClothingService` and the unused Supabase table helpers have no callers in the current navigation.
