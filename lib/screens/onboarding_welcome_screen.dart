import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:envisionfit/supabase/supabase_config.dart';
import 'package:envisionfit/screens/gender_selection_screen.dart';
import 'package:envisionfit/navigation/root_tabs.dart';
import 'package:envisionfit/services/onboarding_service.dart';
import 'package:envisionfit/theme.dart';

class OnboardingWelcomeScreen extends StatefulWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  State<OnboardingWelcomeScreen> createState() => _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState extends State<OnboardingWelcomeScreen> {
  bool _authBusy = false;
  StreamSubscription<AuthState>? _authSub;
  bool _handledAuth = false; // prevents double navigation

  @override
  void initState() {
    super.initState();
    // If a session already exists (e.g., returning from Google OAuth), advance.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = SupabaseConfig.auth.currentUser;
      if (user != null) {
        debugPrint('[Welcome] Existing session detected for uid=${user.id}. Determining next screen...');
        await _ensureUsersRow();
        if (!mounted) return;
        await _determineAndNavigate();
      } else {
        debugPrint('[Welcome] No existing session. Showing auth options.');
      }
    });

    // Listen for auth state changes (web redirect completes async)
    _authSub = SupabaseConfig.auth.onAuthStateChange.listen((data) async {
      debugPrint('[Welcome] Auth change: event=${data.event} sessionPresent=${data.session != null}');
      if (_handledAuth) return;
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        _handledAuth = true;
        try {
          await _ensureUsersRow();
        } catch (e) {
          debugPrint('[Welcome] ensureUsersRow after signedIn error: $e');
        }
        if (mounted) {
          await _determineAndNavigate();
        }
      }
    });
  }

  Future<void> _signInWithGoogle() async {
    if (_authBusy) return;
    setState(() => _authBusy = true);
    try {
      final redirect = Uri.base.origin; // ensure we return to the active preview origin
      debugPrint('[Welcome] Google sign-in: starting (redirectTo=$redirect)');
      await SupabaseConfig.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirect,
      );
      debugPrint('[Welcome] Google sign-in launched. The page may redirect.');
    } catch (e) {
      if (e is AuthException) {
        debugPrint('[Welcome] Google sign-in AuthException: status=${e.statusCode} message=${e.message}');
      } else {
        debugPrint('[Welcome] Google sign-in error: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _ensureUsersRow() async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) return;
      final computedName = (user.userMetadata is Map)
          ? (user.userMetadata as Map)['name'] ?? (user.email ?? 'User')
          : (user.email ?? 'User');
      debugPrint('[Welcome] ensureUsersRow: upserting users row for uid=${user.id}');
      await SupabaseConfig.client.from('users').upsert(
        {
          'id': user.id,
          'name': computedName,
          'email': user.email,
        },
        onConflict: 'id',
      );
    } catch (e) {
      if (e is PostgrestException) {
        debugPrint('[Welcome] ensureUsersRow PostgrestException: code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}');
        // Surface a friendlier hint for common RLS issues
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save your profile (RLS/Unauthorized). Check Supabase policies for "users".'),
            ),
          );
        }
      } else {
        debugPrint('[Welcome] ensureUsersRow error: $e');
      }
    }
  }

  // Email sign-up removed per current auth strategy (Google only).

  /// Decide where to go after a successful sign-in.
  /// Priority:
  /// 1) If onboarding already completed locally -> go straight to Try-On (RootTabs)
  /// 2) Else, if a Supabase user record exists with stored photo paths -> hydrate local profile and go to Try-On
  /// 3) Else -> continue onboarding at Gender selection
  Future<void> _determineAndNavigate() async {
    try {
      // Case 1: local onboarding already completed
      final completed = await OnboardingService.isCompleted();
      if (completed) {
        debugPrint('[Welcome] Local onboarding already completed. Navigating to RootTabs/Try-On.');
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RootTabs()),
        );
        return;
      }

      // Case 2: try to hydrate from Supabase user record
      final authUser = SupabaseConfig.auth.currentUser;
      final uid = authUser?.id;
      if (uid != null) {
        final record = await SupabaseUserService.getUserById(uid);
        final hasProfile = record != null;
        final name = (record?['name'] as String?)?.trim();
        final email = (record?['email'] as String?)?.trim();
        final gender = (record?['gender'] as String?)?.trim();
        final selfiePath = (record?['selfieImagePath'] as String?)?.trim();
        final fullBodyPath = (record?['fullBodyImagePath'] as String?)?.trim();

        // Consider the profile restorable if we at least have a full-body photo path stored
        if (hasProfile && (fullBodyPath != null && fullBodyPath.isNotEmpty)) {
          debugPrint('[Welcome] Found existing Supabase profile with full-body photo. Hydrating local onboarding.');
          await OnboardingService.setCompleted(
            name: name ?? (email ?? 'User'),
            email: email ?? (authUser?.email ?? ''),
            gender: gender,
            selfiePath: selfiePath,
            fullBodyPath: fullBodyPath,
          );
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const RootTabs()),
          );
          return;
        }
      }

      // Case 3: continue onboarding
      debugPrint('[Welcome] No completed profile found. Proceeding to gender selection.');
      _proceedToGender();
    } catch (e) {
      debugPrint('[Welcome] _determineAndNavigate error: $e');
      // Fallback to onboarding flow to avoid trapping
      if (mounted) _proceedToGender();
    }
  }

  void _proceedToGender() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const GenderSelectionScreen()),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.platformDefault, webViewConfiguration: const WebViewConfiguration());
    } catch (e) {
      debugPrint('[Welcome] launch error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Reference design: split background images, gradient overlay, editorial headline,
    // Google button, and a "Continue as Guest" action.
    return Scaffold(
      body: Stack(
        children: [
          // Background: two split images side-by-side (local assets)
          Positioned.fill(
            child: Row(
              children: const [
                Expanded(
                  child: _BackgroundAssetImage(
                    assetPath: 'assets/images/lady_onbaording_screen_1.png',
                  ),
                ),
                Expanded(
                  child: _BackgroundAssetImage(
                    assetPath: 'assets/images/Gentleman_onbaording_screen_1.png',
                  ),
                ),
              ],
            ),
          ),

          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.30),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.90),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: RichText(
                            text: TextSpan(
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                              children: [
                                const TextSpan(text: 'Magic'),
                                TextSpan(
                                  text: 'Fit',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.60),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Hero + Actions
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                               // Tagline removed per request

                              // Editorial headline
                              Text(
                                'Try Before\nYou Buy.',
                                style: theme.textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const SizedBox(height: 24),

                              // Google sign-in button (white background, black text)
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _authBusy ? null : _signInWithGoogle,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Using a simple Material icon as a lightweight stand-in
                                      const Icon(Icons.login, color: Colors.black, size: 20),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'Sign in with Google',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Continue as Guest
                              Center(
                                child: TextButton(
                                  onPressed: _proceedToGender,
                                  child: Text(
                                    'CONTINUE AS GUEST',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.70),
                                      letterSpacing: 3.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

class _BackgroundAssetImage extends StatelessWidget {
  final String assetPath;
  const _BackgroundAssetImage({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.85,
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) {
          return const ColoredBox(color: Colors.black);
        },
      ),
    );
  }
}
